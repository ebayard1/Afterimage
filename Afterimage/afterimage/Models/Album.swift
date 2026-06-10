import Foundation
import FirebaseFirestore

struct Album: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var creatorId: String
    var memberIds: [String]
    var createdAt: Date
    var revealAt: Date
    var durationDays: Int
    var coverPhotoURL: String?
    var requirePresence: Bool? = false

    /// Optional film stock applied to the roll. Stored as the FilmStock raw
    /// value so the Album doc round-trips through Firestore cleanly.
    var filmStockRaw: String? = nil
    /// Optional soundtrack title attached to the roll.
    var soundtrackTitle: String? = nil
    /// Optional soundtrack artist attached to the roll.
    var soundtrackArtist: String? = nil

    var isRevealed: Bool { Date() >= revealAt }
    var timeRemaining: TimeInterval { max(0, revealAt.timeIntervalSinceNow) }
}
