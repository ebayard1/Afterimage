import Foundation
import FirebaseFirestore

@Observable
@MainActor
final class CommentService {
    var comments: [Comment] = []

    /// Which album `comments` currently describes.
    ///
    /// Deliberately *observed* (no `@ObservationIgnored`): callers keep the
    /// last snapshot on screen while the listener is detached, so they need a
    /// way to tell "this is my roll's thread" from "this is whatever roll the
    /// service was pointed at before". See `pauseListening()`.
    private(set) var loadedAlbumId: String?

    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private let db = Firestore.firestore()

    /// Idempotent in both directions: re-calling for the album that is already
    /// live is a no-op (a visibility gate that fires twice must not churn the
    /// Watch stream), and calling for a *different* album re-keys cleanly.
    func startListening(albumId: String) {
        if listener != nil, loadedAlbumId == albumId { return }
        listener?.remove()
        // Switching rolls is the one case where retained comments are actually
        // wrong — drop them rather than flash another roll's thread.
        if loadedAlbumId != albumId { comments = [] }
        loadedAlbumId = albumId
        listener = db.collection("albums").document(albumId).collection("comments")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    // The hop means a snapshot from a just-removed listener can
                    // still land after a re-key; drop it if it isn't ours.
                    guard let self, self.loadedAlbumId == albumId else { return }
                    self.comments = docs.compactMap { try? $0.data(as: Comment.self) }
                }
            }
    }

    /// Detach the listener but KEEP the last snapshot.
    ///
    /// This is what a *visibility* gate wants. Clearing `comments` on the way
    /// out meant a card scrolled off and back re-rendered "TOP COMMENTS (0)"
    /// with no rows for the frame(s) before the (cache-served) snapshot landed
    /// — a visible blink on every scroll-back, on every revealed roll. The data
    /// is a handful of structs; holding it costs nothing and the panel redraws
    /// instantly with the previous content, then updates in place.
    func pauseListening() {
        listener?.remove()
        listener = nil
    }

    /// Full reset: detach *and* forget. For teardowns where the data itself is
    /// no longer valid — sign-out, or a screen dismissing for good.
    func stopListening() {
        pauseListening()
        comments = []
        loadedAlbumId = nil
    }

    func post(text: String,
              referencedShotId: String?,
              parentId: String? = nil,
              albumId: String,
              userId: String,
              username: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let comment = Comment(
            id: UUID().uuidString,
            userId: userId,
            username: username,
            text: trimmed,
            createdAt: Date(),
            referencedShotId: referencedShotId,
            parentId: parentId,
            likedBy: nil
        )
        try db.collection("albums").document(albumId)
            .collection("comments").document(comment.id ?? UUID().uuidString)
            .setData(from: comment)
    }

    func toggleLike(commentId: String, albumId: String, userId: String) async throws {
        let ref = db.collection("albums").document(albumId)
            .collection("comments").document(commentId)
        let snap = try await ref.getDocument()
        let comment = try snap.data(as: Comment.self)
        var likes = comment.likedBy ?? []
        if let idx = likes.firstIndex(of: userId) {
            likes.remove(at: idx)
        } else {
            likes.append(userId)
        }
        try await ref.updateData(["likedBy": likes])
    }
}
