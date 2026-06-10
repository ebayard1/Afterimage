import Foundation

/// A single song attached to an album — plays under the reveal cinematic and
/// the Year-In-Rolls recap. Sample-only; not actually decoded as audio yet.
struct Soundtrack: Identifiable, Hashable, Codable {
    var id: String { "\(title)|\(artist)" }
    let title: String
    let artist: String
    let durationSeconds: Int

    var formattedDuration: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

extension Soundtrack {
    /// Curated sample track catalog used by the picker. Stays small + tasteful.
    static let catalog: [Soundtrack] = [
        .init(title: "Heart-Shaped Box",    artist: "Nirvana",            durationSeconds: 282),
        .init(title: "Pink + White",        artist: "Frank Ocean",        durationSeconds: 184),
        .init(title: "Motion Picture Soundtrack", artist: "Radiohead",    durationSeconds: 414),
        .init(title: "Re: Stacks",          artist: "Bon Iver",           durationSeconds: 405),
        .init(title: "Vienna",              artist: "Billy Joel",         durationSeconds: 218),
        .init(title: "Sundress",            artist: "ASAP Rocky",         durationSeconds: 165),
        .init(title: "Pyramids",            artist: "Frank Ocean",        durationSeconds: 580),
        .init(title: "Skinny Love",         artist: "Bon Iver",           durationSeconds: 238),
        .init(title: "Holocene",            artist: "Bon Iver",           durationSeconds: 337),
        .init(title: "Strawberry Swing",    artist: "Coldplay",           durationSeconds: 249),
        .init(title: "Harvest Moon",        artist: "Neil Young",         durationSeconds: 305),
        .init(title: "Dreams",              artist: "Fleetwood Mac",      durationSeconds: 257),
    ]
}
