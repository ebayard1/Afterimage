import SwiftUI
import UIKit
import ImageIO
import CoreImage

/// Which decoded flavour of a photo a film cell wants.
///
/// A single photo can live in the cache more than once: the developed strip
/// wants a normal colour frame, while a developing roll wants the pre-blurred
/// greyscale pair that stands in for a sealed negative. They are baked to
/// different sizes and are not interchangeable, so each gets its own key.
enum FilmFrameTier: Sendable {
    /// Full-colour downsampled frame for a developed roll's strip.
    case normal
    /// Pre-blurred greyscale PAIR (heavy + soft) for a developing roll's sealed
    /// negative. See `FilmImageCache.bakeSealed`.
    case sealed

    /// Longest-side pixel budget for this tier's decode. `nonisolated` because
    /// the prefetch and bake paths read it from detached tasks — the project
    /// defaults every unannotated declaration to MainActor.
    nonisolated var maxDimension: CGFloat {
        switch self {
        // Film cells render ≤ ~175 pt; decoding a 12 MP camera JPEG for them
        // was a ~40× over-decode in CPU and memory.
        case .normal: 700
        // Sealed frames are ~94 pt wide AND heavily blurred — there is nothing
        // above ~256 px that could possibly survive the blur, and baking the
        // Gaussian at this size is what makes pre-blurring cheap enough to do
        // on every cache miss.
        case .sealed: 256
        }
    }
}

