import SwiftUI

/// Horizontal "newsstand ticker" of friend activity that sits between the
/// Rolls feed header and the developing section. Driven by the live activity
/// feed passed in as `events`.
struct ActivityRail: View {
    let events: [ActivityEvent]
    var onTapEvent: (ActivityEvent) -> Void = { _ in }

    /// Newsstand-ticker pan speed, points per second. Slow — a drift, not a scroll.
    private let panSpeed: Double = 22
    /// Measured width of one full row of chips (single copy).
    @State private var rowWidth: CGFloat = 0
    /// Measured width of the rail itself.
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            wire
        }
        .padding(.vertical, 10)
        .background(Palette.surface.opacity(0.4))
        .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)
        .background(
            GeometryReader { g in
                Color.clear
                    .onAppear { containerWidth = g.size.width }
                    .onChange(of: g.size.width) { _, w in containerWidth = w }
            }
        )
    }

    /// One row of chips. `measured: true` reports its width for the marquee math.
    private func chipRow(measured: Bool) -> some View {
        HStack(spacing: 8) {
            ForEach(events) { ev in
                chip(ev)
            }
        }
        .background(
            Group {
                if measured {
                    GeometryReader { g in
                        Color.clear
                            .onAppear { rowWidth = g.size.width }
                            .onChange(of: g.size.width) { _, w in rowWidth = w }
                    }
                }
            }
        )
    }

    /// The ticker itself. When the chips overflow the rail it pans slowly and
    /// continuously (looping seamlessly via a doubled row); when they fit, it
    /// just sits still. The pan phase is derived from the wall clock, so data
    /// refreshes never make it jump — chips keep drifting from wherever they are.
    @ViewBuilder
    private var wire: some View {
        if rowWidth > containerWidth, containerWidth > 0 {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                let span = rowWidth + 8
                let t = ctx.date.timeIntervalSinceReferenceDate
                let offset = -CGFloat((t * panSpeed).truncatingRemainder(dividingBy: Double(span)))
                HStack(spacing: 8) {
                    chipRow(measured: true)
                    chipRow(measured: false)
                }
                .offset(x: offset)
            }
            .frame(width: max(containerWidth, 1), alignment: .leading)
            .clipped()
        } else {
            chipRow(measured: true)
                .padding(.horizontal, 16)
        }
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
