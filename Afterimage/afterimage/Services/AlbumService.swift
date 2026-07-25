import Foundation
import FirebaseFirestore

/// The user's rolls, live.
///
/// There is exactly ONE of these for the whole app — created in `ContentView`
/// and handed down through the environment. Never make one with `@State`
/// inside a screen: the paged `TabView` keeps Rolls, Camera and Profile
/// mounted at the same time, so a per-screen instance means three copies of
/// the same `albums` query and three decodes of every snapshot.
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
    ///
    /// Results are cached (see `ShotURLCache`): the same roll is rendered on
    /// both Rolls and Profile, and each card re-runs its `.task(id:)` every
    /// time it reappears, so this used to be one Firestore read per roll *per
    /// surface, per appearance*. The cache is invalidated by
    /// `invalidateShotURLs(albumId:)` when you shoot into the roll, and ages
    /// out after a minute so someone else's frames turn up too.
    nonisolated static func fetchShotURLs(albumId: String, limit: Int = 6) async -> [String] {
        await ShotURLCache.shared.urls(albumId: albumId, limit: limit) {
            do {
                let snap = try await Firestore.firestore()
                    .collection("albums").document(albumId)
                    .collection("shots")
                    .order(by: "createdAt")
                    .limit(to: limit)
                    .getDocuments()
                return snap.documents.compactMap { $0.data()["photoURL"] as? String }
            } catch {
                // nil, not [] — a failed read must stay retryable.
                return nil
            }
        }
    }

    /// Drop every cached shot-URL list for one roll, across all `limit`
    /// variants, so the next card re-reads.
    ///
    /// Called by `ShotService` after a shot lands in Firestore. Without it, a
    /// roll whose `previewURLs` hasn't been backfilled yet gets its fallback
    /// list memoized once and then keeps showing exactly those frames for the
    /// rest of the app session — you shoot three more and the strip never
    /// changes, because `.task(id:)` re-runs but nothing reads Firestore again.
    nonisolated static func invalidateShotURLs(albumId: String) async {
        await ShotURLCache.shared.invalidate(albumId: albumId)
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
    ///
    /// Now that there is a single shared instance, "every screen" is literal:
    /// the optimistic removal is seen by Rolls, Camera and Profile at once.
    /// Previously each tab held its own `AlbumService`, so only the tab that
    /// performed the leave updated immediately and the others waited on the
    /// snapshot. That is the intended behaviour, not a regression.
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

// MARK: - Session cache for the shot-URL fallback

/// Memoizes `AlbumService.fetchShotURLs`.
///
/// An `actor` rather than a static dictionary behind an `NSLock` for two
/// reasons: `fetchShotURLs` is `nonisolated` + `async`, so there is no lock to
/// hold across the `await` anyway, and the actor lets simultaneous callers for
/// the same roll (Rolls and Profile render the same card at the same moment)
/// *coalesce onto one in-flight read* instead of racing two identical queries
/// — something a plain lock-guarded dictionary can't do.
///
/// Size is bounded by the number of rolls the user is a member of (tens), so
/// there is no size-based eviction — but entries do go stale, in two ways:
///
/// * **You** shoot into the roll. Handled exactly, by `invalidate(albumId:)`
///   from `ShotService` after the write.
/// * **Someone else** shoots into a roll you're both in. Nothing local fires,
///   so the entry needs to age out on its own — hence `ttl`.
private actor ShotURLCache {
    // Explicitly `nonisolated` so the (nonisolated) `fetchShotURLs` can reach
    // it without an actor hop just to read the reference. Safe: an immutable
    // `let` holding a Sendable actor.
    nonisolated static let shared = ShotURLCache()

    /// How long a cached list is served before the next card re-reads.
    ///
    /// 60s. The cache exists to coalesce the Home/Profile duplicate reads and
    /// the repeat card appearances of a single scrolling session — both of
    /// which happen within seconds, so a minute serves them just as well as
    /// forever did. What it buys is a ceiling on how long a friend's new frame
    /// can be invisible in your strip: one read per roll per minute of active
    /// looking, instead of one per roll for the whole session.
    private static let ttl: TimeInterval = 60

    private struct Entry {
        let urls: [String]
        let storedAt: Date
    }

    private var cached: [String: Entry] = [:]
    private var inFlight: [String: Task<[String]?, Never>] = [:]
    /// Bumped per album by `invalidate`. A read that was already in flight when
    /// the invalidation landed must not write its (pre-write) result into the
    /// cache afterwards — it compares generations before storing.
    private var generation: [String: Int] = [:]

    /// - Parameter fetch: performs the read. Returns `nil` on failure, which is
    ///   never cached, so a transient network error retries on the next card.
    func urls(
        albumId: String,
        limit: Int,
        fetch: @Sendable @escaping () async -> [String]?
    ) async -> [String] {
        let key = "\(albumId)#\(limit)"
        if let hit = cached[key], Date().timeIntervalSince(hit.storedAt) < Self.ttl {
            return hit.urls
        }
        if let running = inFlight[key] { return await running.value ?? [] }

        let startGeneration = generation[albumId, default: 0]
        let task = Task<[String]?, Never> { await fetch() }
        inFlight[key] = task
        let result = await task.value
        // Identity-compared: an `invalidate` during the await may already have
        // cleared this slot and a later caller may own it now.
        if inFlight[key] == task { inFlight[key] = nil }

        // Only a non-empty read is cached. An empty result means either a
        // failure or a roll with no shots yet; both must stay retryable, and
        // the cards can't tell `[]` apart from "not loaded" anyway.
        if let result, !result.isEmpty,
           generation[albumId, default: 0] == startGeneration {
            cached[key] = Entry(urls: result, storedAt: Date())
        }
        return result ?? []
    }

    /// Evict one roll — every `limit` variant of its key, plus any read still
    /// in flight for it (whose result is now known to predate the new shot).
    func invalidate(albumId: String) {
        generation[albumId, default: 0] += 1
        let prefix = "\(albumId)#"
        cached = cached.filter { !$0.key.hasPrefix(prefix) }
        inFlight = inFlight.filter { !$0.key.hasPrefix(prefix) }
    }
}
