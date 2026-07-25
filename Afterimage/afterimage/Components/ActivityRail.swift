import SwiftUI
import Combine

/// Horizontal "newsstand ticker" of friend activity that sits between the
/// Rolls feed header and the developing section. Driven by the live activity
/// feed passed in as `events`.
struct ActivityRail: View {
    let events: [ActivityEvent]
    var onTapEvent: (ActivityEvent) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Which chip the ticker is parked on — advances on a timer so the rail
    /// "reads out" the wire on its own; a manual drag still works.
    @State private var tickerIndex = 0
    private let tickerTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { idx, ev in
                            ScrollFadeIn(delay: Double(idx) * 0.04, distance: 10) {
                                chip(ev)
                            }
                            .id(idx)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onReceive(tickerTimer) { _ in
                    // Auto-advance through the updates, wrapping back to the
                    // start — a slow newsstand ticker. Static under Reduce
                    // Motion or when there's nothing to cycle through.
                    guard !reduceMotion, events.count > 1 else { return }
                    tickerIndex = (tickerIndex + 1) % events.count
                    withAnimation(.easeInOut(duration: 0.7)) {
                        proxy.scrollTo(tickerIndex, anchor: .leading)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .background(Palette.surface.opacity(0.4))
        .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)
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
