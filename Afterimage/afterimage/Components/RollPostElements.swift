import SwiftUI

// MARK: - Roll post anatomy — shared helpers
//
// The three building blocks for the canonical Afterimage post format:
//   1. FrameNumberTrack — Menlo orange "STOCK  6 ▶  7A ▶  8 ▶..." strip that
//      runs along the top and bottom of the film strip section
//
// Used by both DevelopingFilmStripCard and RevealedRollCard so the two states
// of a roll share the exact same chrome.

// MARK: - Canonical film-strip geometry
//
// Every roll post — developing (red darkroom glow) and developed (real photos)
// — renders its film strip with these exact metrics so the proportions are
// identical across the whole feed, on every device width. Frame size is driven
// by a fixed ASPECT RATIO (not a fixed height) so the strip looks the same on
// an iPhone SE as on a Pro Max — matched to the reference screenshot.
enum FilmStripMetrics {
    /// Number of frames shown per strip. 4 wide frames (per the redesign) — the
    /// frames are flex, so fewer frames simply widen to fill the row.
    static let frameCount = 4
    /// Gap between frames. A thin black rebate so each photo reads as its own
    /// framed negative separated by a slim black divider (the strip background
    /// is black, so the gap simply shows through as a divider).
    static let frameSpacing: CGFloat = 6
    /// Corner radius applied to each photo frame — a subtle round so the frames
    /// read as individual negatives rather than a flush contact sheet.
    static let frameCornerRadius: CGFloat = 6
    /// Width ÷ height of a single frame. 0.54 ≈ a tall portrait negative —
    /// taller than a 2:3/3:4 photo so each frame reads as a tall photo.
    static let frameAspect: CGFloat = 0.54
    /// Width ÷ height of the whole frame row (the 5 frames side by side).
    /// Used to give the row a fixed box so the panning reel knows its height.
    /// The thin 2pt rebates between frames are negligible at feed widths, so
    /// `frameCount * frameAspect` matches the per-frame layout to within ~3pt.
    static var rowAspect: CGFloat { CGFloat(frameCount) * frameAspect }
}

// MARK: Kodak-orange used by the frame-number track.

extension Color {
    /// The exact orange used for 35mm film edge-print labels. Kodak/Fujifilm
    /// both use a slightly muted, warm orange — never bright safety-cone.
    static let kodakEdge = Color(red: 0.83, green: 0.42, blue: 0.10)
}

// MARK: - Candle-flicker edge print
//
// The edge-print label rows read like the film base lit from behind by a warm,
// living flame: the numbers (and barcodes) breathe between a dim ember orange
// and a brighter warm amber, with a soft glow that jitters the way a candle
// does. Crucially they NEVER wash to white and NEVER hard-reset — the intensity
// is a sum of incommensurate sines (plus a slow breath), so it wanders
// organically and never snaps back to a start value the way the old sliding
// gradient did.
//
// The warm fill is painted as an overlay masked to the row's glyphs/bars, so
// the whole row flickers as one piece of backlit film. Top and bottom edges get
// different `seed` phase offsets so they don't flicker in lockstep.
//
// The flame runs AT REST and freezes DURING SCROLL — the opposite of the
// original wiring. It was previously scroll-driven ("the light steadies when
// the film stops moving"), but that put a 24 Hz mask + animated-shadow rebuild
// per band, two bands per card, into the exact window where the frame budget is
// tightest (PERF_DIAGNOSIS §3b). At rest the flame costs nothing that matters
// and is where the "living film" character actually reads; during a flick the
// eye cannot resolve a 24 Hz edge-print jitter anyway. So: `paused` ORs in
// `isFeedScrolling` alongside the standard ambient gates.
//
// Both layers are now STATIC and cacheable — the masked amber fill and its
// fixed-radius bloom never change their inputs, so the render server can keep
// the rasterized layer and the tick only animates `opacity` on it. That is the
// difference between "recompute a mask + a Gaussian every tick" and "reblend
// two cached layers", which is the whole point of PERF_DIAGNOSIS's rule 4.
// The colour ramp is preserved by fading the MAX-amber fill in over the ember
// base rather than recolouring: ember (0.83, 0.42, 0.10) at flame 0 →
// amber (1.00, 0.70, 0.28) at flame 1, identical endpoints, and the linear
// blend between them matches the old per-channel lerp exactly.
//
// Rate is 12 Hz, not 24 — `candle(t)`'s fastest term is sin(23.9·t) ≈ 3.8 Hz,
// so 12 Hz is still ~3 samples per cycle of the fastest jitter and the flicker
// reads the same.
//
// Under `accessibilityReduceMotion` the flame freezes to a steady mid-amber
// glow — no flicker, no pulse.