/// The two pre-blurred greyscale variants of one sealed negative.
/// `heavy` ≈ the old `blur(radius: 11)`, `soft` ≈ `blur(radius: 4)`; the card
/// crossfades between them by opacity instead of animating a blur radius.
struct SealedFramePair: Sendable {
    let heavy: UIImage
    let soft: UIImage
}

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

    /// Shared CoreImage context for the sealed-tier bake. Creating a `CIContext`
    /// is expensive (it spins up a GPU command queue), so there is exactly one.
    /// `nonisolated` so the detached bake tasks can reach it — `CIContext` is
    /// documented thread-safe (and declared `Sendable`).
    nonisolated private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    /// Insert with a real byte cost so `totalCostLimit` can do its job.
    nonisolated static func insert(_ image: UIImage, forKey key: NSURL) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        shared.setObject(image, forKey: key, cost: cost)
    }

    // MARK: - Cache keys
    //
    // One URL, several decoded flavours. Every non-default tier gets a `#tier=`
    // suffix so a small film-strip decode can never be served to a full-screen
    // surface, or a pre-blurred sealed frame to a developed roll.

    /// Cache key for a full-screen-tier decode of `url` (slideshow, viewer).
    nonisolated static func fullKey(_ url: URL) -> NSURL {
        NSURL(string: url.absoluteString + "#tier=full") ?? (url as NSURL)
    }

    /// Cache keys for the sealed (undeveloped-negative) pre-blur pair.
    nonisolated static func sealedHeavyKey(_ url: URL) -> NSURL {
        NSURL(string: url.absoluteString + "#tier=sealed-heavy") ?? (url as NSURL)
    }
    nonisolated static func sealedSoftKey(_ url: URL) -> NSURL {
        NSURL(string: url.absoluteString + "#tier=sealed-soft") ?? (url as NSURL)
    }

    /// The already-decoded sealed pair for `url`, if both halves are resident.
    nonisolated static func cachedSealedPair(_ url: URL) -> SealedFramePair? {
        guard let heavy = shared.object(forKey: sealedHeavyKey(url)),
              let soft  = shared.object(forKey: sealedSoftKey(url)) else { return nil }
        return SealedFramePair(heavy: heavy, soft: soft)
    }

    nonisolated static func insertSealed(_ pair: SealedFramePair, for url: URL) {
        insert(pair.heavy, forKey: sealedHeavyKey(url))
        insert(pair.soft,  forKey: sealedSoftKey(url))
    }

    /// Whether `url` is already resident at `tier` — used to skip prefetch work.
    nonisolated static func isCached(_ url: URL, tier: FilmFrameTier) -> Bool {
        switch tier {
        case .normal: shared.object(forKey: url as NSURL) != nil
        case .sealed: cachedSealedPair(url) != nil
        }
    }

    // MARK: - Decoding

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

    /// Bake the sealed-negative pair: greyscale, pre-blurred at two fixed radii.
    ///
    /// The developing card used to render each frame through
    /// `.saturation(0).blur(radius: 11 - reveal * 7)`, with `reveal` changing on
    /// every scroll frame — an offscreen Gaussian per image whose parameters
    /// never repeated, so nothing the render server cached was ever reusable
    /// (PERF_DIAGNOSIS §3a). Baking two fixed variants here and crossfading them
    /// by opacity is visually indistinguishable and costs one blend per frame.
    ///
    /// Radii are in bake pixels, not points. A 256 px frame is drawn into a
    /// ~94 × 174 pt cell with `scaledToFill`, so one baked pixel lands at
    /// roughly 0.7–0.9 pt depending on the photo's aspect: 14 px ≈ 10–13 pt
    /// (the old 11) and 5 px ≈ 3.5–4.5 pt (the old 4). The residual upscale
    /// from 256 px to the cell's device pixels softens things further, which is
    /// only ever helpful for a frame that must stay illegible.
    nonisolated static func bakeSealed(_ data: Data, maxDimension: CGFloat) -> SealedFramePair? {
        guard let base = decodeDownsampled(data, maxDimension: maxDimension),
              let cg = base.cgImage else { return nil }
        let source = CIImage(cgImage: cg)
        let extent = source.extent
        // Greyscale FIRST, so the card no longer needs `.saturation(0)` at all —
        // the only hues left after the card's `colorMultiply` are black → red,
        // which is the design rule for a sealed frame (it must never resolve
        // into a real photo).
        let mono = source.applyingFilter("CIPhotoEffectMono")

        func blurred(_ radius: Double) -> UIImage? {
            // `CIGaussianBlur` samples outside the image and returns a LARGER,
            // edge-softened extent — left alone that puts a transparent halo
            // around the frame and the cell stops being filled. Clamping first
            // extends the edge pixels infinitely; cropping back restores the
            // original extent with solid edges.
            let out = mono
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
                .cropped(to: extent)
            guard let cgOut = ciContext.createCGImage(out, from: extent) else { return nil }
            return UIImage(cgImage: cgOut)
        }

        guard let heavy = blurred(14), let soft = blurred(5) else { return nil }
        return SealedFramePair(heavy: heavy, soft: soft)
    }

    // MARK: - Fetch + off-main decode

    /// Outcome of a `fetchAndDecode` — a decoded payload, a human-readable
    /// failure reason for the DEBUG frame overlay, or "the caller went away".
    enum LoadOutcome<T: Sendable>: Sendable {
        case value(T)
        case failed(String)
        case cancelled
    }

    /// Download `url` and turn its bytes into `T`, **off the main thread**.
    ///
    /// `decode` runs inside `Task.detached`, so it must capture only `Sendable`
    /// values (`Data`, `CGFloat`, `URL`) and never the calling view. This is the
    /// fix for PERF_DIAGNOSIS §3c: the cache helpers were always written to be
    /// callable from a detached task, but the call site ran a full JPEG decode
    /// synchronously from a view `.task`, i.e. on the main thread, mid-scroll.
    ///
    /// Up to 3 attempts. Transient failures (network blips, 5xx) self-heal on
    /// retry; a 4xx (e.g. expired token / deleted object) won't, so we stop
    /// early and report it instead of hammering the network.
    nonisolated static func fetchAndDecode<T: Sendable>(
        url: URL,
        decode: @escaping @Sendable (Data) -> T?
    ) async -> LoadOutcome<T> {
        var lastReason = "no response"
        for attempt in 0..<3 {
            if Task.isCancelled { return .cancelled }
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 20
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse,
                   !(200..<300).contains(http.statusCode) {
                    lastReason = "HTTP \(http.statusCode)"
                    if (400..<500).contains(http.statusCode) { break }   // won't recover
                } else {
                    let decoded = await Task.detached(priority: .userInitiated) {
                        decode(data)
                    }.value
                    if let decoded { return .value(decoded) }
                    lastReason = "decode failed (\(data.count)B)"
                }
            } catch {
                let nsError = error as NSError
                if nsError.code == NSURLErrorCancelled { return .cancelled }  // pan swapped url
                lastReason = error.localizedDescription
            }
            // Backoff before retrying (0.3s, 0.6s).
            try? await Task.sleep(nanoseconds: UInt64(300_000_000) * UInt64(attempt + 1))
        }
        return .failed(lastReason)
    }

    // MARK: - Prefetch

    /// Warm the cache for a card's frames ahead of first paint.
    ///
    /// Fire-and-forget: returns immediately and does everything off the main
    /// thread. Without this, a card's photos decode one at a time as each cell's
    /// `.task` discovers a cache miss — which, on the feed, means during the
    /// flick that brought the card on screen.
    ///
    /// Concurrency is capped so a whole feed's worth of prefetch cannot flood
    /// the URL loading system and starve the frames that are actually visible.
    nonisolated static func prefetch(urls: [URL],
                                     maxDimension: CGFloat? = nil,
                                     tier: FilmFrameTier = .normal) {
        let pending = urls.filter { !isCached($0, tier: tier) }
        guard !pending.isEmpty else { return }
        let dimension = maxDimension ?? tier.maxDimension
        // `.utility`: visible frames decode at `.userInitiated` inside
        // `fetchAndDecode`, so a prefetch never outranks something on screen.
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                let maxInFlight = 3
                var next = 0
                while next < pending.count && next < maxInFlight {
                    let url = pending[next]; next += 1
                    group.addTask { await warm(url, maxDimension: dimension, tier: tier) }
                }
                while await group.next() != nil {
                    if Task.isCancelled { break }
                    guard next < pending.count else { continue }
                    let url = pending[next]; next += 1
                    group.addTask { await warm(url, maxDimension: dimension, tier: tier) }
                }
            }
        }
    }

    /// Download + decode one URL into the cache at `tier`. Silent on failure —
    /// a prefetch miss just means the visible cell does the work itself, with
    /// its own retry and its own DEBUG reporting.
    nonisolated private static func warm(_ url: URL,
                                         maxDimension: CGFloat,
                                         tier: FilmFrameTier) async {
        guard !isCached(url, tier: tier) else { return }
        switch tier {
        case .normal:
            let outcome = await fetchAndDecode(url: url) {
                decodeDownsampled($0, maxDimension: maxDimension)
            }
            if case .value(let img) = outcome { insert(img, forKey: url as NSURL) }
        case .sealed:
            let outcome = await fetchAndDecode(url: url) {
                bakeSealed($0, maxDimension: maxDimension)
            }
            if case .value(let pair) = outcome { insertSealed(pair, for: url) }
        }
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
            apply(image: nil, fail: nil)
            return
        }
        // Cache hit → swap in instantly, no shimmer. This is what keeps the
        // pan smooth once a photo has been seen once, and it is the fast path
        // the card's `prefetch` is trying to put every frame on.
        if let cached = FilmImageCache.shared.object(forKey: url as NSURL) {
            apply(image: cached, fail: nil)
            return
        }
        // New photo entering this frame: clear the old one so we show the
        // shimmer placeholder while it loads, rather than the previous image.
        apply(image: nil, fail: nil)

        let maxDimension = FilmFrameTier.normal.maxDimension
        // The decode itself happens inside `fetchAndDecode`'s detached task —
        // this closure captures only `Data` and `CGFloat`, never `self`.
        let outcome = await FilmImageCache.fetchAndDecode(url: url) { data in
            FilmImageCache.decodeDownsampled(data, maxDimension: maxDimension)
        }
        switch outcome {
        case .cancelled:
            return
        case .value(let img):
            FilmImageCache.insert(img, forKey: url as NSURL)
            apply(image: img, fail: nil)
        case .failed(let reason):
            #if DEBUG
            print("🎞️ FilmFrameImage failed [\(reason)] url=\(url.absoluteString.prefix(140))")
            #endif
            apply(image: nil, fail: reason)
        }
    }

    private func apply(image: UIImage?, fail: String?) {
        self.image = image
        self.failReason = fail
    }
}

