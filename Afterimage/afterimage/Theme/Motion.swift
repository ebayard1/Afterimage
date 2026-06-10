import SwiftUI

/// Canonical animation curves for Afterimage. Use these instead of
/// `.linear`, `.easeIn`, `.easeOut`, `.easeInOut` — the built-in curves are
/// too weak; they lack the punch that makes motion feel intentional.
///
/// The cubic-bezier curves below are the iOS / Linear / Family-app strain:
/// strong ease-outs that hit fast and decelerate clean. No `easeIn` anywhere
/// — `easeIn` makes the interface feel sluggish because it delays movement
/// at the exact moment the user is watching most closely.
enum Motion {
    /// 200ms strong ease-out. The "crisp" curve — for sub-300ms state changes
    /// where the user is in a tight feedback loop (field focus, toggle, label
    /// swap, blackout fade-out). Emil's threshold: UI animations should stay
    /// under 300ms.
    static let crisp = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.20)

    /// 550ms drawer curve (from Ionic Framework, used by iOS). For sheet
    /// enters, expand/collapse panels, and other "deliberate but not slow"
    /// transitions.
    static let expressive = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.55)

    /// 850ms strong ease-out. For big reveal moments — sunrise reveal stages,
    /// scroll fade-ups in the feed, hero block intros.
    static let cinematic = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.85)

    /// Sub-second tactile spring for taps. Springs are inherently interruptible
    /// so they're ideal for rapidly-triggered presses.
    static let tap = Animation.spring(response: 0.28, dampingFraction: 0.78)

    /// Heavier spring for cards moving in/out — weight, not bounce.
    static let weighty = Animation.spring(response: 0.55, dampingFraction: 0.86)

    /// Per-item stagger delay used for cascade reveals. Default 60ms is in
    /// Emil's 30–80ms range — fast enough to feel cascaded, slow enough to
    /// register as intentional.
    static func staggered(_ index: Int, base: Double = 0.06) -> Animation {
        expressive.delay(Double(index) * base)
    }
}