private struct CandleFlicker: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFeedScrolling) private var isScrolling
    @Environment(\.ambientMotionPaused) private var ambientPaused
    /// Phase offset (seconds) so separate rows flicker independently.
    var seed: Double = 0

    /// The brightest point of the ramp — a warm amber, never cream/white.
    /// Faded over the row's own ember orange by `flame`, which reproduces the
    /// old per-channel interpolation (0.83→1.00, 0.42→0.70, 0.10→0.28).
    private static let amber = Color(red: 1.00, green: 0.70, blue: 0.28)
    /// The bloom colour, unchanged from the old animated `.shadow`.
    private static let bloom = Color(red: 1.0, green: 0.72, blue: 0.36)

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0,
                                paused: reduceMotion || isScrolling || ambientPaused)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate + seed
            let flame = reduceMotion ? 0.5 : Self.candle(t)

            content
                // Bloom: a masked fill at a FIXED blur radius, sitting BEHIND
                // the glyphs exactly where the old `.shadow` did, faded by the
                // flame. Replaces `radius: 2 → 9`, which re-ran a Gaussian
                // every tick. 6pt sits mid-way through the old range; the swell
                // now reads as brightness rather than spread.
                .background {
                    Self.bloom.mask(content)
                        .blur(radius: 6)
                        .opacity(flame * 0.45)
                }
                // Static masked amber layer — inputs never change, so this
                // rasterizes once and the tick only reblends it.
                .overlay { Self.amber.mask(content).opacity(flame) }
        }
    }

    /// 0…1 candle-flame intensity. Layered sines at incommensurate frequencies
    /// give a fast organic jitter; the slow term is the flame "breathing." The
    /// frequencies share no common period, so the curve never visibly repeats
    /// or resets.
    static func candle(_ t: Double) -> Double {
        let jitterFast = 0.18 * sin(t * 11.0)
        let jitterMid  = 0.13 * sin(t * 17.3 + 1.3)
        let jitterHigh = 0.09 * sin(t * 23.9 + 4.1)
        let breath     = 0.10 * sin(t * 3.1)
        let raw = 0.5 + jitterFast + jitterMid + jitterHigh + breath
        return min(1.0, max(0.0, raw))
    }
}

extension View {
    /// Applies the backlit candle flicker to a film-strip edge-print row so all
    /// its numbers and barcodes breathe together. See `CandleFlicker`.
    func candleFlicker(seed: Double = 0) -> some View { modifier(CandleFlicker(seed: seed)) }
}

// MARK: - Film edge barcode
//
// A short run of thin vertical bars of varying width — the DX / frame barcode
// that Kodak prints along the edge of a 35mm negative next to the frame
// numbers. Deterministic from a seed so a given frame's barcode is stable and
// pans/loops with the film. Rendered in the same edge-print orange and painted
// over by `candleFlicker`, so it breathes with the numbers beside it.

struct FilmBarcode: View {
    /// Bar widths, precomputed from the seed so `ForEach` stays stable.
    private let widths: [CGFloat]
    var height: CGFloat = 11

    init(seed: Int, bars: Int = 16, height: CGFloat = 11) {
        var rng = SimpleSplitMix(seed: seed)
        self.widths = (0..<bars).map { _ in
            let r = rng.next01()
            return r < 0.55 ? 1.0 : (r < 0.85 ? 2.0 : 3.0)
        }
        self.height = height
    }

