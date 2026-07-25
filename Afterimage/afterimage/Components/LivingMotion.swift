import SwiftUI

// MARK: - Living motion primitives
//
// Perpetual micro-loops that make Afterimage feel like a mechanical instrument
// instead of a static app. Every one of these is `TimelineView`-driven so the
// animation runs without state updates and never re-renders the rest of the
// view tree on each frame.
//
// Principles:
//   - Subtle by default. Each loop should be barely-perceptible individually
//     but compound across the screen into a "the app is breathing" feel.
//   - Hardware-accelerated only: transform + opacity. No layout-triggering
//     properties.
//   - Cheap enough to run on every visible card simultaneously without
//     dropping frames.
//   - **Gated, never removed.** Every clock below ORs `\.ambientMotionPaused`
//     (offscreen card / unselected tab / backgrounded app) into its `paused:`
//     argument, so motion costs nothing when nobody can see it. Gating is where
//     the savings come from — it takes these clocks to *zero* off screen, which
//     no rate cut can match — so rates are chosen for how the effect looks, not
//     to shave wakeups off something already paused.
//   - Rates are therefore per-effect, and split into two kinds:
//       * **Positional** drift (sprocket pan, marquee pan). The visible step is
//         a distance, so a slow clock is genuinely invisible: at 6 pt/sec a
//         12 Hz tick moves half a point. These run slow.
//       * **Photometric** modulation (warmth flicker, grain repaint). The
//         visible step is a luminance change, and the eye's temporal contrast
//         sensitivity *peaks* at 5–10 Hz — the worst possible place to leave a
//         residual step. These run at 24 Hz, where the 42 ms hold falls inside
//         the eye's ~50 ms temporal integration window and consecutive steps
//         fuse into a continuous ramp instead of a staircase.
//     See `AmbientMotion.swift`.

// MARK: LivingSprocketStrip
//
// Replaces the static 16-hole sprocket row with a perpetually drifting strip
// of sprocket holes. Cycle is slow (~5s) so the motion reads as "running
// film" instead of "scrolling content."

struct LivingSprocketStrip: View {
    /// Tunable period (seconds) for one full sprocket-hole cycle.
    var period: Double = 5.0
    /// Vertical strip height — matches the surrounding card padding.
    /// Geometry follows a real 35mm Kodak frame (KS-1870 perforation):
    /// hole W:H = 1.41:1, spacing = 0.70 × hole width. Holes are sized large
    /// so they read as big, distinct perforations (fewer per row).
    var height: CGFloat = 16
    var holeWidth: CGFloat = 19
    var holeHeight: CGFloat = 13.5
    var holeSpacing: CGFloat = 13
    /// Band (film) colour behind the holes. Use `.clear` to draw only the
    /// punched holes — lets this strip be overlaid on top of the glare so the
    /// holes stay dark while the film band keeps its sheen.
    var bandBackground: Color = .black
    /// When set, the strip ignores its own clock and drifts left by this many
    /// points (taken modulo the hole pitch so it recycles seamlessly). Used by
    /// `FilmStripSection` to lock the perforations to the film frames and edge
    /// numbers so the entire strip pans in unison at one speed.
    var externalOffset: CGFloat? = nil

    @Environment(\.ambientMotionPaused) private var ambientPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let ext = externalOffset {
                GeometryReader { geo in
                    holes(width: geo.size.width,
                          offset: -(ext.truncatingRemainder(dividingBy: holeWidth + holeSpacing)))
                }
            } else {
                // Standalone mode: drift on a slow private clock (used by the
                // developing card, which has no panning frames to sync to).
                // 12 Hz: one full hole-pitch takes `period` (~5s), so the strip
                // travels ~6pt/sec — well under a point per tick at 12 Hz, and
                // the 30 Hz it used to run at was pure wakeups. Paused whenever
                // the card is offscreen or the page isn't showing.
                TimelineView(.animation(minimumInterval: 1.0 / 12.0,
                                        paused: ambientPaused || reduceMotion)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let phase = (t.truncatingRemainder(dividingBy: period)) / period   // 0…1
                    GeometryReader { geo in
                        holes(width: geo.size.width, offset: -CGFloat(phase) * (holeWidth + holeSpacing))
                    }
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .background(bandBackground)
        .clipped()
        .accessibilityHidden(true)
    }

    private func holes(width: CGFloat, offset: CGFloat) -> some View {
        let pitch = holeWidth + holeSpacing
        let count = Int(width / pitch) + 2
        return HStack(spacing: holeSpacing) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Palette.background)
                    .frame(width: holeWidth, height: holeHeight)
            }
        }
        .offset(x: offset)
    }
}

