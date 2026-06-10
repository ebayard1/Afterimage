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
/// Respects `accessibilityReduceMotion` — drops the transform + blur, keeps
/// opacity so the entry signal is still visible.
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
            .blur(radius: (reduceMotion || appeared) ? 0 : 4)
            .onAppear {
                withAnimation((reduceMotion ? Motion.crisp : Motion.expressive).delay(delay)) {
                    appeared = true
                }
            }
    }
}
