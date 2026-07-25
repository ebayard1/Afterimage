import SwiftUI

// MARK: - Viewport height
//
// Position-driven effects (the sealed developing frames' safe-light reveal, the
// film-strip glare) need to know how tall the window is in order to normalize a
// card's `midY` into a 0…1 "where am I on screen" value.
//
// They used to read `UIScreen.main.bounds.height`. Two problems: it is
// deprecated in iOS 26, and it is simply the wrong number under Stage Manager /
// iPad multitasking, where the app's window is not the screen.
//
// The alternative — measuring per card with a `GeometryReader` — is worse, and
// deliberately not used: the roll cards are built from flexible, screen-measured
// layers and a self-referential measurement on a fresh or recycled cell can fall
// back to a stale value and stick there (see the warning comment in
// `FilmStripSection.body` explaining why the strip's own width measurement was
// reverted). So the height is measured ONCE, at the root, by `MainTabView`'s
// existing `GeometryReader`, and published down the whole tree.

private struct ViewportHeightKey: EnvironmentKey {
    /// A sane non-zero fallback so `midY / viewportHeight` can never divide by
    /// zero before the root has published a real value.
    static let defaultValue: CGFloat = 852
}

extension EnvironmentValues {
    /// Full height of the app's window, in points, published once by
    /// `MainTabView`. Use this instead of `UIScreen.main.bounds.height` for any
    /// "how far up the screen is this?" math.
    var viewportHeight: CGFloat {
        get { self[ViewportHeightKey.self] }
        set { self[ViewportHeightKey.self] = newValue }
    }
}

// MARK: - Sealed-frame reveal

/// The "surfacing from the developer" progress for a developing roll's sealed
/// negatives, as a pure function of the frame's position on screen.
///
/// Kept as a free function rather than living in a view so the sealed image
/// layers and the darkroom glow layers in `DevelopingFilmStripCard` can each
/// evaluate the identical curve inside their own `.visualEffect` — which runs
/// during rendering and never invalidates a view body. It replaced a
/// `GeometryReader` → preference → `@State` loop that wrote state on every
/// scroll frame (PERF_DIAGNOSIS §3a).
///
/// Both entry points are `nonisolated`: `.visualEffect` takes a `@Sendable`
/// closure, so it runs outside the main actor, and the project defaults every
/// unannotated declaration to MainActor.
enum SealedReveal {
    /// 0…1. Rises as the card rides UP the screen (i.e. as you scroll down the
    /// feed), so the negative barely brightens the further down you scroll.
    /// Smoothstep-eased so the emergence feels organic rather than linear.
    ///
    /// Under reduced motion this is pinned to a steady mid-reveal, matching the
    /// old `scrollGlow = 0.5` behaviour exactly.
    nonisolated static func progress(midY: CGFloat,
                                     viewportHeight: CGFloat,
                                     reduceMotion: Bool) -> Double {
        guard !reduceMotion else { return 0.5 }
        let h = max(viewportHeight, 1)
        let raw = min(max(1 - Double(midY / h), 0), 1)
        return raw * raw * (3 - 2 * raw)          // smoothstep
    }

    /// Convenience for the `.visualEffect` call sites — same coordinate space
    /// (`.global`) the old preference key published its `midY` in.
    nonisolated static func progress(in proxy: GeometryProxy,
                                     viewportHeight: CGFloat,
                                     reduceMotion: Bool) -> Double {
        progress(midY: proxy.frame(in: .global).midY,
                 viewportHeight: viewportHeight,
                 reduceMotion: reduceMotion)
    }
}
