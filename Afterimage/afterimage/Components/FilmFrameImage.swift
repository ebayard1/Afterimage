import SwiftUI
import UIKit

/// Image view tailored for the 35mm film-strip frames on the Rolls feed.
///
/// Loads the image manually via URLSession so we can inspect its real
/// dimensions (something SwiftUI's `AsyncImage` doesn't surface), then:
///   - portrait images render normally with `scaledToFill`
///   - landscape images are rendered sideways (90° rotation) so their long
///     axis aligns with the tall frame — they still fill the cell instead of
///     being center-cropped into a sliver.
///
/// All photos pick up the album's `FilmStock` grade for visual identity.
struct FilmFrameImage: View {
    let url: URL?
    var stockGrade: FilmStock?

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let img = image {
                    rendered(img, in: geo.size)
                } else if didFail {
                    failedState
                } else {
                    ShimmerPlaceholder()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .task { await load() }
    }

    /// Returns the image with the right rotation + sizing for the frame.
    /// Landscape images get a 90° clockwise rotation so they fill the portrait
    /// frame "sideways" instead of being center-cropped.
    @ViewBuilder
    private func rendered(_ img: UIImage, in frameSize: CGSize) -> some View {
        let isLandscape = img.size.width > img.size.height
        if isLandscape {
            // Render the image at the SWAPPED frame dimensions, rotate 90°,
            // then constrain the outer container back to the original
            // portrait frame size. The visual result fills the cell.
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: frameSize.height, height: frameSize.width)
                .rotationEffect(.degrees(90))
                .frame(width: frameSize.width, height: frameSize.height)
                .filmStockGrade(stockGrade)
        } else {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: frameSize.width, height: frameSize.height)
                .filmStockGrade(stockGrade)
        }
    }

    private var failedState: some View {
        ZStack {
            Color(white: 0.07)
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.25))
        }
    }

    private func load() async {
        guard let url, image == nil, !didFail else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) {
                await MainActor.run { self.image = img }
                return
            }
            await MainActor.run { self.didFail = true }
        } catch {
            await MainActor.run { self.didFail = true }
        }
    }
}
