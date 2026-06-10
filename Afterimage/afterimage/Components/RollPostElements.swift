import SwiftUI

// MARK: - Roll post anatomy — shared helpers
//
// The three building blocks for the canonical Afterimage post format:
//   1. FrameNumberTrack — Menlo orange "STOCK  6 ▶  7A ▶  8 ▶..." strip that
//      runs along the top and bottom of the film strip section
//   2. StockPill — deep-wine red pill with a camera glyph + stock name
//   3. SoundtrackPill — dark pill with note glyph + soundtrack title
//
// Used by both DevelopingFilmStripCard and RevealedRollCard so the two states
// of a roll share the exact same chrome.

// MARK: Kodak-orange used by the frame-number track.

extension Color {
    /// The exact orange used for 35mm film edge-print labels. Kodak/Fujifilm
    /// both use a slightly muted, warm orange — never bright safety-cone.
    static let kodakEdge = Color(red: 0.83, green: 0.42, blue: 0.10)
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

// MARK: StockPill

/// Deep-wine red pill that surfaces the album's film stock. Camera glyph on
/// the left, stock short code in Menlo. Reads like a stamp.
///
/// All text is locked to one line + `fixedSize` so the pill never gets
/// squeezed into a multi-line vertical stack when sharing a row with other
/// pills — that's what was producing the broken "CINESTIL\nL 800T" wrap.
struct StockPill: View {
    let stock: FilmStock

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(stockTint.opacity(0.55))
                    .frame(width: 20, height: 14)
                Image(systemName: "camera.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(stockTint)
            }
            Text(stock.shortCode)
                .font(.custom("Menlo", size: 10)).tracking(1.5)
                .foregroundStyle(stockTint)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(
            Capsule().fill(stockBackground)
                .overlay(Capsule().stroke(stockBorder, lineWidth: 1))
        )
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Film stock: \(stock.displayName)")
    }

    /// Pink/coral foreground color, derived from Palette.red but lightened so
    /// it sits comfortably on the deep-wine background.
    private var stockTint: Color {
        Color(red: 0.95, green: 0.62, blue: 0.62)
    }

    private var stockBackground: Color {
        // Deeper than Palette.darkRed so the pill reads as its own object.
        Color(red: 0.22, green: 0.05, blue: 0.07)
    }

    private var stockBorder: Color {
        Color(red: 0.45, green: 0.13, blue: 0.16)
    }
}

// MARK: SoundtrackPill

/// Dark pill with a music note + soundtrack title in Menlo. Lower visual
/// weight than StockPill — it's contextual flavor, not identity.
struct SoundtrackPill: View {
    let soundtrack: Soundtrack

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
            Text(soundtrack.title.uppercased())
                .font(.custom("Menlo", size: 10)).tracking(1.5)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(
            Capsule().fill(Palette.background.opacity(0.6))
                .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
        )
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Soundtrack: \(soundtrack.title) by \(soundtrack.artist)")
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