// MARK: - Sealed negative (developing rolls)

/// A single undeveloped negative for `DevelopingFilmStripCard`'s film strip:
/// the real sealed shot stripped to greyscale, heavily blurred, and tinted red
/// so you can *barely* make out a shape. It never resolves into a real photo —
/// black → red only, per DESIGN.md.
///
/// As the card travels UP the screen (i.e. as you scroll down the feed) it
/// appears to "surface from the developer": the blur softens, the image lifts
/// out of the dark, and shape firms up. That progress used to be a
/// `GeometryReader` → preference → `@State` loop plus an animated blur radius —
/// a state write and six offscreen Gaussians per scroll frame. Both are gone:
///
///   • the two blur levels are **baked at decode time** (`bakeSealed`) and
///     crossfaded by opacity, and
///   • the position read happens inside `.visualEffect`, which is evaluated
///     during rendering and invalidates no view body at all.
///
/// While the photo is still loading the frame shows nothing — the card's own
/// black backing and red safe-light glow are exactly what a sealed frame should
/// look like, and it spares the strip six `repeatForever` shimmer animations
/// per developing card.
struct SealedFilmFrameImage: View {
    let url: URL?

    @Environment(\.viewportHeight) private var viewportHeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pair: SealedFramePair?

    var body: some View {
        // Read the environment into locals: the `visualEffect` closure is
        // @Sendable and must not capture `self`.
        let vh = viewportHeight
        let rm = reduceMotion

        GeometryReader { geo in
            ZStack {
                if let pair {
                    fill(pair.heavy, in: geo.size)
                    // Soft variant crossfaded in over the heavy one. A
                    // blur-11 → blur-4 crossfade is indistinguishable from
                    // animating the radius, and costs one blend instead of a
                    // fresh Gaussian.
                    fill(pair.soft, in: geo.size)
                        .visualEffect { content, proxy in
                            content.opacity(SealedReveal.progress(in: proxy,
                                                                  viewportHeight: vh,
                                                                  reduceMotion: rm))
                        }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            // Lifts out of the dark / shape firms up / emerges, all as the card
            // rides up the viewport. Same numbers as the old modifier chain,
            // now evaluated per rendered frame rather than per body rebuild.
            .visualEffect { content, proxy in
                let r = SealedReveal.progress(in: proxy, viewportHeight: vh, reduceMotion: rm)
                return content
                    .brightness(-0.34 + r * 0.30)
                    .contrast(1.0 + r * 0.25)
                    .opacity(0.85 + r * 0.15)
            }
            // Constant, so it stays a cacheable layer: tint the already-grey
            // image red. Nothing but black → red ever shows.
            .colorMultiply(Color(red: 0.80, green: 0.05, blue: 0.04))
        }
        .task(id: url) { await load() }
    }

    private func fill(_ img: UIImage, in size: CGSize) -> some View {
        Image(uiImage: img)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
    }

    private func load() async {
        guard let url else {
            pair = nil
            return
        }
        // Cache hit → straight in, no flash. `DevelopingFilmStripCard` prefetches
        // the sealed tier for its first frames, so this is the common path.
        if let cached = FilmImageCache.cachedSealedPair(url) {
            pair = cached
            return
        }
        pair = nil

        let maxDimension = FilmFrameTier.sealed.maxDimension
        // Captures only `Data` and `CGFloat`; the bake runs detached.
        let outcome = await FilmImageCache.fetchAndDecode(url: url) { data in
            FilmImageCache.bakeSealed(data, maxDimension: maxDimension)
        }
        switch outcome {
        case .cancelled:
            return
        case .value(let baked):
            FilmImageCache.insertSealed(baked, for: url)
            pair = baked
        case .failed(let reason):
            #if DEBUG
            print("🎞️ SealedFilmFrameImage failed [\(reason)] url=\(url.absoluteString.prefix(140))")
            #endif
            pair = nil
        }
    }
}
