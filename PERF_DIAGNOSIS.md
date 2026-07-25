# Afterimage Performance Diagnosis — 2026-07-25

Symptoms reported: device heats up quickly during local runs; scroll choppiness on the
Rolls feed and Profile page. Full-code audit of `Afterimage/afterimage` (~13.3k lines, 70 files).

---

## 1. Heat: the paged TabView keeps all three pages alive at once

`MainTabView` uses `TabView(...).tabViewStyle(.page)` (MainTabView.swift:25–37). A paged
TabView instantiates and retains **all pages simultaneously** — Rolls, Camera, and Profile
are all in the view hierarchy the whole time. Two consequences:

### 1a. The AVCaptureSession likely runs while you browse the feed
`CameraTabView` builds `CameraView`, whose `.task { await camera.start() }`
(CameraView.swift:262–274) fires when the view enters the hierarchy — not when it becomes
visible. `onDisappear { camera.stop() }` never fires because a paged TabView doesn't remove
offscreen pages from the hierarchy. So the camera sensor + `.high` (1080p) session +
preview pipeline can run from app launch, continuously, even on the Rolls/Profile tabs.
A live capture session is the single biggest heat source an app can have.

**Quick confirmation:** look for the green camera-in-use dot in the status bar while
sitting on the Rolls tab.

### 1b. All feed/profile animations keep ticking while on the camera tab
Because all pages stay mounted, the ~25 `TimelineView`s across the app tick regardless of
which tab is showing. There is no `scenePhase`/tab-selection gating anywhere.

## 2. Heat: continuous animation load, per card, forever

The feed is designed as "always breathing," and the cost compounds per card. On a feed of
N albums, **all** of this runs continuously (eager `VStack` — every card, even offscreen):

| Source | Rate | Scope | File |
|---|---|---|---|
| Ambient sunrise gradient (full-screen `RadialGradient`) | 10 Hz | 1× | HomeView.swift:72–86 |
| `LivingFilmGrain` — `Canvas` redrawing 70 random specks | 12 Hz | per card | LivingMotion.swift:92–120 |
| `FilmStripSection` — re-renders the **entire strip subtree** (6 image cells, 2 number bands, 4 sprocket strips) | 12 Hz | per card | RollPostElements.swift:290–327 |
| `warmthFlicker` (opacity oscillation) | 10 Hz | header + each section header + each card title | LivingMotion.swift:128–153 |
| `ActivityRail` marquee — re-evaluates every chip (with AsyncImages) per tick | 30 Hz | 1× | ActivityRail.swift:61–71 |
| `LivingSprocketStrip` standalone clock | 30 Hz | per developing card | LivingMotion.swift:55 |
| `PulsingDot` / `ShimmerPlaceholder` `repeatForever` | display rate | several | PulsingDot.swift, ShimmerPlaceholder.swift |
| `ScrollSheen` Metal shader (fbm noise ×3 streaks) over the whole strip, `blendMode(.plusLighter)` | every redraw | per card | ScrollSheen.swift + FilmSheen.metal |

Effect: the display can never idle down (ProMotion stays pinned high), GPU composites
grain + shader + blurs every frame, CPU re-evaluates strip layouts 12×/sec/card. This is
sustained load that produces heat *even when the phone is sitting still on the feed*.
The camera page adds its own `warmthFlicker` on the counter badge (with a double
`.shadow` bloom re-rendered at 10 Hz — shadows are offscreen blur passes) and
`FlashReadyLED` at 20 Hz.

Note: `FilmStripSection`'s comment says the TimelineView "re-renders the whole strip" — the
12 Hz clock invalidates the full subtree including `ForEach` re-evaluation and per-cell
`FilmFrameImage` views, not just a transform. This is layout work, not a cheap
GPU-transform animation.

## 3. Scroll choppiness: per-frame main-thread work during scroll

