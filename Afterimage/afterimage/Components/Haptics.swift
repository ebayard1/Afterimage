import UIKit

// MARK: - Shared, prepared feedback generators
//
// Every haptic in the app used to allocate its generator inline
// (`UIImpactFeedbackGenerator(style: .soft).impactOccurred()`), which pays two
// costs on every single tap: the allocation itself, and — far more visible —
// the Taptic Engine spin-up latency, because a generator that has never been
// `prepare()`d has to wake the hardware before it can fire. That shows up as a
// haptic landing a beat after the tap that caused it (PERF_DIAGNOSIS §5.8).
//
// One long-lived generator per style, kept warm: each helper fires and then
// immediately calls `prepare()` again, so the engine stays in its ready state
// through a burst of taps and idles back down on its own a few seconds later.
//
// **The style and intensity at each call site are tuned — a helper here must
// never quietly change them.** Anything needing a different intensity passes it
// through; anything needing a style not listed here gets a new helper rather
// than being folded into an existing one.
//
// `CameraView` deliberately keeps its own inline generators: its shutter and
// zoom-dial haptics fire from tight gesture loops with their own preparation
// lifecycle.
enum Haptics {
    // Held for the process lifetime — they are tiny, and surviving between taps
    // is the entire point.
    private static let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Sharp, dry tap — mode switches and hard mechanical actions.
    static func rigid(intensity: CGFloat? = nil) {
        fire(impactRigid, intensity: intensity)
    }

    /// The heaviest thump — reveal moments and other one-per-session beats.
    static func heavy(intensity: CGFloat? = nil) {
        fire(impactHeavy, intensity: intensity)
    }

    /// Standard press — the system's neutral impact weight.
    static func medium(intensity: CGFloat? = nil) {
        fire(impactMedium, intensity: intensity)
    }

    /// Small, quick tick.
    static func light(intensity: CGFloat? = nil) {
        fire(impactLight, intensity: intensity)
    }

    /// The app's default touch: cushioned, used for most button taps.
    static func soft(intensity: CGFloat? = nil) {
        fire(impactSoft, intensity: intensity)
    }

    /// Discrete "moved to a new value" tick — pickers, tabs, toggles.
    static func selectionChanged() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    /// Outcome feedback for a completed operation.
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }

    /// `impactOccurred()` and `impactOccurred(intensity:)` are different calls,
    /// not the same one with a default — passing 1.0 is NOT equivalent to
    /// omitting it, so the nil case has to take the no-argument path.
    private static func fire(_ generator: UIImpactFeedbackGenerator,
                             intensity: CGFloat?) {
        if let intensity {
            generator.impactOccurred(intensity: intensity)
        } else {
            generator.impactOccurred()
        }
        // Re-arm for the next hit; this is what removes the first-tap lag.
        generator.prepare()
    }
}
