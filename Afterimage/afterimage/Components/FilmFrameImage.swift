import SwiftUI
import UIKit
import ImageIO

/// Process-wide cache for decoded film-strip frames, keyed by URL.
///
/// The Rolls reel pans through the whole album as you scroll, so the same photo
/// flows in and out of the visible frames repeatedly. Caching the decoded
/// `UIImage` means a photo is fetched + decoded once; every subsequent time it
/// re-enters a frame it appears instantly with no shimmer, keeping the pan
/// smooth instead of re-hitting the network on each swap.
enum FilmImageCache {
    // nonisolated(unsafe): NSCache is documented thread-safe, and the whole
    // point of these helpers is to be callable from detached decode tasks —
    // under the project's default MainActor isolation they'd otherwise hop
    // every decode back onto the main thread.
    nonisolated(unsafe) static let shared: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 240          // plenty for several full rolls on screen
        // Hard byte ceiling — without it, 240 full-res decodes could pin
        // multiple GB and ride the app into memory-pressure churn.
        c.totalCostLimit = 256 << 20
        return c
    }()

    /// Insert with a real byte cost so `totalCostLimit` can do its job.
    nonisolated static func insert(_ image: UIImage, forKey key: NSURL) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        shared.setObject(image, forKey: key, cost: cost)
    }

    /// Cache key for a full-screen-tier decode of `url` (slideshow, viewer) —
    /// distinct from the plain-url key so a small film-strip decode can never
    /// be served to a full-screen surface, or vice versa.
    nonisolated static func fullKey(_ url: URL) -> NSURL {
        NSURL(string: url.absoluteString + "#tier=full") ?? (url as NSURL)
    }

    /// Decode `data` downsampled so its longest side is at most `maxDimension`
    /// pixels, with the bitmap decoded immediately (off the render path).
    /// Full-camera JPEGs are far bigger than any screen; decoding them at
    /// display size is dramatically cheaper in CPU and memory.
    nonisolated static func decodeDownsampled(_ data: Data, maxDimension: CGFloat) -> UIImage? {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts) else {
            return UIImage(data: data)
        }
        let thumbOpts = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cg)
    }
}

/// Image view tailored for the 35mm film-strip frames on the Rolls feed.
///
/// Loads the image manually via URLSession so we can inspect its real
/// dimensions (something SwiftUI's `AsyncImage` doesn't surface), then:
///   - portrait images render normally with `scaledToFill`
///   - landscape images are rendered sideways (90° rotation) so their long
///     axis aligns with the tall frame — they still fill the cell instead of
///     being center-cropped into a sliver.
///
struct FilmFrameImage: View {
    let url: URL?

    @State private var image: UIImage?
    @State private var failReason: String?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let img = image {
                    rendered(img, in: geo.size)
                } else if failReason != nil {
                    failedState
                } else {
                    ShimmerPlaceholder()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        // Re-run whenever the frame is handed a different photo — the reel
        // swaps `url` in place as it pans through the album, so the load must
        // track the url, not just the view's lifetime.
        .task(id: url) { await load() }
    }

    /// Renders the photo with one consistent rule for EVERY frame: center-crop
    /// fill. Portrait and landscape shots are treated identically (no sideways
    /// rotation) so a roll never shows mixed orientations — the crop you see in
    /// the strip matches what the camera framed.
    @ViewBuilder
    private func rendered(_ img: UIImage, in frameSize: CGSize) -> some View {
        Image(uiImage: img)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: frameSize.width, height: frameSize.height)
    }

    private var failedState: some View {
        ZStack {
            Color(white: 0.07)
            VStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.25))
                #if DEBUG
                // Surface the real reason (e.g. "HTTP 403", "HTTP 404") right in
                // the frame so a failing load is diagnosable from a screenshot.
                if let failReason {
                    Text(failReason)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 2)
                }
                #endif
            }
        }
    }

    private func load() async {
        guard let url else {
            await apply(image: nil, fail: nil)
            return
        }
        // Cache hit → swap in instantly, no shimmer. This is what keeps the
        // pan smooth once a photo has been seen once.
        if let cached = FilmImageCache.shared.object(forKey: url as NSURL) {
            await apply(image: cached, fail: nil)
            return
        }
        // New photo entering this frame: clear the old one so we show the
        // shimmer placeholder while it loads, rather than the previous image.
        await apply(image: nil, fail: nil)

        // Up to 3 attempts. Transient failures (network blips, 5xx) self-heal
        // on retry; a 4xx (e.g. expired token / deleted object) won't, so we
        // stop early and report it instead of hammering the network.
        var lastReason = "no response"
        for attempt in 0..<3 {
            if Task.isCancelled { return }
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 20
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse,
                   !(200..<300).contains(http.statusCode) {
                    lastReason = "HTTP \(http.statusCode)"
                    if (400..<500).contains(http.statusCode) { break }   // won't recover
                } else if let img = FilmImageCache.decodeDownsampled(data, maxDimension: 700) {
                    // Film cells render ≤ ~175 pt; decoding a 12 MP camera JPEG
                    // for them was a ~40× over-decode in CPU and memory.
                    FilmImageCache.insert(img, forKey: url as NSURL)
                    await apply(image: img, fail: nil)
                    return
                } else {
                    lastReason = "decode failed (\(data.count)B)"
                }
            } catch {
                let nsError = error as NSError
                if nsError.code == NSURLErrorCancelled { return }        // pan swapped url
                lastReason = error.localizedDescription
            }
            // Backoff before retrying (0.3s, 0.6s).
            try? await Task.sleep(nanoseconds: UInt64(300_000_000) * UInt64(attempt + 1))
        }
        #if DEBUG
        print("🎞️ FilmFrameImage failed [\(lastReason)] url=\(url.absoluteString.prefix(140))")
        #endif
        await apply(image: nil, fail: lastReason)
    }

    @MainActor
    private func apply(image: UIImage?, fail: String?) {
        self.image = image
        self.failReason = fail
    }
}
