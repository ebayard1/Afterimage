import Foundation
import FirebaseFirestore

@Observable
@MainActor
final class CommentService {
    var comments: [Comment] = []

    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private let db = Firestore.firestore()
    @ObservationIgnored private var currentAlbumId: String?

    func startListening(albumId: String) {
        currentAlbumId = albumId
        listener?.remove()
        listener = db.collection("albums").document(albumId).collection("comments")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.comments = docs.compactMap { try? $0.data(as: Comment.self) }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        comments = []
        currentAlbumId = nil
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
