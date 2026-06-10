import Foundation
import FirebaseFirestore

struct Shot: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var userId: String
    var photoURL: String
    var createdAt: Date
    var note: String?
    /// emoji -> array of user IDs that reacted with it
    var reactions: [String: [String]]?

    func reactionCount(_ emoji: String) -> Int {
        reactions?[emoji]?.count ?? 0
    }

    func didReact(userId: String, emoji: String) -> Bool {
        reactions?[emoji]?.contains(userId) ?? false
    }
}
