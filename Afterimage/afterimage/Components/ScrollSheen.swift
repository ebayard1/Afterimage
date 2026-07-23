import SwiftUI

// MARK: - Feed scrolling environment flag
//
// Published by the Rolls feed and the Profile archive scroll views (via
// `.onScrollPhaseChange`) and consumed by `ScrollSheen` so the film glare can
// run at full strength while you scroll and ease back to a calm floor the moment
// the feed comes to rest — letting you pause on a photo without the glare
// fighting for attention.

private struct FeedScrollingKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// True while the enclosing feed/archive scroll view is actively scrolling.
    var isFeedScrolling: Bool {
        get { self[FeedScrollingKey.self] }
        set { self[FeedScrollingKey.self] = newValue }
    }
}

// MARK: - ScrollSheen
//
// A scroll-driven specular sheen for the film-strip object on every roll post.
//
// Driven by scroll position: a `GeometryReader` reads the strip's location in
// the viewport and feeds it to the `filmSheen` Metal shader as `progress`.
// Scroll → it shimmers and travels.
//
// Its *brightness* is also a pure function of that same screen position: the
// glare runs at full strength as the post enters from the top/bottom edges and
// dissolves to a calm floor (`centerFloor`) as it crosses the middle of the
// screen — so the photo you're actually looking at (centred) is clean and
// glare-free, and the sheen swells back as the post moves on. Because it tracks
// position rather than scroll *state*, it eases continuously and never snaps off
// the moment you lift your finger. No `TimelineView`, no video.
//
// The light itself (wavy front, mottled grain, iridescence, interference) lives
// in `FilmSheen.metal`. A per-card `seed` makes each post shimmer differently.
//
// Respects `accessibilityReduceMotion`: pins `progress` and the brightness so
// the sheen is a single static (but still textured) glint that never animates.

private struct ScrollSheen: ViewModifier {
    /// Per-card random seed — drives tilt, streak phases, and widths in the
    /// shader so no two posts shimmer alike.
    var seed: Double
    /// Peak brightness of the sheen (at the top/bottom edges of the screen).
    var intensity: CGFloat = 0.30

    /// Brightness floor the glare eases down to as the post reaches centre.
    static let centerFloor: CGFloat = 0.22

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                SheenLayer(seed: seed, intensity: intensity,
                           centerFloor: ScrollSheen.centerFloor, reduceMotion: reduceMotion)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

/// The actual shader-backed glint. Brightness is derived live from the strip's
/// vertical position in the viewport (via the `GeometryReader`), so it tracks
/// scroll smoothly with no state machine and no animation to drive.
private struct SheenLayer: View {
    let seed: Double
    let intensity: CGFloat
    /// Brightness the glare eases to when the strip sits at screen centre.
    let centerFloor: CGFloat
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            // Strip centre in screen space → normalized travel.
            // 0 at the bottom edge of the screen, 0.5 at centre, 1 at the top.
            let screenH = max(geo.frame(in: .global).height, UIScreen.main.bounds.height)
            let midY = geo.frame(in: .global).midY
            let progress = min(max(1 - (midY / screenH), 0), 1)
            let p = reduceMotion ? 0.5 : progress

            // Positional fade: 1 (full glare) at the top/bottom edges, easing to
            // `centerFloor` as the post crosses the middle of the screen.
            let centerness = 1 - abs(progress - 0.5) * 2          // 1 centre → 0 edges
            let fade = reduceMotion
                ? 0.85
                : centerFloor + (1 - centerFloor) * (1 - centerness)
            let baseAmp = reduceMotion ? intensity * 0.6 : intensity
            let amp = baseAmp * fade

            Rectangle()
                .fill(.black)
                .colorEffect(
                    ShaderLibrary.filmSheen(
                        .float2(geo.size),
                        .float(Float(p)),
                        .float(Float(seed)),
                        .float(Float(amp))
                    )
                )
                .blendMode(.plusLighter)   // light *added* onto the negative
        }
    }
}

extension View {
    /// Adds a scroll-driven, per-card-randomized specular sheen that sweeps
    /// across the film strip as the post moves through the viewport, and that
    /// eases to a subtle floor when the feed stops scrolling.
    /// See `ScrollSheen`, `isFeedScrolling`, and `FilmSheen.metal`.
    func scrollSheen(seed: Double, intensity: CGFloat = 0.30) -> some View {
        modifier(ScrollSheen(seed: seed, intensity: intensity))
    }
}