// MARK: LivingFilmGrain
//
// TimelineView-driven Canvas that re-renders the grain field at 24fps with a
// deterministic per-frame seed. Every speck is repositioned each tick so the
// surface visibly twinkles instead of being static.
//
// 24 Hz because that is what the effect is imitating: film grain is a
// projection-rate phenomenon, one independent grain field per 24fps frame. The
// rate is not decorative. With only `density` (70) sparse specks, a slower
// clock holds each field long enough to individually resolve — at the 8 Hz
// this ran at, each field was held 125 ms, well past the eye's ~50 ms temporal
// integration window, so specks became trackable across a hold and the whole
// layer read as discrete "boiling" rather than continuous shimmer. At 24 Hz the
// 42 ms hold falls inside that window and the fields fuse.
//
// The clock stays cheap where it matters: it is paused off screen / off tab
// like everything else here, and additionally paused while the feed is
// *scrolling*, since a 4.5%-opacity twinkle is invisible during a flick and
// those are exactly the frames where the budget is tightest.

struct LivingFilmGrain: View {
    /// Density — number of grain specks per frame.
    var density: Int = 70
    /// Per-speck opacity.
    var opacity: Double = 0.045
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.ambientMotionPaused) private var ambientPaused
    @Environment(\.isFeedScrolling) private var isFeedScrolling

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0,
                                paused: ambientPaused || reduceMotion || isFeedScrolling)) { context in
            Canvas { ctx, size in
                // Seed from the current time bucket so the grain twinkles
                // deterministically across the population of specks. The bucket
                // multiplier MUST stay locked to the clock rate above — one new
                // field per tick. If it lags the clock, consecutive ticks land
                // in the same bucket and redraw an identical field (paying the
                // repaint for no visible change); if it leads, fields are
                // skipped.
                let bucket = Int(context.date.timeIntervalSinceReferenceDate * 24)
                var rng = SimpleSplitMix(seed: bucket)
                for _ in 0..<density {
                    let x = CGFloat(rng.next01()) * size.width
                    let y = CGFloat(rng.next01()) * size.height
                    let r = CGFloat(0.4 + rng.next01() * 0.9)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Warmth flicker (projector lamp metaphor)
//
// Subtle perpetual opacity oscillation — like the warmth of a projector bulb
// breathing. Designed to be barely perceptible per-element but to give the
// composition an overall sense of liveness when applied to multiple headlines.

struct WarmthFlicker: ViewModifier {
    /// Period of one full cycle in seconds.
    var period: Double = 3.4
    /// Lower bound of the opacity oscillation. Upper bound is always 1.0.
    var floor: Double = 0.93

    @Environment(\.ambientMotionPaused) private var ambientPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFeedScrolling) private var isFeedScrolling

    func body(content: Content) -> some View {
        // 24 Hz. This is the most-instantiated clock in the app (header, every
        // section header, every card title), which is exactly why it is worth
        // getting right rather than cheap: it is also the one whose residual
        // step is most often on screen.
        //
        // Peak per-tick alpha step is amplitude × (2π / period) / rate, where
        // amplitude is (1 − floor)/2. Quote the *deepest* call site, not the
        // shallowest — the section headers at `period: 4.4, floor: 0.82`:
        //
        //     0.09 × (2π / 4.4) / 24 = 0.09 × 1.428 / 24 ≈ 0.0054
        //
        // ~0.5% per tick. At the 6 Hz this briefly ran at that same site
        // stepped 0.021 — over 2% — and 6 Hz sits in the 5–10 Hz band where the
        // eye's temporal contrast sensitivity peaks, so a 2% luminance step
        // landed at or above the Weber threshold and the "breath" could read as
        // a visible staircase. The shallowest site (the 3.4/0.93 default) is
        // 0.0027 here; every site is under 0.6%, and the 42 ms hold is inside
        // the eye's ~50 ms integration window so the steps fuse.
        //
        // The wakeups are affordable because the gating is what does the real
        // work: paused offscreen/off-tab, and during a scroll where the flicker
        // is imperceptible anyway.
        TimelineView(.animation(minimumInterval: 1.0 / 24.0,
                                paused: ambientPaused || reduceMotion || isFeedScrolling)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let cycle = (sin(t * (2 * .pi / period)) + 1) / 2  // 0…1
            let alpha = floor + (1.0 - floor) * cycle
            content.opacity(alpha)
        }
    }
}

extension View {
    /// Applies a slow opacity oscillation to simulate a warm projector lamp.
    /// Cheap (TimelineView-driven, transform+opacity only) and safe to apply
    /// to multiple headlines on the same screen.
    func warmthFlicker(period: Double = 3.4, floor: Double = 0.93) -> some View {
        modifier(WarmthFlicker(period: period, floor: floor))
    }
}

// MARK: - Tiny seeded PRNG (shared by LivingFilmGrain)
//
// SplitMix64. Same algorithm as the SignInView grain helper but exposed here
// so multiple living-motion components can share it without duplication.

struct SimpleSplitMix {
    var state: UInt64
    init(seed: Int) {
        let s = UInt64(truncatingIfNeeded: seed)
        self.state = s &* 0x9E37_79B9_7F4A_7C15
    }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z &>> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z &>> 31)
    }
    mutating func next01() -> Double {
        Double(next() &>> 11) / Double(UInt64(1) << 53)
    }
}
