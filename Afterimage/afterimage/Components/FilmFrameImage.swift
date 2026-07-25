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
/// `nonisolated` so its synthesized `Hashable`/`Equatable` conformances are too:
/// the project defaults declarations to the main actor, and this is hashed as a
/// dictionary key from inside `FilmFrameLoader`'s actor context. Without this the
/// conformance is main-actor-isolated and unusable there — a warning today, an
/// error under the Swift 6 language mode.
nonisolated enum FilmFrameTier: Sendable, Hashable {
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

/// One decoded frame, in whichever shape its tier produces.
///
/// Both tiers share a single loader (`FilmFrameLoader`) so that a URL is never
/// fetched or decoded twice, which means the one shared task per URL+tier has to
/// be able to hand back either flavour.
enum DecodedFilmFrame: Sendable {
    /// `.normal` — one downsampled colour frame.
    case single(UIImage)
    /// `.sealed` — the pre-blurred greyscale pair. See `FilmImageCache.bakeSealed`.
    case pair(SealedFramePair)
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
        // Sized against what the tiers actually decode to now that nothing is
        // cached at full camera resolution (bytes = w × h × 4):
        //
        //   • normal (strip frame, 700 px long edge)  ≈ 525 × 700  ≈ 1.5 MB
        //   • sealed PAIR (2 × 256 px long edge)      ≈ 2 × 0.2 MB ≈ 0.4 MB
        //   • full (slideshow, 2600 px long edge)     ≈ 1950 × 2600 ≈ 20 MB
        //
        // A roll card holds ~7 strip cells, so 150 entries still covers roughly
        // twenty cards' worth of frames — far more than can be on screen or one
        // flick away, which is all a cache has to reach.
        c.countLimit = 150
        // Hard byte ceiling, and the limit that actually binds: 128 MB is ~85
        // strip frames, or a slideshow's half-dozen full-screen decodes sitting
        // on top of the strips behind it. The old 256 MB ceiling was sized for
        // full-resolution decodes that no longer happen, and a resident set that
        // large mostly buys memory-warning eviction churn on older devices
        // (PERF_DIAGNOSIS §5.3).
        c.totalCostLimit = 128 << 20
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

    /// The already-decoded frame for `url` at `tier`, if it is resident.
    nonisolated static func cached(_ url: URL, tier: FilmFrameTier) -> DecodedFilmFrame? {
        switch tier {
        case .normal: shared.object(forKey: url as NSURL).map(DecodedFilmFrame.single)
        case .sealed: cachedSealedPair(url).map(DecodedFilmFrame.pair)
        }
    }

    /// Whether `url` is already resident at `tier` — used to skip prefetch work.
    nonisolated static func isCached(_ url: URL, tier: FilmFrameTier) -> Bool {
        cached(url, tier: tier) != nil
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

    // MARK: Sealed bake radii
    //
    // The sealed frame's whole contract (DESIGN.md §4.4) is that it is a
    // red-black smear you can *barely* sense a shape in and that NEVER resolves
    // into a legible photo. It used to get there with a live
    // `.blur(radius: 11 - reveal * 7)` — 11 pt at rest, 4 pt fully revealed —
    // so the baked pair has to land on those same POINT radii, and the bake is
    // specified in PIXELS. The conversion, derived from the real layout:
    //
    //   1. `FilmStripMetrics`: 4 frames separated by 6 pt rebates, in a
    //      full-bleed strip. On a 393 pt screen (the modern iPhone baseline):
    //          frameW = (393 − 6 × 3) / 4          = 93.75 pt
    //   2. `frameAspect` 0.54 (width ÷ height):
    //          frameH = 93.75 / 0.54               = 173.61 pt
    //   3. The sealed tier decodes to 256 px on the LONG edge, so a portrait
    //      photo of aspect `a` bakes to (256a × 256) px.
    //   4. `scaledToFill` uses max(frameW/imgW, frameH/imgH). The width term
    //      only wins when a < 0.54 — i.e. a photo TALLER than the already very
    //      tall cell, which no camera produces. So for every real photo
    //      (3:4 = 0.75, 2:3 = 0.667, square = 1.0) the HEIGHT term binds and
    //      the scale is one aspect-independent constant:
    //          173.61 / 256                        = 0.678 pt per baked pixel
    //
    // Hence radius_px = radius_pt / 0.678:
    //      heavy: 11 pt → 16.2 px          soft: 4 pt → 5.9 px
    //
    // The previous 14 / 5 px predate this arithmetic and landed at 9.5 pt and
    // 3.4 pt — ~14% short of the live blur they replaced, which is exactly the
    // direction a sealed frame must never err in.
    //
    // Two things stay approximate, on purpose:
    //   • Landscape shots scale up further (a 4:3 landscape lands at 0.90 pt
    //     per baked pixel, so ~14.6 pt heavy). That is MORE blur, never less,
    //     which is only ever helpful here.
    //   • The bake is cached per URL and is therefore device-independent, while
    //     the cell is not: the same radii read 10.5 / 3.8 pt on a 375 pt SE and
    //     12.4 / 4.5 pt on a 440 pt Pro Max. No single baked constant can be
    //     exact at every width; 393 pt is the width it is exact at, and wider
    //     screens (bigger cells) get proportionally more blur, which is again
    //     the safe direction.
    //
    // If `FilmStripMetrics` ever changes, re-run step 1–4 and re-derive these.

    /// Bake radius for the `heavy` variant, in bake pixels ≈ 11 pt on a 393 pt
    /// screen. Matches the old `blur(radius: 11)` at reveal 0.
    nonisolated static let sealedHeavyRadius: Double = 16.2
    /// Bake radius for the `soft` variant, in bake pixels ≈ 4 pt on a 393 pt
    /// screen. Matches the old `blur(radius: 4)` at reveal 1.
    nonisolated static let sealedSoftRadius: Double = 5.9

    /// Bake the sealed-negative pair: greyscale, pre-blurred at two fixed radii.
    ///
    /// The developing card used to render each frame through
    /// `.saturation(0).blur(radius: 11 - reveal * 7)`, with `reveal` changing on
    /// every scroll frame — an offscreen Gaussian per image whose parameters
    /// never repeated, so nothing the render server cached was ever reusable
    /// (PERF_DIAGNOSIS §3a). Baking two fixed variants here and crossfading them
    /// by opacity is visually indistinguishable and costs one blend per frame.
    ///
    /// See `sealedHeavyRadius` / `sealedSoftRadius` for how the radii are
    /// derived — they are in BAKE PIXELS, not points, and the conversion
    /// between the two is set by the film-strip geometry.
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

        guard let heavy = blurred(sealedHeavyRadius),
              let soft  = blurred(sealedSoftRadius) else { return nil }
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
    ///
    /// `decodePriority` is the priority of the detached decode. Visible cells
    /// leave it at `.userInitiated`; prefetch drops it to `.utility` so warming
    /// a frame nobody is looking at yet cannot outrank one that is on screen.
    nonisolated static func fetchAndDecode<T: Sendable>(
        url: URL,
        decodePriority: TaskPriority = .userInitiated,
        decode: @escaping @Sendable (Data) -> T?
    ) async -> LoadOutcome<T> {
        var lastReason = "no response"
        let attempts = 3
        for attempt in 0..<attempts {
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
                    let decoded = await Task.detached(priority: decodePriority) {
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
            // Backoff before RETRYING (0.3 s, 0.6 s). Nothing follows the last
            // attempt, so sleeping after it was 900 ms of pure added latency on
            // the failure path — the frame's error state was already decided.
            guard attempt < attempts - 1 else { break }
            try? await Task.sleep(for: .milliseconds(300 * (attempt + 1)))
        }
        return .failed(lastReason)
    }

    // MARK: - Loading (the only two entry points)

    /// The decoded frame for `url` at `tier`, for a cell that is on screen.
    ///
    /// Goes through `FilmFrameLoader`, so if a prefetch (or another cell showing
    /// the same photo) is already fetching this URL at this tier, this call
    /// **joins that work** instead of starting a second download and a second
    /// decode. Inserting into the cache is done for you.
    nonisolated static func frame(for url: URL,
                                  tier: FilmFrameTier = .normal) async -> LoadOutcome<DecodedFilmFrame> {
        if let hit = cached(url, tier: tier) { return .value(hit) }
        return await FilmFrameLoader.frame(for: url, tier: tier, lane: .visible)
    }

    /// Warm the cache for a card's frames ahead of first paint, then return.
    ///
    /// Without this, a card's photos decode one at a time as each cell's `.task`
    /// discovers a cache miss — which, on the feed, means during the flick that
    /// brought the card on screen.
    ///
    /// **`await` this from the card's own `.task(id:)`** rather than firing it
    /// off detached. It is structured on purpose: the task group below is a child
    /// of the caller, so when the card goes away — a scroll far enough that
    /// SwiftUI tears it down, or the user swiping from Rolls to Camera — SwiftUI
    /// cancels the `.task`, which cancels this group, which drops each frame's
    /// claim on the shared work in `FilmFrameLoader`. Work nobody is waiting for
    /// any more stops instead of competing with the capture pipeline for CPU and
    /// radio. Nothing here touches the main thread beyond the group's own
    /// bookkeeping: every fetch and every decode runs inside a detached task
    /// owned by the loader.
    ///
    /// What the caller gets, precisely:
    ///   • a URL already being fetched at this tier is joined, never restarted;
    ///   • at most `FrameLoadLimiter.permits` fetch+decode units run at once
    ///     across every film-strip load in the app, however many cards call this
    ///     in one frame (`RollSlideshowView` warms the full-screen tier through
    ///     its own path and is not counted here — it is one modal screen warming
    ///     two photos, not a feed);
    ///   • a cell that asks for a frame nothing else has started takes the next
    ///     free permit ahead of every queued prefetch. A cell that lands on a URL
    ///     a prefetch already queued shares that request, and therefore its place
    ///     in the queue — it is at worst as slow as the prefetch it replaced, and
    ///     saves the duplicate download either way.
    nonisolated static func prefetch(urls: [URL], tier: FilmFrameTier = .normal) async {
        let pending = urls.filter { !isCached($0, tier: tier) }
        guard !pending.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            for url in pending {
                // No per-call cap here on purpose: capping inside one call is
                // exactly the bug this replaced (see `FrameLoadLimiter`). These
                // children queue on the process-wide limiter, and a queued child
                // is a suspended continuation — it costs no socket and no CPU.
                group.addTask {
                    _ = await FilmFrameLoader.frame(for: url, tier: tier, lane: .prefetch)
                }
            }
        }
    }

    /// One fetch + decode + cache insert, holding a process-wide permit.
    /// Called only from `FilmFrameLoader`'s shared task — everything else goes
    /// through `frame(for:tier:)` or `prefetch(urls:tier:)`.
    nonisolated fileprivate static func performLoad(
        url: URL,
        tier: FilmFrameTier,
        lane: FrameLoadLimiter.Lane
    ) async -> LoadOutcome<DecodedFilmFrame> {
        if let hit = cached(url, tier: tier) { return .value(hit) }
        let dimension = tier.maxDimension
        let decodePriority: TaskPriority = lane == .visible ? .userInitiated : .utility
        return await FrameLoadLimiter.shared.withPermit(lane) { () async -> LoadOutcome<DecodedFilmFrame> in
            // Re-check after the queue: on a cold launch a request can sit here
            // for seconds behind a feed's worth of frames, and in that time the
            // whole reason for it may have gone away.
            if Task.isCancelled { return .cancelled }
            if let hit = cached(url, tier: tier) { return .value(hit) }
            switch tier {
            case .normal:
                let outcome = await fetchAndDecode(url: url, decodePriority: decodePriority) {
                    decodeDownsampled($0, maxDimension: dimension)
                }
                switch outcome {
                case .value(let img):
                    insert(img, forKey: url as NSURL)
                    return .value(.single(img))
                case .failed(let reason): return .failed(reason)
                case .cancelled:          return .cancelled
                }
            case .sealed:
                let outcome = await fetchAndDecode(url: url, decodePriority: decodePriority) {
                    bakeSealed($0, maxDimension: dimension)
                }
                switch outcome {
                case .value(let pair):
                    insertSealed(pair, for: url)
                    return .value(.pair(pair))
                case .failed(let reason): return .failed(reason)
                case .cancelled:          return .cancelled
                }
            }
        }
    }
}

// MARK: - Process-wide concurrency cap

/// The one place that decides how many film frames may be in flight at once.
///
/// A cap only means something if it is outside every call site. This used to be
/// `let maxInFlight = 3` *inside* the task group `prefetch()` spun up per card,
/// which bounded a single card and coordinated nothing: the Rolls feed is an
/// eager `VStack` (it has to be — see `HomeView`), so every card's
/// `.task(id: album.id)` fires in the same frame. On a cold launch with 18 rolls
/// that was 18 independent groups, i.e. up to 54 concurrent downloads and 54
/// concurrent decodes — for a developing card, two `CIGaussianBlur` passes each
/// through the shared `CIContext` — to paint the ~6 frames actually on screen.
/// With one shared limiter the same launch runs 4 units at a time, full stop.
///
/// Waiters are served in two lanes so warming does not starve a frame the user
/// is looking at: a `.visible` request takes the next free permit ahead of every
/// queued `.prefetch` one. The one case that lane ordering does NOT cover is a
/// visible cell joining a request a prefetch already put in the queue — it
/// inherits that request's place, because there is only one request. It is still
/// strictly ahead of where it would have been without the prefetch.
///
/// Scope, exactly: everything that goes through `FilmImageCache.frame(for:tier:)`
/// or `FilmImageCache.prefetch(urls:tier:)` — i.e. every strip and sealed frame
/// on the feed and on profiles. `RollSlideshowView` warms its full-screen tier by
/// calling `fetchAndDecode` directly and is outside this cap; that is a single
/// modal screen holding at most a few requests, not a feed's worth of cards.
actor FrameLoadLimiter {
    /// Which queue a request waits in.
    enum Lane: Sendable {
        /// A cell that is on screen (or one flick away) and showing a shimmer.
        case visible
        /// Cache warming for a card that has not painted its frames yet.
        case prefetch
    }

    // `nonisolated`, like everything else reachable from a detached decode task:
    // the project defaults unannotated declarations to MainActor.
    nonisolated static let shared = FrameLoadLimiter()

    /// 4 concurrent fetch+decode units, app-wide. Enough to keep a fast link
    /// busy; few enough that the decoder queue is never what drops a frame.
    nonisolated static let permits = 4

    private var active = 0
    private var visibleWaiters: [CheckedContinuation<Void, Never>] = []
    private var prefetchWaiters: [CheckedContinuation<Void, Never>] = []

    /// Run `body` holding one permit.
    ///
    /// `nonisolated` and `@Sendable` so `body` provably does NOT run on this
    /// actor — the limiter must stay free to hand out permits while work is in
    /// flight. `body` cannot throw and reports cancellation as a return value,
    /// so the permit has exactly one release path and cannot leak.
    ///
    /// Acquiring is not itself a cancellation point: a queued request that gets
    /// cancelled still takes its permit, sees `Task.isCancelled`, and returns it
    /// immediately — a couple of actor hops, no socket and no decode. That is
    /// cheaper than keeping the queue searchable.
    nonisolated func withPermit<T: Sendable>(_ lane: Lane,
                                             _ body: @Sendable () async -> T) async -> T {
        await acquire(lane)
        let value = await body()
        await release()
        return value
    }

    private func acquire(_ lane: Lane) async {
        if active < Self.permits {
            active += 1
            return
        }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            switch lane {
            case .visible:  visibleWaiters.append(c)
            case .prefetch: prefetchWaiters.append(c)
            }
        }
        // Resumed by `release()`, which hands its permit straight over. `active`
        // is deliberately untouched on this path — the count only ever changes
        // when a permit is created or destroyed, never when it changes hands, so
        // it cannot drift.
    }

    private func release() {
        if !visibleWaiters.isEmpty {
            visibleWaiters.removeFirst().resume()
        } else if !prefetchWaiters.isEmpty {
            prefetchWaiters.removeFirst().resume()
        } else {
            active -= 1
        }
    }
}

// MARK: - Request coalescing

/// De-duplicates in-flight frame loads, process-wide.
///
/// Prefetch used to dedupe only against the *completed* cache, which meant it
/// lost the race it created: a card's `prefetch` started downloading frames 1–6,
/// and microseconds later each cell's `.task(id: url)` looked in the cache, saw
/// nothing (the download was still in flight) and downloaded and baked the same
/// URL a second time. Every frame on a card's first paint cost 2× the bytes and
/// 2× the decodes — 12 CoreImage bakes per developing card instead of 6 — on
/// exactly the frames prefetch existed to make free. Prefetch only paid off on a
/// revisit.
///
/// So one task per (URL, tier) lives here, and both the prefetch path and the
/// cell path go through it. The first caller creates it; later callers await the
/// same one. The task is unstructured **on purpose**: it belongs to the loader,
/// not to whoever happened to ask first, so a consumer going away can never
/// cancel a fetch another consumer — say, a cell that is on screen — is still
/// waiting on. Each consumer holds a ticket instead, and the work is cancelled
/// exactly when the last ticket is dropped.
actor FilmFrameLoader {
    nonisolated static let shared = FilmFrameLoader()

    private struct Key: Hashable, Sendable {
        let url: URL
        let tier: FilmFrameTier
    }

    private struct Entry: Sendable {
        let task: Task<FilmImageCache.LoadOutcome<DecodedFilmFrame>, Never>
        /// Distinguishes this task from a later one for the same key, so a task
        /// finishing can only ever retire its own entry.
        let generation: Int
        /// Tickets of everyone currently waiting. The task is cancelled when —
        /// and only when — this goes empty.
        var consumers: Set<Int>
    }

    private var entries: [Key: Entry] = [:]
    private var nextTicket = 0
    private var nextGeneration = 0

    /// The decoded frame for `url` at `tier`, sharing one fetch + decode with
    /// every other caller that wants the same thing.
    ///
    /// If the calling task is cancelled this returns as soon as the shared work
    /// does, and the claim is dropped immediately rather than at that point — so
    /// a prefetch nobody wants any more stops now, while one a visible cell has
    /// also joined keeps going.
    nonisolated static func frame(for url: URL,
                                  tier: FilmFrameTier,
                                  lane: FrameLoadLimiter.Lane) async -> FilmImageCache.LoadOutcome<DecodedFilmFrame> {
        let key = Key(url: url, tier: tier)
        let (task, ticket) = await shared.join(key, lane: lane)
        let outcome = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            // Unstructured, so it is not itself cancelled, and idempotent with
            // the `leave` below — tickets are unique and never reused, so
            // dropping the same one twice is a no-op.
            Task { await shared.leave(key, ticket: ticket) }
        }
        await shared.leave(key, ticket: ticket)
        return outcome
    }

    private func join(_ key: Key,
                      lane: FrameLoadLimiter.Lane)
        -> (Task<FilmImageCache.LoadOutcome<DecodedFilmFrame>, Never>, Int) {
        nextTicket += 1
        let ticket = nextTicket
        if var entry = entries[key] {
            entry.consumers.insert(ticket)
            entries[key] = entry
            return (entry.task, ticket)
        }
        nextGeneration += 1
        let generation = nextGeneration
        // `.detached`: a `Task {}` created in an actor-isolated method inherits
        // that actor, which would run every download and bake on this actor.
        // Detached also makes it explicit that this task outlives its creator.
        // `.utility` for warming so it cannot outrank an on-screen decode; the
        // runtime escalates it if a `.userInitiated` consumer joins later.
        let task = Task<FilmImageCache.LoadOutcome<DecodedFilmFrame>, Never>
            .detached(priority: lane == .visible ? .userInitiated : .utility) {
                let outcome = await FilmImageCache.performLoad(url: key.url, tier: key.tier, lane: lane)
                await FilmFrameLoader.shared.finish(key, generation: generation)
                return outcome
            }
        entries[key] = Entry(task: task, generation: generation, consumers: [ticket])
        return (task, ticket)
    }

    /// Drop one consumer's claim. The last one out cancels the work.
    private func leave(_ key: Key, ticket: Int) {
        guard var entry = entries[key] else { return }
        entry.consumers.remove(ticket)
        if entry.consumers.isEmpty {
            entry.task.cancel()
            entries[key] = nil
        } else {
            entries[key] = entry
        }
    }

    /// Retire a finished task so the next miss starts fresh — a failed load must
    /// not be handed to the next caller as a cached verdict. Consumers already
    /// awaiting it still get its result; they just find nothing left to leave.
    private func finish(_ key: Key, generation: Int) {
        guard entries[key]?.generation == generation else { return }
        entries[key] = nil
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

        // Through the loader, not straight to the network: the card's prefetch
        // is very likely mid-download on this exact URL right now, and joining
        // that is the whole point — this used to start a second, identical
        // download and decode microseconds after the first (see
        // `FilmFrameLoader`). Everything below the call runs off the main
        // thread; only the `apply` lands back here.
        let outcome = await FilmImageCache.frame(for: url, tier: .normal)
        switch outcome {
        case .value(.single(let img)):
            apply(image: img, fail: nil)
        case .failed(let reason):
            #if DEBUG
            print("🎞️ FilmFrameImage failed [\(reason)] url=\(url.absoluteString.prefix(140))")
            #endif
            apply(image: nil, fail: reason)
        case .cancelled, .value(.pair):
            // `.pair` is unreachable — the `.normal` tier only ever decodes to
            // `.single`. Cancelled means this frame was handed a different url
            // (or the card went away); leave the state to whoever owns it now.
            return
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
                    // Soft variant crossfaded in over the heavy one, costing one
                    // blend instead of a fresh Gaussian per frame.
                    //
                    // The opacity is `r²`, NOT `r`. Crossfading two blurs of the
                    // same image is not the same operation as blurring at the
                    // radius in between: a 50/50 mix is
                    // `0.5·blur(11) + 0.5·blur(4)`, which keeps every edge the
                    // soft layer still resolves, just at half contrast, over an
                    // unstructured base. A true mid-radius Gaussian suppresses
                    // that detail outright. Linear opacity therefore made
                    // mid-reveal frames — the most common state on the feed —
                    // read more legibly than the live blur ever did, which is
                    // the one direction a sealed frame must not drift.
                    //
                    // Squaring holds the soft layer back until late: 0 → 0,
                    // 0.5 → 0.25, 1 → 1. Endpoints stay EXACT (pure heavy at
                    // rest, pure soft fully revealed) and only the middle is
                    // pulled toward the heavy blur.
                    //
                    // Squaring specifically, rather than a smoothstep: smoothstep
                    // is symmetric about 0.5 and maps 0.5 → 0.5, so it would move
                    // the shoulders around without touching the midpoint that is
                    // actually the problem.
                    //
                    // This matters most under Reduce Motion, where
                    // `SealedReveal.progress` pins `r` to exactly 0.5 forever —
                    // those users sat permanently on the leakiest point of the
                    // linear ramp and now sit at 0.25.
                    fill(pair.soft, in: geo.size)
                        .visualEffect { content, proxy in
                            let r = SealedReveal.progress(in: proxy,
                                                          viewportHeight: vh,
                                                          reduceMotion: rm)
                            return content.opacity(r * r)
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

        // Same shared loader as the prefetch above, so the two blur passes for
        // this negative happen once for the whole app, not once per asker.
        let outcome = await FilmImageCache.frame(for: url, tier: .sealed)
        switch outcome {
        case .value(.pair(let baked)):
            pair = baked
        case .failed(let reason):
            #if DEBUG
            print("🎞️ SealedFilmFrameImage failed [\(reason)] url=\(url.absoluteString.prefix(140))")
            #endif
            pair = nil
        case .cancelled, .value(.single):
            // `.single` is unreachable for the sealed tier; cancelled means the
            // frame moved on to another url.
            return
        }
    }
}
