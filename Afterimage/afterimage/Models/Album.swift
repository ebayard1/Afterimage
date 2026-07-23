import Foundation
import FirebaseFirestore
import CoreLocation

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

    /// Short share/QR code for joining (also keyed in `invites/{code}`).
    var inviteCode: String? = nil
    /// First few shot URLs, denormalized so feed/profile film-strip cards can
    /// render without loading the whole shots subcollection. Maintained on upload.
    var previewURLs: [String]? = nil
    /// Total shots in the roll, denormalized alongside `previewURLs`.
    var shotCount: Int? = nil
    /// Where the roll was shot — captured from GPS at the first shot.
    var locationName: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil

    var isRevealed: Bool { Date() >= revealAt }
    var timeRemaining: TimeInterval { max(0, revealAt.timeIntervalSinceNow) }
}

// MARK: - Display helpers

extension Album {
    /// Map pin coordinate (captured from the first shot's GPS).
    var mapCoordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lng = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Reverse-geocoded place label.
    var mapLocationName: String? {
        (locationName?.isEmpty == false) ? locationName : nil
    }

    /// Photo URLs for the feed/profile film-strip cards (denormalized).
    var stripPreviewURLs: [String] { previewURLs ?? [] }

    /// Shot count shown on cards (denormalized).
    var displayShotCount: Int { shotCount ?? previewURLs?.count ?? 0 }
}
