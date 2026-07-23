import Foundation
import FirebaseFirestore

/// Activity-rail item, fanned out into `users/{uid}/feed` by Cloud Functions.
struct FeedItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var kind: String
    var actorUid: String
    var actorUsername: String
    var actorPhotoURL: String?
    var albumId: String?
    var albumName: String?
    var detail: String?
    var happenedAt: Date

    /// Maps the stored kind string to the rail's icon/headline enum.
    var eventKind: ActivityEvent.Kind { ActivityEvent.Kind(rawValue: kind) ?? .addedShot }
}

/// Notification doc in `users/{uid}/notifications`, written by Cloud Functions.
struct AppNotificationItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var kind: String
    var title: String
    var subtitle: String
    var icon: String
    var read: Bool
    var createdAt: Date
    var albumId: String?

    var relativeTime: String {
        let s = -createdAt.timeIntervalSinceNow
        if s < 60 { return "now" }
        if s < 3600 { return "\(Int(s / 60))m" }
        if s < 86400 { return "\(Int(s / 3600))h" }
        return "\(Int(s / 86400))d"
    }
}

/// A friend request in the top-level `friendRequests` collection.
struct FriendRequestModel: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var fromUid: String
    var toUid: String
    var status: String          // pending | accepted | declined
    var createdAt: Date
}
