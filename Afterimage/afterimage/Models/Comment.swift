import Foundation
import FirebaseFirestore

struct Comment: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var userId: String              // firebase uid (or "me"/"sam-uid" for sample)
    var username: String            // e.g. "@sam_k"
    var text: String
    var createdAt: Date
    /// Optional reference to a specific shot in the album.
    var referencedShotId: String?
    /// Threaded reply support — id of the parent comment (top-level if nil).
    var parentId: String?
    /// User ids that have liked this comment.
    var likedBy: [String]?

    var likeCount: Int { likedBy?.count ?? 0 }
    func didLike(_ uid: String) -> Bool { likedBy?.contains(uid) ?? false }
}
