import Foundation
import FirebaseFirestore

@Observable
@MainActor
final class AlbumService {
    var albums: [Album] = []

    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private let db = Firestore.firestore()

    func startListening(userId: String) {
        listener?.remove()
        listener = db.collection("albums")
            .whereField("memberIds", arrayContains: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.albums = docs.compactMap { try? $0.data(as: Album.self) }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        albums = []
    }

    /// Fallback for the feed/profile film-strip cards: read a roll's shot photo
    /// URLs straight from the `shots` subcollection. The album's denormalized
    /// `previewURLs` is normally maintained server-side by the `onShotCreated`
    /// Cloud Function, but if that list is missing (older rolls, or a backend
    /// that hasn't caught up), the cards call this so photos still appear.
    nonisolated static func fetchShotURLs(albumId: String, limit: Int = 6) async -> [String] {
        do {
            let snap = try await Firestore.firestore()
                .collection("albums").document(albumId)
                .collection("shots")
                .order(by: "createdAt")
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { $0.data()["photoURL"] as? String }
        } catch {
            return []
        }
    }

    func create(
        name: String,
        durationDays: Int,
        creatorId: String,
        requirePresence: Bool = false
    ) async throws -> String {
        // durationDays == 0 is the quick TEST window: reveals in 5 minutes
        // (instead of at the next sunrise) so a reveal can be tested today.
        let revealAt = durationDays == 0
            ? Date().addingTimeInterval(5 * 60)
            : SunriseCalculator.nextSunrise(daysFromNow: durationDays)
        let code = Self.makeInviteCode()
        let album = Album(
            id: nil,
            name: name,
            creatorId: creatorId,
            memberIds: [creatorId],
            createdAt: Date(),
            revealAt: revealAt,
            durationDays: durationDays,
            coverPhotoURL: nil,
            requirePresence: requirePresence,
            inviteCode: code,
            previewURLs: [],
            shotCount: 0
        )
        let ref = try db.collection("albums").addDocument(from: album)
        // Map the invite code → album for QR / code joins.
        try? await db.collection("invites").document(code).setData([
            "albumId": ref.documentID
        ])
        return ref.documentID
    }

    /// Resolves a share code to an album id. Accepts either a raw invite code or
    /// a full album document id (so pasted ids still work).
    func resolveInvite(code rawCode: String) async throws -> String? {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }
        let upper = code.uppercased()
        let inviteDoc = try await db.collection("invites").document(upper).getDocument()
        if let albumId = inviteDoc.data()?["albumId"] as? String { return albumId }
        // Fallback: maybe they pasted the album id directly.
        let albumDoc = try await db.collection("albums").document(code).getDocument()
        return albumDoc.exists ? code : nil
    }

    func join(albumId: String, userId: String) async throws {
        try await db.collection("albums").document(albumId).updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ])
    }

    /// 6-character uppercased code, avoiding ambiguous characters.
    private static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }

    /// Removes the user from the roll. If they were the last member, the roll
    /// deletes itself — an album with no members would otherwise be orphaned
    /// forever (nobody can read it, so nobody could ever clean it up).
    ///
    /// The album is dropped from the local `albums` list immediately, so it
    /// vanishes from every screen the instant you leave — no waiting for the
    /// Firestore snapshot listener to catch up.
    func leave(albumId: String, userId: String) async throws {
        // Optimistic: vanish from every screen instantly. Restored on failure.
        let removed = albums.first { $0.id == albumId }
        albums.removeAll { $0.id == albumId }

        do {
            let ref = db.collection("albums").document(albumId)
            let snap = try await ref.getDocument()
            let members = snap.data()?["memberIds"] as? [String] ?? []
            let isLastMember = members.contains(userId) && members.count <= 1

            if isLastMember {
                // Tear the roll down while we're still a member, so the security
                // rules (which gate on membership of the still-existing album doc)
                // still permit deleting the child shots and the album itself.
                let shotDocs = try? await ref.collection("shots").getDocuments()
                for doc in shotDocs?.documents ?? [] {
                    try? await doc.reference.delete()
                }
                // Best-effort: drop the invite-code mapping too.
                if let code = snap.data()?["inviteCode"] as? String {
                    try? await db.collection("invites").document(code).delete()
                }
                try await ref.delete()
            } else {
                try await ref.updateData([
                    "memberIds": FieldValue.arrayRemove([userId])
                ])
            }
        } catch {
            // Leave failed — put the roll back so the UI stays truthful.
            if let removed, !albums.contains(where: { $0.id == albumId }) {
                albums.append(removed)
                albums.sort { $0.createdAt > $1.createdAt }
            }
            throw error
        }
    }

    func rename(albumId: String, newName: String) async throws {
        try await db.collection("albums").document(albumId).updateData([
            "name": newName
        ])
    }

    func delete(albumId: String) async throws {
        // Best-effort: remove shots subcollection first, then album doc.
        let shotsRef = db.collection("albums").document(albumId).collection("shots")
        let shotDocs = try await shotsRef.getDocuments()
        for doc in shotDocs.documents {
            try? await doc.reference.delete()
        }
        try await db.collection("albums").document(albumId).delete()
    }
}