### 3a. Preference-key → @State → blur-chain invalidation, every scroll frame
`DevelopingFilmStripCard` publishes its `midY` via a `GeometryReader` preference and
updates `@State scrollGlow` on **every scroll frame** (HomeView.swift:513–529). That
invalidates the whole card body, and the sealed frames re-render with a changed
**5-deep filter chain per image**: `.saturation(0).blur(radius: 11−reveal*7)
.brightness(...).contrast(...).opacity(...).colorMultiply(...)`
(HomeView.swift:580–612). A per-frame-changing Gaussian blur radius on up to 6 images per
card is one of the most expensive things SwiftUI can do — each is an offscreen render pass
whose parameters change every frame, so nothing caches.

### 3b. CandleFlicker: mask + shadow passes at 24 Hz, only while scrolling
The edge-print flicker (RollPostElements.swift:70–119) runs a 24 Hz TimelineView per edge
band (2 per card) that is **paused when idle and active exactly while scrolling** — i.e.
it adds `overlay { warm.mask(content) }` (a mask pass) plus a 2–9pt animated `.shadow`
(another blur pass) per band per tick, precisely during the window where frame budget is
tightest. This directly stacks against scroll frame deadlines.

### 3c. Image decode on the main thread
`FilmFrameImage.load()` runs on the MainActor (view `.task`), and calls
`FilmImageCache.decodeDownsampled(data, maxDimension: 700)` **synchronously from that
context** (FilmFrameImage.swift:160) — so JPEG decode of camera images happens on the main
thread. The cache infrastructure was explicitly written to be callable from detached tasks
(comment at FilmFrameImage.swift:13–16), but the call site never detaches. Every cache-miss
photo entering the strip decodes on the main thread — a classic mid-scroll hitch, worst on
Profile where lazy cards instantiate during the flick.

### 3d. Card instantiation cost during scroll (Profile)
Profile uses a `LazyVStack`, so each `AlbumRow` materializes mid-scroll: starting 4–6
TimelineViews, a Metal shader layer, a `.task` Firestore fallback fetch
(`AlbumService.fetchShotURLs`), image loads, plus a `ScrollFadeIn` entry animation that
animates **blur** (4→0) + offset + opacity over the whole card (ScrollFadeIn.swift:24–31).
That is a heavy single-frame spike per card entering the viewport.

### 3e. Eager VStack on Home
The feed's outer `VStack` must stay eager (known layout constraint — see memory note and
HomeView.swift:104–111), which means all N cards' bodies, preferences, animations, and
comment listeners are live regardless of visibility. With more than ~6–8 albums this
multiplies every cost above.

### 3f. SheenLayer GeometryReader re-evaluation
Each card's sheen reads `geo.frame(in: .global)` in body (ScrollSheen.swift:79–95), so
every scroll frame re-evaluates the layer and pushes new shader uniforms per card. Cheap
individually; adds up across N cards on top of 3a/3b.

## 4. Redundant Firestore listeners and data work

- **Three `AlbumService` instances with identical snapshot queries** run simultaneously
  (HomeView, ProfileView, CameraTabView — all alive due to the paged TabView). Each
  snapshot re-decodes every album document ×3. Additional short-lived instances in
  RollMapView, AlbumSettingsView, JoinAlbumView, CreateAlbumView.
