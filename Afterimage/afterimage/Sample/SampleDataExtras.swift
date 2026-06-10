import SwiftUI
import CoreLocation

// MARK: - Sample film stock + soundtrack assignments per album
//
// Mapped by the sample album id ("sample-sams-bday" → stock + soundtrack).
// Lookups are total — anything not in the table just returns nil and the UI
// falls through cleanly.

extension SampleData {
    static func filmStock(forAlbumId id: String) -> FilmStock? {
        switch id {
        case "\(samplePrefix)sams-bday":     return .kodakPortra400
        case "\(samplePrefix)road-trip":     return .cinestill800T
        case "\(samplePrefix)nye-2025":      return .ilfordHP5
        case "\(samplePrefix)beach-day":     return .fujiSuperia
        case "\(samplePrefix)festival":      return .lomoRedscale
        case "\(samplePrefix)concert":       return .cinestill800T
        case "\(samplePrefix)spring-escape": return .polaroid600
        default: return nil
        }
    }

    static func soundtrack(forAlbumId id: String) -> Soundtrack? {
        let catalog = Soundtrack.catalog
        switch id {
        case "\(samplePrefix)sams-bday":
            return catalog.first { $0.title == "Vienna" }
        case "\(samplePrefix)road-trip":
            return catalog.first { $0.title == "Harvest Moon" }
        case "\(samplePrefix)nye-2025":
            return catalog.first { $0.title == "Dreams" }
        case "\(samplePrefix)beach-day":
            return catalog.first { $0.title == "Strawberry Swing" }
        case "\(samplePrefix)festival":
            return catalog.first { $0.title == "Pyramids" }
        case "\(samplePrefix)concert":
            return catalog.first { $0.title == "Heart-Shaped Box" }
        case "\(samplePrefix)spring-escape":
            return catalog.first { $0.title == "Holocene" }
        default: return nil
        }
    }
}

// MARK: - Activity rail events
//
// Sample feed of recent activity from friends + the user. Used by the rail
// at the top of the Rolls feed.

extension SampleData {
    static var activityEvents: [ActivityEvent] {
        let now = Date()
        return [
            ActivityEvent(
                kind: .startedRoll,
                actorUsername: "@sam_k", actorPhotoSeed: "sam",
                albumName: "Brunch at Mae's", detail: nil,
                happenedAt: now.addingTimeInterval(-60 * 4)),
            ActivityEvent(
                kind: .addedShot,
                actorUsername: "@maya", actorPhotoSeed: "maya",
                albumName: "NYE 2025", detail: "shot 18 of 24",
                happenedAt: now.addingTimeInterval(-60 * 18)),
            ActivityEvent(
                kind: .taggedYou,
                actorUsername: "@leo", actorPhotoSeed: "leo",
                albumName: "Festival", detail: "3 new shots",
                happenedAt: now.addingTimeInterval(-60 * 35)),
            ActivityEvent(
                kind: .revealedRoll,
                actorUsername: "@noah", actorPhotoSeed: "noah",
                albumName: "Beach Day", detail: nil,
                happenedAt: now.addingTimeInterval(-3600 * 2)),
            ActivityEvent(
                kind: .commented,
                actorUsername: "@kim", actorPhotoSeed: "kim",
                albumName: "Sam's Birthday", detail: "\u{201C}this one is so good\u{201D}",
                happenedAt: now.addingTimeInterval(-3600 * 4)),
            ActivityEvent(
                kind: .appearedIn,
                actorUsername: "@riley", actorPhotoSeed: "riley",
                albumName: "Concert", detail: "2 shots",
                happenedAt: now.addingTimeInterval(-3600 * 7)),
            ActivityEvent(
                kind: .addedShot,
                actorUsername: "@jake", actorPhotoSeed: "jake",
                albumName: "Road Trip", detail: "shot 14 of 24",
                happenedAt: now.addingTimeInterval(-3600 * 12)),
        ]
    }
}

// MARK: - "On this day" memory surfacing
//
// Picks one revealed album to surface as "1 year ago today" — based purely
// on the current date for the demo so something always shows.

extension SampleData {
    struct OnThisDay: Identifiable {
        let id = UUID()
        let yearsAgo: Int
        let album: Album
        let teaserPhotoURL: String?
    }

    static var onThisDay: OnThisDay? {
        // Pick the first revealed sample album; pretend it happened "1 year ago"
        // for the demo. In the real app this would do real date math.
        guard let album = albums.first(where: { $0.isRevealed }) else { return nil }
        let firstShot = shots(forAlbumId: album.id ?? "").first
        return OnThisDay(yearsAgo: 1, album: album, teaserPhotoURL: firstShot?.photoURL)
    }
}

// MARK: - Voice note duration table
//
// Sample-only stub — each shot id deterministically gets a fake voice note
// duration (0 = no voice note). Used by camera record UI + viewer playback UI.

extension SampleData {
    /// Returns a fake voice note duration (seconds) for the given shot id, or
    /// nil if no voice note is attached. Deterministic by hash.
    static func voiceNoteDuration(forShotId id: String) -> Double? {
        let h = abs(id.hashValue)
        guard h % 4 == 0 else { return nil }
        let secs = Double((h % 9) + 2)  // 2…10 seconds
        return secs
    }
}

// MARK: - Album location coordinates (for the map view)

extension SampleData {
    static func coordinate(forAlbumId id: String) -> CLLocationCoordinate2D? {
        switch id {
        case "\(samplePrefix)sams-bday":      return .init(latitude: 40.6782, longitude: -73.9442)  // Brooklyn
        case "\(samplePrefix)road-trip":      return .init(latitude: 36.2704, longitude: -121.8081) // Big Sur
        case "\(samplePrefix)nye-2025":       return .init(latitude: 41.8781, longitude: -87.6298)  // Chicago
        case "\(samplePrefix)beach-day":      return .init(latitude: 40.5800, longitude: -73.8350)  // Rockaway
        case "\(samplePrefix)festival":       return .init(latitude: 30.2672, longitude: -97.7431)  // Austin
        case "\(samplePrefix)concert":        return .init(latitude: 40.7505, longitude: -73.9934)  // MSG
        case "\(samplePrefix)spring-escape":  return .init(latitude: 34.8697, longitude: -111.7610) // Sedona
        default: return nil
        }
    }
}

// MARK: - Convenience: pull sample film stock / soundtrack directly off an Album
//
// Falls through to the album's encoded value first, then to the curated table.

extension Album {
    var filmStock: FilmStock? {
        if let raw = filmStockRaw, let stock = FilmStock(rawValue: raw) { return stock }
        return SampleData.filmStock(forAlbumId: id ?? "")
    }

    var soundtrack: Soundtrack? {
        if let title = soundtrackTitle, let artist = soundtrackArtist {
            // Match to catalog for duration metadata where possible.
            if let cat = Soundtrack.catalog.first(where: { $0.title == title && $0.artist == artist }) {
                return cat
            }
            return Soundtrack(title: title, artist: artist, durationSeconds: 0)
        }
        return SampleData.soundtrack(forAlbumId: id ?? "")
    }
}
