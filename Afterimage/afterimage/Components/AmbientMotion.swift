import SwiftUI

// MARK: - Ambient motion gating
//
// Afterimage's "living film" look is built from ~25 perpetual
// `TimelineView(.animation(...))` clocks — film grain, sprocket drift, warmth
// flicker, the activity marquee, the sunrise wash. Left ungated they tick
// forever, on every card, on every page: the paged `TabView` keeps all three
// pages mounted at once, and the Rolls feed is a deliberately eager `VStack`,
// so nothing ever leaves the view hierarchy. The display therefore can never
// idle its refresh rate down and the CPU/GPU never get a quiet frame — that is
// sustained load with the phone sitting still, and it is the app's dominant
// heat source after the capture session itself.
//
// The fix is gating, never deletion. The motion IS the product (DESIGN.md), so
// it has to run at full quality whenever you can actually see it and cost
// nothing when you can't. `ambientMotionPaused` is the single flag that every
// ambient clock ORs into its `paused:` argument.
//
// It is published at two levels:
//   1. Per page, by `MainTabView` — true when the page is not the selected tab,
//      or when the scene is not `.active`.
//   2. Per card, by `ambientVisibilityGate()` — ORs in "this card is scrolled
//      off screen", which is what stops the offscreen cards of the eager feed.
//
// Consumers additionally OR in `accessibilityReduceMotion`, and the
// twinkle-class effects (grain, warmth flicker) also OR in `isFeedScrolling`
// so they surrender their frames during a flick, when the eye cannot resolve
// them anyway. Effects whose phase is derived from the wall clock and must not
// visibly snap on resume (the film-strip drift) are gated by visibility only.

private struct AmbientMotionPausedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// True when ambient, purely decorative motion in this subtree should stop
    /// ticking — the card is scrolled off screen, the page is not the selected
    /// tab, or the app is not foregrounded.
    var ambientMotionPaused: Bool {
        get { self[AmbientMotionPausedKey.self] }
        set { self[AmbientMotionPausedKey.self] = newValue }
    }
}

// MARK: - Per-card visibility gate

/// Widens the inherited `ambientMotionPaused` with this view's own scroll
/// visibility and republishes it to the subtree. Applied to each roll card so
/// the ones scrolled off screen stop animating — the eager `VStack` on Rolls
/// keeps them mounted forever, so visibility is the only signal available.
private struct AmbientVisibilityGate: ViewModifier {
    /// Starts `true` on purpose: `onScrollVisibilityChange` only reports after
    /// its first visibility pass, and starting paused would show a card frozen
    /// for a beat before it came alive.
    @State private var visible = true
    @Environment(\.ambientMotionPaused) private var inherited

    func body(content: Content) -> some View {
        content
            // A near-zero threshold means "any sliver on screen counts", so a
            // card is already running by the time it slides into view rather
            // than starting up halfway across the screen.
            .onScrollVisibilityChange(threshold: 0.01) { isVisible in
                visible = isVisible
            }
            // Layout-neutral by construction. This modifier only observes and
            // republishes an environment value — it adds no container, no
            // frame, no geometry reader, and never touches the size proposal
            // passed down to `content`. That matters: the Rolls cards are
            // built from flexible, screen-measured layers that collapse if
            // anything disturbs the proposed height (see the eager-`VStack`
            // comment block in `HomeView`).
            .environment(\.ambientMotionPaused, inherited || !visible)
    }
}

extension View {
    /// Pauses ambient motion inside this view while it is scrolled off screen,
    /// on top of whatever the enclosing page already published. Layout-neutral.
    /// See `AmbientVisibilityGate`.
    func ambientVisibilityGate() -> some View {
        modifier(AmbientVisibilityGate())
    }
}
