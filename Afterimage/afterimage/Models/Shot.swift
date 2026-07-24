import Foundation
import FirebaseFirestore

struct Shot: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var userId: String
    /// The still image. For a video shot this is the poster frame (first frame),
    /// so every feed thumbnail / film-strip frame / hero shows a still and never
    /// autoplays — the video only plays when tapped into a full-screen player.
    var photoURL: String
    /// Set only when this shot is a video. `nil` for a plain photo.
    var videoURL: String? = nil
    var createdAt: Date
    var note: String?

    /// True when this shot carries a playable video (poster in `photoURL`).
    var isVideo: Bool { !(videoURL?.isEmpty ?? true) }
    /// emoji -> array of user IDs that reacted with it
    var reactions: [String: [String]]?
    /// Where this shot was taken (captured at the first shot of a roll). The
    /// Cloud Function copies the first located shot's place onto the album.
    var latitude: Double?
    var longitude: Double?
    var locationName: String?

    func reactionCount(_ emoji: String) -> Int {
        reactions?[emoji]?.count ?? 0
    }

    func didReact(userId: String, emoji: String) -> Bool {
        reactions?[emoji]?.contains(userId) ?? false
    }
}
