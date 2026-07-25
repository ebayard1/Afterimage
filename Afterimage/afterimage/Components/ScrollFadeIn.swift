import SwiftUI

/// Wraps a view so it fades up + in when first appearing on screen.
/// Used for cards in the Rolls feed and tile grids — kills the
/// "everything pops in at once" AI feel.
///
/// Per Emil: the per-tile entry uses Motion.expressive (550ms) instead of
/// cinematic (850ms). 850ms × 40 tiles makes the feed feel like it's catching
/// up to your scroll. Shorter durations on rapidly-repeated elements *feel*
/// faster even though more total work happens.
///
/// Opacity + offset only. This used to also animate `blur(radius: 4 → 0)`,
/// which meant every card entering the viewport ran a full-card Gaussian pass
/// — an offscreen render whose radius changed every frame, so nothing cached.
/// Worst on Profile's `LazyVStack`, where cards are instantiated mid-flick and
/// the blur spike landed on the exact frames that were already tightest.
/// Transform + opacity are the only per-frame-cheap properties (PERF_DIAGNOSIS
/// §3d); the fade-up reads the same without the softening.
///
/// Respects `accessibilityReduceMotion` — drops the transform, keeps opacity so
/// the entry signal is still visible.
struct ScrollFadeIn<Content: View>: View {
    var delay: Double = 0
    var distance: CGFloat = 24
    let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: (reduceMotion || appeared) ? 0 : distance)
            .onAppear {
                withAnimation((reduceMotion ? Motion.crisp : Motion.expressive).delay(delay)) {
                    appeared = true
                }
            }
    }
}
