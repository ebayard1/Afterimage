import Foundation

/// A single beat in the friend-activity rail at the top of the Rolls feed.
/// Each event is purely descriptive — no real-time wire-up, sample-only.
struct ActivityEvent: Identifiable, Hashable {
    enum Kind: String {
        case startedRoll      // "started a new roll"
        case addedShot        // "added a shot to NYE 2025"
        case revealedRoll     // "revealed Beach Day"
        case appearedIn       // "appeared in 3 new shots"
        case commented        // "commented on Sam's Birthday"
        case taggedYou        // "tagged you in Festival"
    }

    /// Identity derived from content, NOT a fresh UUID: the rail rebuilds its
    /// events array on every render pass, and unstable ids made SwiftUI tear
    /// down and re-animate every chip each time — the "sudden jolts."
    var id: String {
        "\(kind.rawValue)|\(actorUsername)|\(albumName ?? "")|\(detail ?? "")|\(happenedAt.timeIntervalSince1970)"
    }
    let kind: Kind
    let actorUsername: String  // e.g. "@sam_k"
    let actorPhotoSeed: String // picsum seed for avatar (sample mode)
    var actorPhotoURL: String? = nil // real avatar URL (real mode)
    let albumName: String?     // optional context album
    let detail: String?        // free-form trailing detail
    let happenedAt: Date       // for the relative timestamp

    /// Headline string ("@sam_k started a new roll · 2m ago") composed from kind.
    var headline: String {
        switch kind {
        case .startedRoll:  return "started a new roll"
        case .addedShot:    return "added a shot to"
        case .revealedRoll: return "revealed"
        case .appearedIn:   return "you appear in"
        case .commented:    return "commented on"
        case .taggedYou:    return "tagged you in"
        }
    }

    var iconName: String {
        switch kind {
        case .startedRoll:  return "plus.circle.fill"
        case .addedShot:    return "camera.fill"
        case .revealedRoll: return "sunrise.fill"
        case .appearedIn:   return "person.crop.rectangle"
        case .commented:    return "bubble.left.fill"
        case .taggedYou:    return "tag.fill"
        }
    }

    var relativeTime: String {
        let s = -happenedAt.timeIntervalSinceNow
        if s < 60       { return "now" }
        if s < 3600     { return "\(Int(s / 60))m" }
        if s < 86400    { return "\(Int(s / 3600))h" }
        return "\(Int(s / 86400))d"
    }
}