- **Two `NotificationService` listeners** (HomeView + ProfileView).
- **`TopCommentsBlock` starts a `CommentService` listener per revealed album**
  (TopCommentsBlock.swift:106–112). The `onDisappear` detach never fires in the feed's
  eager `VStack` (offscreen views aren't removed from the hierarchy), so the "N+1 listener
  pile-up" the comment claims to fix is still live — one comment listener per revealed
  roll, all the time.
- `AlbumService.fetchShotURLs` fallback runs per card, per surface — Home and Profile each
  fetch the same album's shots separately; results are never shared or cached.
- Every album snapshot update replaces the whole `albums` array → full feed diff/re-render.

## 5. Secondary findings (stability + polish)

1. **Both Home and Profile run 30 s `Timer.publish` tickers** that update `now` and
   re-render the entire page; `AlbumDetailView` runs a **1 s** ticker
   (AlbumDetailView.swift:18) for its countdown — a full-page invalidation every second
   while open.
2. **`DateFormatter()` allocated inside body computations** (RevealedRollCard.dateStamp —
   HomeView.swift:681, plus AlbumDetailView, CommentsSection, RollMapView). Formatter
   creation is expensive; these run on every card re-render (i.e., 12×/sec under the strip
   clock).
3. **`FilmImageCache` limits**: 240 images / 256 MB ceiling. At 700 px decodes (~2 MB each)
   the byte ceiling permits the full 240 → up to ~0.5 GB of combined budget pressure on
   older devices; memory-warning eviction churn can follow.
4. **`AsyncImage` used for avatars/grids with no downsampling** (ActivityRail, comments,
   Profile header, BentoPhotoGrid etc.) — full-res decodes for 26–92 pt cells, and the
   default URLCache is small so avatars re-fetch. Minor vs. the strip, but the same class
   of problem the FilmFrameImage cache was built to solve.
5. **`CameraController.captureContinuation` thread-safety**: set on the session queue,
   resumed/cleared from the AVFoundation delegate callback thread with no synchronization
   (CameraView.swift:1091–1104). Also a second rapid `capturePhoto` call would overwrite an
   unresumed continuation (leak → hung `await`). Guarded today only by the `isUploading`
   UI flag.
6. **`railEvents` maps the whole activity feed on every HomeView body evaluation**
   (HomeView.swift:26–38) — allocates 40 structs per render; HomeView re-renders often
   (tickers, listeners).
7. **`UIScreen.main.bounds` in card bodies** (FilmStripSection, glow math) — deprecated
   API direction and wrong under iPad multitasking / Stage Manager; harmless on iPhone.
8. **`UIImpactFeedbackGenerator` allocated per event** rather than kept prepared —
   allocation churn plus first-hit latency on each haptic.
9. **Uploads are full-quality JPEG (0.85) of the full cropped sensor frame** — no resize
   before upload. Slower uploads (radio heat on cellular), larger storage, and the strip
   then downsamples to ≤700 px anyway. A 1440–2048 px long-edge upload would be visually
   identical in-app.
10. **Debug vs release**: local device runs from Xcode are Debug builds — SwiftUI is
    substantially slower there. The issues above are real, but final judgement of scroll
    smoothness should be made on a Release build (Profile scheme / TestFlight).

## 6. What "fixed" looks like (for the upcoming plan)

Priority order by impact:

1. **Gate the camera session to tab visibility** (start on camera tab select / appear,
   stop on leave, and on `scenePhase != .active`). Biggest single heat win.
2. **Pause all ambient animation when not visible or not needed**: a single shared
   "ambient motion" clock/flag — pause TimelineViews on non-visible tabs, pause when the
   scroll view is idle for grain/strip drift if acceptable, and coalesce the many
   independent 10–30 Hz clocks into one slow shared cadence.
3. **Kill per-scroll-frame blur mutation** on sealed frames (3a): quantize `scrollGlow`
   into a few buckets, or precompute 2–3 blurred variants and crossfade opacity
   (transform/opacity only), or drive it with a shader instead of Gaussian blur.
4. **Move image decode off the main thread** (3c) and prefetch strip images.
5. **Rework CandleFlicker** to transform/opacity-only (no per-tick mask + shadow), or
   pause it during scroll instead of running only during scroll.
6. **Single shared AlbumService/NotificationService** injected via environment (like
   UserService) — one listener per query for the whole app.
7. **Comment listeners on visibility**, not hierarchy membership (e.g., `onScrollVisibilityChange`
   on iOS 18+, or defer listening until the block is expanded / near-viewport).
8. **Feed container strategy**: give cards a computable fixed height (the strip metrics
   are already aspect-driven, so height is derivable from screen width) and then move the
   Home feed to a lazy container safely — respecting the July 2026 regression noted in
   HomeView.swift:104–111 (fixed heights are the precondition that was missing).
9. Secondary cleanups: static DateFormatters, downsampled avatar loading, upload resize,
   continuation thread-safety in CameraController, prepared haptic generators, cache limit
   tuning, remove per-page 30 s tickers in favor of one shared clock.

Verification plan once fixes land: Instruments — Core Animation FPS + GPU on feed scroll,
Time Profiler main-thread during flick, Energy Log on each tab idle; confirm the camera
indicator dot is absent off-tab; thermal state via `ProcessInfo.thermalState` logging.
