import SwiftUI

/// Horizontal "newsstand ticker" of friend activity that sits between the
/// Rolls feed header and the developing section. Sample-only; reads from
/// SampleData.activityEvents.
struct ActivityRail: View {
    let events: [ActivityEvent]
    var onTapEvent: (ActivityEvent) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { idx, ev in
                        ScrollFadeIn(delay: Double(idx) * 0.04, distance: 10) {
                            chip(ev)
                        }
                    }
                }
                .padding(.horizontal, 16)
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

    private func chip(_ ev: ActivityEvent) -> some View {
        Button { onTapEvent(ev) } label: {
            HStack(spacing: 9) {
                AsyncImage(url: URL(string: "https://picsum.photos/seed/\(ev.actorPhotoSeed)/80/80")) { phase in
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
