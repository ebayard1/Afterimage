import SwiftUI

/// Full-screen, Snapchat-recap-style slideshow for a revealed roll.
///
/// Opened from the Rolls feed (HomeView) as a `.fullScreenCover`. Navigation:
///   • segmented progress bars across the top, one per photo
///   • photos auto-advance on timed cues
///   • tap right half = next · tap left half = previous
///   • press-and-hold pauses; releasing resumes
///   • swipe down to dismiss · advancing past the last photo dismisses
///
/// Modeled on RecapView's look + gesture physics, so it shares the app's feel.
struct RollSlideshowView: View {
    let album: Album
    /// Shots passed in by the caller (sample mode). In real mode this is empty
    /// and we load the album's shots live via `shotService`.
    private let initialShots: [Shot]
    /// Effective shots used throughout the view.
    private var shots: [Shot] { initialShots.isEmpty ? shotService.shots : initialShots }

    init(album: Album, shots: [Shot]) {
        self.album = album
        self.initialShots = shots
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @State private var shotService = ShotService()

    @State private var index: Int = 0
    @State private var prevIndex: Int = 0             // outgoing photo, drawn beneath
    @State private var frontOpacity: CGFloat = 1      // incoming photo fades 0→1 over it
    @State private var progress: CGFloat = 0          // 0…1 fill of current bar
    @State private var isPaused: Bool = false
    @State private var timer: Timer?

    // Gesture bookkeeping for a single press.
    @State private var pressStart: Date?
    @State private var startX: CGFloat = 0
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    @State private var holdWork: DispatchWorkItem?

    /// Press longer than this (without moving) = pause.
    private let holdSeconds: Double = 0.18

    // ── Timed cues ──────────────────────────────────────────────────────────
    // Each photo's on-screen seconds. Constant placeholder for now; later this
    // is where real beat/cue timings synced to the track would plug in.
    private let secondsPerPhoto: Double = 4.0
    private func cue(forIndex _: Int) -> Double { secondsPerPhoto }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Two-layer crossfade: the outgoing photo stays fully opaque
                // underneath while the incoming photo fades in on top — so the
                // transition never passes through black.
                if prevIndex != index,
                   prevIndex >= 0, prevIndex < shots.count,
                   let prevURL = URL(string: shots[prevIndex].photoURL) {
                    SlideshowPhoto(url: prevURL, progress: 1.0)
                        .ignoresSafeArea()
                }
                if let shot = currentShot, let url = URL(string: shot.photoURL) {
                    SlideshowPhoto(url: url, progress: progress)
                        .ignoresSafeArea()
                        .opacity(frontOpacity)
                }

                LinearGradient(colors: [.black.opacity(0.5), .clear, .black.opacity(0.85)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Gesture catcher: tap (l/r), press-and-hold, swipe-down. Sits
                // above the photo but below the interactive close button.
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(pressGesture(width: geo.size.width))

                // Non-interactive chrome — lets taps fall through to the catcher.
                VStack(spacing: 0) {
                    progressBars
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                    metaRow
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                    // Film-roll perforations bracketing the frame — the photo
                    // reads as a single running negative as you flip through.
                    filmEdge
                        .padding(.top, 12)
                    Spacer()
                    filmEdge
                    if isPaused { pausedPill.padding(.top, 12).padding(.bottom, 4) }
                    captionBlock
                        .padding(.horizontal, 22)
                        .padding(.top, 14)
                        .padding(.bottom, 28)
                }
                .allowsHitTesting(false)

                // Interactive close affordance (taps beat the gesture catcher).
                VStack {
                    HStack {
                        Spacer()
                        closeButton
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }
            .offset(y: dragOffset)
            .scaleEffect(dragOffset > 0 ? max(0.9, 1 - dragOffset / 1600) : 1)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let id = album.id {
                shotService.startListening(albumId: id, currentUserId: auth.uid ?? "")
            }
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Chrome

    private var progressBars: some View {
        HStack(spacing: 3) {
            ForEach(shots.indices, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(0.28))
                    .frame(height: 2.5)
                    .overlay(
                        GeometryReader { g in
                            Capsule()
                                .fill(.white)
                                .frame(width: g.size.width * fill(forIndex: i))
                        }
                    )
            }
        }
    }

    private func fill(forIndex i: Int) -> CGFloat {
        if i < index { return 1 }
        if i == index { return min(1, max(0, progress)) }
        return 0
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            Circle().fill(Palette.surface)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text(album.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(index + 1) / \(shots.count)")
                    .font(.custom("Menlo", size: 9)).tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var captionBlock: some View {
        // The author's caption (Shot.note), printed on the frame. Nothing if absent.
        if let note = currentShot?.note, !note.isEmpty {
            Text("\u{201C}\(note)\u{201D}")
                .font(.custom("Times New Roman", size: 16)).italic()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
                .id(index)
        }
    }

    /// A single drifting 35mm perforation band — used top and bottom to frame
    /// the slideshow photo in "running film" chrome.
    private var filmEdge: some View {
        LivingSprocketStrip(bandBackground: .black.opacity(0.78))
            .overlay(Rectangle().fill(Palette.gold.opacity(0.10)).frame(height: 1), alignment: .top)
            .overlay(Rectangle().fill(Palette.gold.opacity(0.10)).frame(height: 1), alignment: .bottom)
    }

    private var pausedPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "pause.fill").font(.system(size: 9, weight: .bold))
            Text("PAUSED").font(.custom("Bebas Neue", size: 12)).tracking(2)
        }
        .foregroundStyle(Palette.gold)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.black.opacity(0.55))
        .clipShape(Capsule())
    }

    private var closeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            dismissSlideshow()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.75))
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.6), radius: 6, y: 1)
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel("Close slideshow")
    }

    private var currentShot: Shot? {
        guard index >= 0 && index < shots.count else { return nil }
        return shots[index]
    }

    // MARK: - Gesture

    private func pressGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pressStart == nil {
                    pressStart = Date()
                    startX = value.startLocation.x
                    let work = DispatchWorkItem { beginHoldPause() }
                    holdWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + holdSeconds, execute: work)
                }
                let dy = value.translation.height
                let dx = value.translation.width
                if !isDragging, dy > 10, dy > abs(dx) {
                    // it's a downward swipe — not a hold
                    cancelHold()
                    if isPaused { endHoldPause() }
                    isDragging = true
                }
                if isDragging { dragOffset = max(0, dy) }
            }
            .onEnded { value in
                cancelHold()
                let started = pressStart
                let wasHold = isPaused && !isDragging
                pressStart = nil

                if wasHold {
                    endHoldPause()
                    return
                }
                if isDragging {
                    isDragging = false
                    let elapsedMs = max(1, Date().timeIntervalSince(started ?? Date()) * 1000)
                    let velocity = value.translation.height / elapsedMs
                    if value.translation.height > 100 || (value.translation.height > 24 && velocity > 0.11) {
                        dismissSlideshow()
                    } else {
                        withAnimation(Motion.tap) { dragOffset = 0 }
                    }
                    return
                }
                // plain tap: right half = next, left half = previous
                if startX > width / 2 { goNext() } else { goPrev() }
            }
    }

    private func beginHoldPause() {
        guard pressStart != nil, !isDragging else { return }
        isPaused = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func endHoldPause() {
        isPaused = false
    }

    private func cancelHold() {
        holdWork?.cancel()
        holdWork = nil
    }

    // MARK: - Navigation

    private func goNext() {
        if index >= shots.count - 1 {
            dismissSlideshow()                    // past the last photo = dismiss
        } else {
            transition(to: index + 1)
        }
    }

    private func goPrev() {
        transition(to: max(0, index - 1))
    }

    /// Hard cut to another photo — no fade, ever. The outgoing frame stays
    /// beneath (as a no-black backstop) until the incoming photo has loaded, then
    /// the incoming one snaps in instantly.
    private func transition(to newIndex: Int) {
        guard newIndex != index else { return }
        prevIndex = index
        index = newIndex
        progress = 0
        frontOpacity = 1   // instant — hard cut
    }

    private func dismissSlideshow() {
        stopTimer()
        dismiss()
    }

    // MARK: - Auto-advance timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                if isPaused { return }            // press-and-hold freezes progress
                if shots.isEmpty { return }       // real mode: still loading
                progress += 0.05 / cue(forIndex: index)
                if progress >= 1.0 {
                    if index >= shots.count - 1 {
                        dismissSlideshow()
                    } else {
                        transition(to: index + 1)
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Orientation-aware slideshow photo

/// One full-screen slideshow frame. Loads the `UIImage` (so it can read the real
/// orientation) and animates per the spec:
///   • VERTICAL photos sit still, fully visible (scaledToFit) — no pan/zoom.
///   • HORIZONTAL photos start zoomed-in and pan across, then zoom out to reveal
///     the whole frame, driven by `progress` (0…1).
private struct SlideshowPhoto: View {
    let url: URL?
    let progress: CGFloat

    @State private var image: UIImage?

    /// Fraction of the photo's life spent panning before the zoom-out begins.
    private let panEnd: CGFloat = 0.6

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let img = image {
                    if img.size.width > img.size.height {
                        landscape(img, in: geo.size)
                    } else {
                        // Vertical — fully visible and frozen.
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                } else {
                    // Transparent while loading so the previous frame underneath
                    // stays visible — gives a clean hard cut with no flash.
                    Color.clear
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .task(id: url) { await load() }
    }

    private func landscape(_ img: UIImage, in size: CGSize) -> some View {
        let aspect = img.size.width / max(img.size.height, 1)
        // scaledToFit makes a wide image touch the left/right edges; this is the
        // zoom factor that fills it vertically so there's room to pan across.
        let fillZoom = max(1, size.height * aspect / max(size.width, 1))
        let panMax = size.width * (fillZoom - 1) / 2

        let scale: CGFloat
        let offsetX: CGFloat
        if progress <= panEnd {
            let p = panEnd > 0 ? progress / panEnd : 1     // 0…1 across pan phase
            scale = fillZoom
            offsetX = panMax - (2 * panMax) * p            // +panMax → −panMax
        } else {
            let p = (progress - panEnd) / max(0.0001, 1 - panEnd)
            let e = 1 - pow(1 - p, 2)                       // ease-out
            scale = fillZoom + (1 - fillZoom) * e           // fillZoom → 1.0
            offsetX = -panMax + panMax * e                 // −panMax → 0
        }

        return Image(uiImage: img)
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .scaleEffect(scale)
            .offset(x: offsetX)
    }

    private func load() async {
        guard let url else { await MainActor.run { image = nil }; return }
        if let cached = FilmImageCache.shared.object(forKey: url as NSURL) {
            await MainActor.run { image = cached }
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) {
                FilmImageCache.shared.setObject(img, forKey: url as NSURL)
                await MainActor.run { image = img }
            }
        } catch {
            // leave placeholder
        }
    }
}
