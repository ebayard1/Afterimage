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

    func create(
        name: String,
        durationDays: Int,
        creatorId: String,
        requirePresence: Bool = false,
        filmStock: FilmStock? = nil,
        soundtrack: Soundtrack? = nil
    ) async throws -> String {
        let revealAt = SunriseCalculator.nextSunrise(daysFromNow: durationDays)
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
            filmStockRaw: filmStock?.rawValue,
            soundtrackTitle: soundtrack?.title,
            soundtrackArtist: soundtrack?.artist
        )
        let ref = try db.collection("albums").addDocument(from: album)
        return ref.documentID
    }

    func join(albumId: String, userId: String) async throws {
        try await db.collection("albums").document(albumId).updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ])
    }

    func leave(albumId: String, userId: String) async throws {
        try await db.collection("albums").document(albumId).updateData([
            "memberIds": FieldValue.arrayRemove([userId])
        ])
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
