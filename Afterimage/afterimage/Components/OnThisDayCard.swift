import SwiftUI

/// A revealed roll from a previous year on today's calendar day.
struct OnThisDayMemory {
    let yearsAgo: Int
    let album: Album
    let teaserPhotoURL: String?
}

/// "1 YEAR AGO TODAY" surfacing card. Sits between the activity rail and the
/// rolls list when there's a memory worth recalling. Tap to open the album.
struct OnThisDayCard: View {
    let memory: OnThisDayMemory
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                teaserImage
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(memory.yearsAgo) YEAR AGO TODAY")
                        .font(.custom("Bebas Neue", size: 11)).tracking(4)
                        .foregroundStyle(Palette.darkRed)
                    Text(memory.album.name.uppercased())
                        .font(.custom("Bebas Neue", size: 22)).tracking(2)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let loc = memory.album.mapLocationName {
                            Image(systemName: "mappin").font(.system(size: 9))
                                .foregroundStyle(Palette.textTertiary)
                            Text(loc.uppercased())
                                .font(.custom("Bebas Neue", size: 10)).tracking(1.5)
                                .foregroundStyle(Palette.textTertiary)
                        }
                        Text("· tap to revisit")
                            .font(.custom("Times New Roman", size: 11)).italic()
                            .foregroundStyle(Palette.gold)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.gold)
            }
            .padding(12)
            .background(
                ZStack {
                    // Subtle warm ember backdrop — different feel from the gold-only cards.
                    LinearGradient(
                        colors: [Palette.darkRed.opacity(0.18), Palette.surface],
                        startPoint: .leading, endPoint: .trailing
                    )
                    Palette.surface.opacity(0.4)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(LinearGradient(
                        colors: [Palette.darkRed, Palette.gold.opacity(0.4)],
                        startPoint: .leading, endPoint: .trailing), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .pressEffect()
        .warmShadow(radius: 8, y: 4, opacity: 0.35)
        .accessibilityLabel("\(memory.yearsAgo) year ago today: \(memory.album.name). Double-tap to revisit.")
    }

    @ViewBuilder
    private var teaserImage: some View {
        if let url = memory.teaserPhotoURL.flatMap(URL.init) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: ShimmerPlaceholder()
                }
            }
            .frame(width: 64, height: 64)
            .clipped()
            .overlay(Rectangle().stroke(Palette.darkRed.opacity(0.5), lineWidth: 1))
            .accessibilityHidden(true)
        } else {
            ZStack {
                Rectangle().fill(Palette.darkRed.opacity(0.25))
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(Palette.gold)
            }
            .frame(width: 64, height: 64)
        }
    }
}
