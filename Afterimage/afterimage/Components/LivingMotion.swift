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
                // 20fps: the drift is ~6px/s, well under 1px per tick.
                TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { context in
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
// TimelineView-driven Canvas that re-renders the grain field at ~12fps with a
// deterministic per-frame seed. The dots reposition slightly each tick so the
// surface visibly twinkles instead of being static.

struct LivingFilmGrain: View {
    /// Density — number of grain specks per frame.
    var density: Int = 70
    /// Per-speck opacity.
    var opacity: Double = 0.045

    var body: some View {
        // 8fps still twinkles convincingly; every card on screen runs one of
        // these Canvases, so the tick rate is a direct feed-jank lever.
        TimelineView(.animation(minimumInterval: 1.0 / 8.0, paused: false)) { context in
            Canvas { ctx, size in
                // Seed from the current time bucket so the grain twinkles
                // deterministically across the population of specks.
                let bucket = Int(context.date.timeIntervalSinceReferenceDate * 8)
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

    func body(content: Content) -> some View {
        // 10fps is imperceptible for a multi-second sine but halves the tick
        // load — this modifier is applied to MANY headlines per screen.
        TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: false)) { context in
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

// MARK: - FlashReadyLED
//
// Camera flash status indicator — small breathing dot + microcopy. Lives in
// CameraView's top bar. Sells the "the device is on, the flash is charged"
// metaphor without any chrome.

struct FlashReadyLED: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = (sin(t * 1.6) + 1) / 2  // ~3.9s cycle
            HStack(spacing: 5) {
                Circle()
                    .fill(Palette.red)
                    .frame(width: 6, height: 6)
                    .opacity(0.55 + 0.45 * pulse)
                    .shadow(color: Palette.red.opacity(0.6 * pulse), radius: 5)
                Text("FLASH READY")
                    .font(.custom("Bebas Neue", size: 9)).tracking(2)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .accessibilityHidden(true)
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