    var body: some View {
        HStack(alignment: .center, spacing: 1.5) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, w in
                Rectangle()
                    .fill(Color.kodakEdge)
                    .frame(width: w, height: height)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: FrameNumberTrack

/// Renders a strip of "STOCK  6 ▶  7A ▶  8 ▶..." labels in Menlo orange.
/// Mimics the frame-number print along the edge of a 35mm negative.
///
/// The `prefix` is the leading label (stock short code on top, `→ NAME` on
/// bottom). The numbers alternate `N`, `(N+1)A`, `N+2`, `(N+3)A` — that's the
/// real Kodak frame-numbering convention.
///
/// Implementation note: rendered inside a **disabled `ScrollView`** so the
/// text takes its natural width and anything beyond the visible area clips
/// silently — no ellipsis. This mimics a real 35mm edge print where you see
/// only the portion inside the print frame, never a truncation indicator.
struct FrameNumberTrack: View {
    let prefix: String
    let startFrame: Int
    /// How many frame ticks after the prefix. The actual visible count
    /// depends on screen width — extras clip off the right without an
    /// ellipsis.
    var count: Int = 11

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(buildString())
                .font(.custom("Menlo", size: 10)).tracking(1.5)
                .foregroundStyle(Color.kodakEdge)
                .lineLimit(1)
                .padding(.horizontal, 14).padding(.vertical, 6)
        }
        .scrollDisabled(true)
        .background(Color.black)
        .accessibilityHidden(true)
    }

    private func buildString() -> String {
        let parts: [String] = (0..<count).map { i in
            let n = startFrame + i
            let label = (i % 2 == 1) ? "\(n)A" : "\(n)"
            return "\(label) ▶"
        }
        return "\(prefix)  " + parts.joined(separator: "  ")
    }
}

// MARK: - Bottom row member avatars (small, right-aligned)
//
// Used in both card variants. Up to N visible avatars + an overflow count.

struct RollMembersRow: View {
    let memberIds: [String]
    var max: Int = 3
    var size: CGFloat = 26

    var body: some View {
        let display = Array(memberIds.prefix(max))
        let extra = memberIds.count - display.count
        return HStack(spacing: 4) {
            ForEach(Array(display.enumerated()), id: \.offset) { _, uid in
                AlbumMemberAvatar(uid: uid, size: size)
                    .overlay(Circle().stroke(Palette.border, lineWidth: 1))
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.custom("Menlo", size: 10)).tracking(0.5)
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.leading, 2)
            }
        }
        .accessibilityLabel("\(memberIds.count) contributors")
    }
}

// MARK: - FilmStripSection
//
// The entire developed-roll film strip — top sprockets, top edge numbers, the
// photo frames, bottom edge numbers, bottom sprockets — panning as ONE piece of
// film. Everything is driven by a single shared `advance` (measured in frames),
// so the perforations, the printed frame numbers, and the photos all travel
// left together at exactly the same speed.
//
// `advance` is driven purely by a single monotonic clock (`idleDrift` frames per
// second), so the film only ever inches forward — it never tracks scroll
// position, which used to make the strip lurch backward (and read as a "hard
// reset") when the feed rubber-banded or scrolled up. The `scrollSheen` glare
// keeps its own independent scroll read and is left exactly as-is.
//
// The edge numbers are rendered as per-frame cells aligned to the photo columns,
// so each frame's number rides directly above/below its photo. Both sprocket
// rows (and the dark "punched holes" overlay that sits on top of the glare) take
// the same pixel offset, keeping the whole strip locked together.
//
// Under `accessibilityReduceMotion` the shared clock is paused and the strip
// sits still on the first frames — the classic static contact-sheet look.
//
// The per-frame look is supplied by the caller via `frameContent`, so a
// developed roll renders real photos while a developing roll renders its sealed
// red negative — both panning through the exact same film mechanism.
struct FilmStripSection<Cell: View>: View {
    /// Every photo in the roll, in order. The strip cycles through all of them.
    let photoURLs: [String]
    /// Leading frame number printed on the top / bottom edge tracks.
    let startFrameTop: Int
    let startFrameBottom: Int
    /// Per-card seed for the (unchanged) specular glare.
    let sheenSeed: Double

    /// Constant pan speed in frames/second. ~0.12 ≈ one new frame every ~8s — a
    /// slow, continuous creep that loops seamlessly.
    var idleDrift: Double = 0.12

