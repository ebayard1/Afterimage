import SwiftUI
import Combine

/// Horizontal "newsstand ticker" of friend activity that sits between the
/// Rolls feed header and the developing section. Driven by the live activity
/// feed passed in as `events`.
struct ActivityRail: View {
    let events: [ActivityEvent]
    var onTapEvent: (ActivityEvent) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Measured size of ONE copy of the chip row (incl. trailing gap) — the
    /// marquee wraps on this period so the loop is seamless.
    @State private var rowSize: CGSize = .zero

    /// Marquee drift speed, points per second. Slow "news wire" crawl.
    private let crawlSpeed: Double = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            // A continuous slow crawl (like a newsroom wire), not a stepped
            // scroll. The row is duplicated and offset by a clock-driven
            // phase that wraps at one copy's width, so it loops seamlessly.
            // Static (and manually scrollable) under Reduce Motion or when
            // there's only one update.
            if reduceMotion || events.count <= 1 || rowSize == .zero {
                ScrollView(.horizontal, showsIndicators: false) {
                    measuredChipRow.padding(.horizontal, 16)
                }
            } else {
                marquee
            }
        }
        .padding(.vertical, 10)
        .background(Palette.surface.opacity(0.4))
        .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)
    }

    private var chipRow: some View {
        HStack(spacing: 8) {
            ForEach(events) { ev in
                chip(ev)
            }
        }
        .fixedSize()
    }

    /// One copy of the row that also reports its size — keeps `rowSize`
    /// current when live events arrive and the row grows.
    private var measuredChipRow: some View {
        chipRow
            .onGeometryChange(for: CGSize.self) { $0.size } action: { rowSize = $0 }
    }

    private var marquee: some View {
        // The loop period is one row copy plus the 8pt gap between copies.
        let period = rowSize.width + 8
        // Enough copies to cover the screen plus one period of travel.
        let copies = max(2, Int(ceil(UIScreen.main.bounds.width / period)) + 1)
        return TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = CGFloat((t * crawlSpeed).truncatingRemainder(dividingBy: Double(period)))
            HStack(spacing: 8) {
                measuredChipRow
                ForEach(1..<copies, id: \.self) { _ in
                    chipRow
                }
            }
            .fixedSize()
            .offset(x: -phase)
        }
        .frame(height: rowSize.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private var header: some View {
        HStack(spacing: 8) {
            PulsingDot(color: Palette.gold, size: 5)
            Text("ON THE WIRE")
                .font(.custom("Bebas Neue", size: 11)).tracking(4)
                .foregroundStyle(Palette.gold)
            Text("·  live")
                .font(.custom("Times New Roman", size: 11)).italic()
                .foregroundStyle(Palette.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    /// Prefer a real avatar URL; fall back to the picsum seed for sample mode.
    private func avatarURL(_ ev: ActivityEvent) -> URL? {
        if let urlStr = ev.actorPhotoURL, !urlStr.isEmpty { return URL(string: urlStr) }
        return URL(string: "https://picsum.photos/seed/\(ev.actorPhotoSeed)/80/80")
    }

    private func chip(_ ev: ActivityEvent) -> some View {
        Button { onTapEvent(ev) } label: {
            HStack(spacing: 9) {
                AsyncImage(url: avatarURL(ev)) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: ShimmerPlaceholder()
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay(Circle().stroke(Palette.border, lineWidth: 1))
                .overlay(
                    Image(systemName: ev.iconName)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 12, height: 12)
                        .background(Palette.gold)
                        .clipShape(Circle())
                        .offset(x: 10, y: 10)
                )

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(ev.actorUsername)
                            .font(.custom("Bebas Neue", size: 11)).tracking(1)
                            .foregroundStyle(Palette.gold)
                        Text(ev.headline)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 4) {
                        if let albumName = ev.albumName {
                            Text(albumName.uppercased())
                                .font(.custom("Bebas Neue", size: 10)).tracking(1.5)
                                .foregroundStyle(Palette.textPrimary)
                                .lineLimit(1)
                        }
                        if let detail = ev.detail {
                            Text("· \(detail)")
                                .font(.custom("Times New Roman", size: 10)).italic()
                                .foregroundStyle(Palette.textTertiary)
                                .lineLimit(1)
                        }
                        Text("· \(ev.relativeTime)")
                            .font(.custom("Menlo", size: 9)).tracking(0.5)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Palette.surface)
            .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel("\(ev.actorUsername) \(ev.headline) \(ev.albumName ?? "")")
    }
}