    /// Renders a single film cell for the resolved photo URL of that slot
    /// (`nil` when the roll has no photos yet). Developed rolls return the real
    /// `FilmFrameImage`; developing rolls return their blurred red negative.
    @ViewBuilder var frameContent: (URL?) -> Cell

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.ambientMotionPaused) private var ambientPaused

    private var frameCount: Int { FilmStripMetrics.frameCount }
    private var spacing: CGFloat { FilmStripMetrics.frameSpacing }

    var body: some View {
        // The card is always full-bleed (screen width) in both the feed and the
        // profile, so the strip width is simply the screen width. We deliberately
        // do NOT measure it: a self-referential GeometryReader used to fall back
        // to a narrower value on a fresh / lazily-recycled cell and sometimes
        // stick there, exposing the card surface as side margins. Any tiny
        // overshoot is clipped by the card's rounded-rect mask, so the strip can
        // only ever fill — never under-fill and leave a margin.
        let measuredW = UIScreen.main.bounds.width
        let frameW = (measuredW - spacing * CGFloat(frameCount - 1)) / CGFloat(frameCount)
        let step = frameW + spacing
        let frameH = frameW / FilmStripMetrics.frameAspect

        // 12 Hz: the idle drift moves a few points per second, so sub-frame
        // steps stay invisible — and this clock re-renders the whole strip
        // (every cell, both number bands, four sprocket rows), so it is the
        // single most expensive tick on a card. Gated on `ambientMotionPaused`
        // so it only runs for cards actually on screen, on the visible page.
        //
        // Deliberately NOT gated on `isFeedScrolling`, unlike the grain and
        // the warmth flicker: `advance` is derived from wall-clock time, so
        // stopping and restarting the clock lets `context.date` run on
        // underneath and the film visibly snaps forward on release. Visibility
        // gating has the same hazard in principle, but only for cards that
        // were off screen while it happened — where the jump is unobservable.
        TimelineView(.animation(minimumInterval: 1.0 / 12.0,
                                paused: ambientPaused || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // Monotonic, scroll-independent advance — never moves backward, so the
            // loop wraps seamlessly with no perceived hard reset.
            let advance = reduceMotion ? 0 : t * idleDrift
            let base = Int(advance.rounded(.down))
            let frac = CGFloat(advance - Double(base))
            let slide = -frac * step                  // sub-frame pixel slide
            let pannedPixels = CGFloat(advance) * step // continuous travel for sprockets

            // Edge numbers ride the OUTSIDE of the strip; the sprocket holes sit
            // INSIDE, between the numbers and the photos — matching a real
            // negative where the perforations hug the frames and the printed
            // edge codes run along the very edge of the film.
            VStack(spacing: 0) {
                numberBand(start: startFrameTop, base: base, frameW: frameW, slide: slide, width: measuredW, edgePhase: 0)
                LivingSprocketStrip(externalOffset: pannedPixels)
                frameBand(base: base, frameW: frameW, frameH: frameH, slide: slide, width: measuredW)
                LivingSprocketStrip(externalOffset: pannedPixels)
                numberBand(start: startFrameBottom, base: base, frameW: frameW, slide: slide, width: measuredW, edgePhase: 1)
            }
            .background(Color.black)
            // Glare sweeps the full height of the strip — unchanged.
            .scrollSheen(seed: sheenSeed)
            // Re-punch the holes on top of the sheen so they stay dark, using
            // the SAME pan offset so they line up with the holes underneath. The
            // clear spacers mirror the number bands (fixed) and photo band
            // (flexible) so the two re-punch rows land exactly on the sprockets.
            .overlay {
                VStack(spacing: 0) {
                    Color.clear.frame(height: numberBandHeight)
                    LivingSprocketStrip(bandBackground: .clear, externalOffset: pannedPixels)
                    Color.clear.frame(maxHeight: .infinity)
                    LivingSprocketStrip(bandBackground: .clear, externalOffset: pannedPixels)
                    Color.clear.frame(height: numberBandHeight)
                }
            }
        }
    }

    // MARK: Photo frames

    private func frameBand(base: Int, frameW: CGFloat, frameH: CGFloat, slide: CGFloat, width: CGFloat) -> some View {
        let n = max(photoURLs.count, 1)
        return HStack(spacing: spacing) {
            // One extra frame so a new photo is always waiting to slide in from
            // the right as the strip translates left.
            ForEach(0...(frameCount + 1), id: \.self) { slot in
                frameCell(globalIndex: base + slot, n: n)
                    .frame(width: frameW, height: frameH)
                    .clipShape(RoundedRectangle(cornerRadius: FilmStripMetrics.frameCornerRadius,
                                                style: .continuous))
            }
        }
        .frame(height: frameH)
        .offset(x: slide)
        // Pin to the strip width and clip. The row of fixed-width cells is wider
        // than the card, so this MUST be a concrete width — `maxWidth:.infinity`
        // lets the oversized intrinsic width leak up and stretch the whole card
        // past the screen edges.
        .frame(width: width, alignment: .leading)
        .background(Color.black)
        .clipped()
    }

    @ViewBuilder
    private func frameCell(globalIndex: Int, n: Int) -> some View {
        let url: URL? = photoURLs.isEmpty
            ? nil
            : URL(string: photoURLs[(globalIndex % n + n) % n])
        frameContent(url)
    }

    // MARK: Edge numbers — one cell per frame column, so a number rides with
    // each photo at exactly the same speed. Some cells also carry a DX-style
    // barcode next to the number, exactly as a real negative's edge print does.

    /// Fixed height of an edge-print band. Kept constant (rather than intrinsic)
    /// so the re-punch overlay can mirror it with a clear spacer of equal height
    /// and keep the sprocket holes aligned.
    private var numberBandHeight: CGFloat { 22 }

    private func numberBand(start: Int, base: Int, frameW: CGFloat, slide: CGFloat, width: CGFloat, edgePhase: Int) -> some View {
        let n = max(photoURLs.count, 1)
        return HStack(spacing: spacing) {
            ForEach(0...(frameCount + 1), id: \.self) { slot in
                let globalIndex = base + slot
                let k = (globalIndex % n + n) % n
                numberCell(globalIndex: globalIndex, start: start, k: k, frameW: frameW, edgePhase: edgePhase)
            }
        }
        .offset(x: slide)
        // Warm candle flicker across the whole edge-print row (numbers + bars),
        // applied before the black band so it masks to the glyphs/bars. Top and
        // bottom edges get different phase offsets so they don't flicker as one.
        .candleFlicker(seed: Double(edgePhase) * 2.7)
        // Concrete width (not maxWidth:.infinity) so the oversized cell row
        // can't stretch the card past the screen — see frameBand.
        .frame(width: width, height: numberBandHeight, alignment: .leading)
        .background(Color.black)
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func numberCell(globalIndex: Int, start: Int, k: Int, frameW: CGFloat, edgePhase: Int) -> some View {
        // Top edge (phase 0) prints its barcode along the TOP of the band and
        // the bottom edge (phase 1) along the BOTTOM — both barcodes touch the
        // OUTER edge of the film strip, like real edge print at the film's rim.
        let outerAlignment: Alignment = edgePhase == 0 ? .top : .bottom
        HStack(spacing: 7) {
            Text(numberLabel(start: start, k: k))
                .font(.custom("Menlo", size: 10)).tracking(1.5)
                .foregroundStyle(Color.kodakEdge)
                .lineLimit(1)
            if showsBarcode(globalIndex: globalIndex, edgePhase: edgePhase) {
                FilmBarcode(seed: globalIndex &* 2_654_435_761)
                    .frame(maxHeight: .infinity, alignment: outerAlignment)
            }
            Spacer(minLength: 0)
        }
        .frame(width: frameW, height: numberBandHeight, alignment: .leading)
    }

    /// Whether this frame column prints a barcode beside its number. Every sixth
    /// frame carries one — with `frameCount` (4) columns visible at a time, each
    /// edge shows at most one barcode in frame, sometimes none, keeping the
    /// print sparse. The bottom edge is offset by three columns so its barcodes
    /// are STAGGERED against the top edge's instead of stacking.
    private func showsBarcode(globalIndex: Int, edgePhase: Int) -> Bool {
        (((globalIndex + edgePhase * 3) % 6) + 6) % 6 == 0
    }

    /// Kodak-style alternating frame numbering: N, (N+1)A, N+2, (N+3)A …
    /// Wraps with the album length so the numbers loop together with the photos.
    private func numberLabel(start: Int, k: Int) -> String {
        let num = start + k
        return (k % 2 == 1) ? "\(num)A ▶" : "\(num) ▶"
    }
}
