import SwiftUI
import Combine

struct HomeView: View {
    @Environment(AuthService.self) private var auth
    @State private var albumService = AlbumService()
    @State private var activityService = ActivityService()
    @State private var notifService = NotificationService()
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var showNotifications = false
    @State private var membersSheetAlbum: Album?
    @State private var sunriseAlbum: Album?
    @State private var expandedAlbumIds: Set<String> = []
    @State private var now = Date()
    @State private var onThisDayAlbum: Album?
    @State private var slideshowAlbum: Album?
    @State private var isWindingFilm = false
    @AppStorage("hasSeenFeedCoach") private var hasSeenFeedCoach = false
    @State private var showFeedCoach = false
    /// True while the feed is actively scrolling — drives the film-strip glare
    /// fade (full while scrolling, subtle at rest). See `ScrollSheen`.
    @State private var feedScrolling = false
    /// Published by `MainTabView`: true unless Rolls is the selected page and
    /// the app is foregrounded. See `AmbientMotion.swift`.
    @Environment(\.ambientMotionPaused) private var ambientPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Activity rail source — the live fanned-out feed.
    private var railEvents: [ActivityEvent] {
        activityService.items.map { item in
            ActivityEvent(
                kind: item.eventKind,
                actorUsername: item.actorUsername,
                actorPhotoSeed: "",
                actorPhotoURL: item.actorPhotoURL,
                albumName: item.albumName,
                detail: item.detail,
                happenedAt: item.happenedAt
            )
        }
    }

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var allAlbums: [Album] { albumService.albums }
    private var developing: [Album] { allAlbums.filter { !$0.isRevealed } }
    private var revealed:   [Album] { allAlbums.filter {  $0.isRevealed } }

    /// "On this day" — a revealed roll from a prior year on today's calendar day.
    private var onThisDay: OnThisDayMemory? {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: now)
        let thisYear = cal.component(.year, from: now)
        let match = revealed.first { a in
            let c = cal.dateComponents([.month, .day, .year], from: a.createdAt)
            return c.month == today.month && c.day == today.day && (c.year ?? thisYear) < thisYear
        }
        guard let album = match else { return nil }
        let years = thisYear - cal.component(.year, from: album.createdAt)
        return OnThisDayMemory(yearsAgo: max(1, years), album: album,
                               teaserPhotoURL: album.coverPhotoURL)
    }

    /// The slideshow loads its own shots live, so nothing is passed in.
    private func displayShots(for album: Album) -> [Shot] { [] }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()

                // Ambient sunrise wash that breathes — same metaphor as the
                // detail surfaces, so the whole app shares a single living
                // backdrop instead of going neutral in the feed.
                //
                // Stays at 10 Hz: there is exactly one of these for the whole
                // page, and it is a full-screen gradient where banding on a
                // slower step would be visible. It just needs to stop when the
                // page doesn't.
                TimelineView(.animation(minimumInterval: 1.0 / 10.0,
                                        paused: ambientPaused || reduceMotion)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let pulse = (sin(t * (2 * .pi / 8.4)) + 1) / 2
                    RadialGradient(
                        colors: [
                            Palette.gold.opacity(0.07 + 0.04 * pulse),
                            .clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.12),
                        startRadius: 6,
                        endRadius: 360
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                VStack(spacing: 0) {
                    header
                    Divider().background(Palette.border)
                    if isWindingFilm {
                        windingFilmStrip
                    }
                    if allAlbums.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            // Live friend activity rail — non-scrolling-list content
                            // glued to the top so it sits inside the scroll view.
                            ActivityRail(events: railEvents)
                                .padding(.bottom, 8)

                            // MUST stay an eager VStack. The roll cards are
                            // built from flexible, screen-measured layers
                            // (GeometryReader glow preferences, maxHeight
                            // spacers in the strip overlays, full-bleed
                            // breakouts) that need a concrete proposed height;
                            // a lazy container proposes nil and the layout
                            // collapses into stretched frames and black gaps.
                            // Tried in Jul 2026 — broke the page. Laziness here
                            // requires giving every card a fixed height first.
                            VStack(alignment: .leading, spacing: 28) {
                                if let memory = onThisDay {
                                    OnThisDayCard(memory: memory) {
                                        // Open the memory's album just like tapping it in the feed.
                                        // Pushes via NavigationStack value binding.
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                        onThisDayAlbum = memory.album
                                    }
                                }
                                if !developing.isEmpty {
                                    sectionHeader("ROLLS DEVELOPING", count: developing.count, color: Palette.red)
                                    ForEach(Array(developing.enumerated()), id: \.element.id) { idx, album in
                                        ScrollFadeIn(delay: Double(idx) * 0.06) {
                                            VStack(spacing: 14) {
                                                NavigationLink(value: album) {
                                                    AlbumRow(
                                                        album: album, now: now, index: idx,
                                                        onTapMembers: { membersSheetAlbum = album },
                                                        onPreviewSunrise: { sunriseAlbum = album }
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                                .accessibilityLabel("\(album.name), developing roll, \(album.memberIds.count) members")
                                                .accessibilityHint("Double-tap to open the roll. Long-press for more actions.")
                                                .contextMenu {
                                                    rollContextMenu(album: album)
                                                }
                                            }
                                        }
                                        // Eager VStack ⇒ offscreen cards stay
                                        // mounted and would keep every clock
                                        // in them ticking forever. This only
                                        // republishes an environment flag; it
                                        // does not touch layout.
                                        .ambientVisibilityGate()
                                    }
                                }
                                if !revealed.isEmpty {
                                    sectionHeader("DEVELOPED", count: revealed.count, color: Palette.gold)
                                        .padding(.top, 6)
                                    ForEach(Array(revealed.enumerated()), id: \.element.id) { idx, album in
                                        ScrollFadeIn(delay: Double(idx) * 0.08 + 0.1) {
                                        VStack(spacing: 14) {
                                            Button {
                                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                                slideshowAlbum = album
                                            } label: {
                                                AlbumRow(
                                                    album: album, now: now, index: idx,
                                                    onTapMembers: { membersSheetAlbum = album },
                                                    onPreviewSunrise: { sunriseAlbum = album }
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("\(album.name), developed roll, \(album.memberIds.count) members")
                                            .accessibilityHint("Double-tap to play the slideshow. Long-press for more actions.")
                                            .contextMenu {
                                                rollContextMenu(album: album)
                                            }

                                            TopCommentsBlock(
                                                album: album,
                                                isExpanded: Binding(
                                                    get: { expandedAlbumIds.contains(album.id ?? "") },
                                                    set: { newVal in
                                                        let id = album.id ?? ""
                                                        if newVal { expandedAlbumIds.insert(id) }
                                                        else      { expandedAlbumIds.remove(id) }
                                                    }
                                                )
                                            )
                                        }
                                        }
                                        // See the developing loop above —
                                        // environment-only, layout-neutral.
                                        .ambientVisibilityGate()
                                    }
                                }
                            }
                            .padding(16)
                        }
                        .refreshable {
                            isWindingFilm = true
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            try? await Task.sleep(nanoseconds: 900_000_000)
                            isWindingFilm = false
                        }
                        .onScrollPhaseChange { _, newPhase in
                            feedScrolling = (newPhase != .idle)
                        }
                        .environment(\.isFeedScrolling, feedScrolling)
                    }
                }
            }
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(album: album)
                    .environment(auth)
            }
        }
        .task {
            await NotificationScheduler.requestPermission()
            if let uid = auth.uid {
                albumService.startListening(userId: uid)
                activityService.startListening(uid: uid)
                notifService.startListening(uid: uid)
            }
            if !hasSeenFeedCoach {
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation { showFeedCoach = true }
            }
        }
        .overlay {
            if showFeedCoach {
                CoachMarkOverlay(surface: .feed) {
                    hasSeenFeedCoach = true
                    withAnimation { showFeedCoach = false }
                }
            }
        }
        .onReceive(ticker) { now = $0 }
        .sheet(isPresented: $showCreate) {
            CreateAlbumView()
                .environment(auth)
        }
        .sheet(isPresented: $showJoin) {
            JoinAlbumView()
                .environment(auth)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .sheet(item: $membersSheetAlbum) { album in
            AlbumMembersSheet(album: album)
        }
        .fullScreenCover(item: $sunriseAlbum) { album in
            SunriseRevealView(album: album)
        }
        .sheet(item: $onThisDayAlbum) { album in
            NavigationStack {
                AlbumDetailView(album: album)
                    .environment(auth)
            }
        }
        .fullScreenCover(item: $slideshowAlbum) { album in
            RollSlideshowView(album: album, shots: displayShots(for: album))
        }
    }

    private var unreadCount: Int { notifService.unreadCount }

    private var windingFilmStrip: some View {
        HStack(spacing: 10) {
            PulsingDot(color: Palette.gold, size: 5)
            Text("WINDING FILM…")
                .font(.custom("Bebas Neue", size: 11)).tracking(3)
                .foregroundStyle(Palette.gold)
            Spacer()
            Text("checking for new shots")
                .font(.custom("Times New Roman", size: 11)).italic()
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Palette.surface)
        .overlay(Rectangle().fill(Palette.gold.opacity(0.3)).frame(height: 1), alignment: .bottom)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("AFTERIMAGE")
                .font(.custom("Bebas Neue", size: 22)).tracking(6)
                .foregroundStyle(Palette.gold)
                .warmthFlicker(period: 5.2, floor: 0.85)
            Spacer()
            Button { showNotifications = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Palette.textPrimary)
                    if unreadCount > 0 {
                        Circle().fill(Palette.red).frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Palette.background, lineWidth: 1.5))
                            .offset(x: 5, y: -3)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            Button { showJoin = true } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            Button { showCreate = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 27))
                    .foregroundStyle(Palette.gold)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "camera.aperture")
                .font(.system(size: 52))
                .foregroundStyle(Palette.textTertiary)
            Text("no active rolls")
                .font(.custom("Bebas Neue", size: 22)).tracking(3)
                .foregroundStyle(Palette.textPrimary)
            Text("start a roll with friends, or join one\nwith a code or QR they sent you.")
                .multilineTextAlignment(.center).italic()
                .font(.custom("Times New Roman", size: 13))
                .foregroundStyle(Palette.textTertiary)
            VStack(spacing: 10) {
                Button { showCreate = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("CREATE ROLL").tracking(3)
                    }
                    .font(.custom("Bebas Neue", size: 16))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Palette.gold)
                }
                Button { showJoin = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                        Text("JOIN A ROLL").tracking(3)
                    }
                    .font(.custom("Bebas Neue", size: 15))
                    .foregroundStyle(Palette.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(Rectangle().stroke(Palette.red, lineWidth: 1))
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            Spacer()
        }
    }

    @ViewBuilder
    private func rollContextMenu(album: Album) -> some View {
        Button {
            membersSheetAlbum = album
        } label: {
            Label("See members", systemImage: "person.2.fill")
        }
        if !album.isRevealed {
            Button {
                sunriseAlbum = album
            } label: {
                Label("Preview sunrise", systemImage: "sunrise.fill")
            }
        }
        Button {
            UIPasteboard.general.string = album.id ?? album.name
        } label: {
            Label("Copy roll code", systemImage: "doc.on.doc")
        }
        Divider()
        Button(role: .destructive) {
            // sample-only mode; demo only
        } label: {
            Label("Leave roll", systemImage: "rectangle.portrait.and.arrow.right")
        }
    }

    private func sectionHeader(_ text: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.custom("Bebas Neue", size: 12)).tracking(4)
                .foregroundStyle(color)
                .warmthFlicker(period: 4.4, floor: 0.82)
            Text("·  \(count)")
                .font(.custom("Menlo", size: 10)).tracking(1)
                .foregroundStyle(color.opacity(0.6))
            Rectangle().fill(color.opacity(0.3)).frame(height: 1)
        }
    }
}

// MARK: - Album row (dispatcher)
//
// Developing rolls render as a 35mm film strip with red darkroom glow and a
// presence ticker. Revealed albums render as a Kodak contact-sheet card with
// a faint tilt — they look like physical objects scattered on a dark table.

struct AlbumRow: View {
    let album: Album
    let now: Date
    let index: Int
    let onTapMembers: () -> Void
    let onPreviewSunrise: () -> Void
    /// Negative horizontal padding used to break the card out of a surrounding
    /// inset so the film strip runs edge-to-edge. The feed's plain `VStack`
    /// honors this overflow (default `-16`). A `LazyVStack` (profile) clips the
    /// overflow, so the profile gives the card full width another way and passes
    /// `0` here. See `ProfileView.rollCard`.
    var sideBreakout: CGFloat = -16

    var body: some View {
        Group {
            if album.isRevealed {
                RevealedRollCard(album: album, index: index, onTapMembers: onTapMembers)
            } else {
                DevelopingFilmStripCard(
                    album: album, now: now,
                    onTapMembers: onTapMembers,
                    onPreviewSunrise: onPreviewSunrise
                )
            }
        }
        // Break the post card out of the surrounding side inset so the film
        // strip runs edge-to-edge with the screen. Header/footer keep their own
        // internal padding, so text never touches the edge.
        .padding(.horizontal, sideBreakout)
    }
}

// MARK: - DEVELOPING: film strip with red safe-light glow + live ticker
//
// The sealed frames shade with the card's position on screen — a slow
// "safe-light sweeping the negatives" that responds to scroll. That used to be
// a `GeometryReader` → `DevelopingGlowKey` preference → `@State scrollGlow`
// loop, i.e. a state write on EVERY scroll frame, which invalidated the whole
// card body and re-ran a per-image animated blur radius underneath it
// (PERF_DIAGNOSIS §3a — the single biggest cause of the feed's scroll
// choppiness). It is now read inside `.visualEffect`, which is evaluated
// during rendering and invalidates nothing. See `SealedReveal`.

struct DevelopingFilmStripCard: View {
    let album: Album
    let now: Date
    let onTapMembers: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Window height, published once by `MainTabView`. Used to normalize a
    /// frame's `midY` into the 0…1 reveal — never measured per card, which is
    /// the mistake documented in `FilmStripSection.body`.
    @Environment(\.viewportHeight) private var viewportHeight
    /// Photo URLs loaded directly from the roll's shots when the album's
    /// denormalized `previewURLs` list is empty (see AlbumService.fetchShotURLs).
    @State private var fallbackURLs: [String] = []

    /// The album's sealed shots. Shown under heavy blur + darkroom red so you
    /// can *barely* make a shape out — the roll isn't developed yet, so this
    /// never reveals an actual photo, just a distorted impression of one.
    private var sealedShotURLs: [String] {
        album.stripPreviewURLs.isEmpty ? fallbackURLs : album.stripPreviewURLs
    }
    let onPreviewSunrise: () -> Void

    private var interval: TimeInterval { max(0, album.revealAt.timeIntervalSince(now)) }
    private var revealCopy: String {
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if days > 0  { return "\(days)d \(hours)h until sunrise" }
        if hours > 0 { return "\(hours)h \(minutes)m until sunrise" }
        return "\(minutes)m until sunrise"
    }
    /// Real number of shots sealed into this roll so far.
    private var shotCount: Int { max(album.displayShotCount, fallbackURLs.count) }
    /// Honest developing status line. No fabricated presence — just where the
    /// roll is being shot (if known) or how many frames are sealed so far.
    private var ticker: String {
        if let loc = album.mapLocationName {
            return "shooting in \(loc.uppercased())"
        }
        if shotCount == 0 { return "no shots yet — be the first" }
        if shotCount == 1 { return "1 shot sealed in the dark" }
        return "\(shotCount) shots sealed in the dark"
    }
    /// Stable first frame number derived from the album id so the labels
    /// don't shift across renders.
    private var startFrameTop: Int {
        2 + abs((album.id ?? album.name).hashValue) % 16
    }
    private var startFrameBottom: Int { startFrameTop + 6 }

    /// Stable per-card seed for the scroll sheen, derived from the album id so
    /// each post shimmers differently but consistently within a session.
    private var sheenSeed: Double {
        Double(abs((album.id ?? album.name).hashValue) % 997)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            stripSection
            footer
        }
        .background(Palette.surface)
        .overlay(LivingFilmGrain())
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Palette.border.opacity(0.7), lineWidth: 1)
        )
        // If the album has no denormalized preview list, load the shot URLs
        // directly so the sealed frames still render.
        .task(id: album.id) {
            prefetchSealedFrames()
            guard album.stripPreviewURLs.isEmpty, let id = album.id else { return }
            fallbackURLs = await AlbumService.fetchShotURLs(albumId: id)
            // The URLs only just arrived — warm them too.
            prefetchSealedFrames()
        }
    }

    /// Decode this card's visible frames off the main thread before first paint.
    /// Without it each cell discovers its own cache miss and decodes during the
    /// flick that brought the card on screen (PERF_DIAGNOSIS §3c). One extra
    /// frame beyond the strip's `frameCount + 1` slots covers the cell waiting
    /// to slide in from the right.
    private func prefetchSealedFrames() {
        let urls = sealedShotURLs
            .prefix(FilmStripMetrics.frameCount + 2)
            .compactMap { URL(string: $0) }
        FilmImageCache.prefetch(urls: urls, tier: .sealed)
    }

    // MARK: Header — title + shot count

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(album.name.uppercased())
                    .font(.custom("Bebas Neue", size: 42)).tracking(1)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .warmthFlicker()
                Spacer(minLength: 8)
                Text("\(shotCount) / 24 SHOTS")
                    .font(.custom("Menlo", size: 13)).tracking(2)
                    .foregroundStyle(Palette.gold)
            }
        }
        .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 14)
    }

    // MARK: Strip section — the whole strip (sprockets, edge numbers, sealed
    // frames) pans as one piece of film, exactly like a developed roll. The
    // sealed red negative is supplied per-cell; `FilmStripSection` drives the pan.

    private var stripSection: some View {
        FilmStripSection(
            photoURLs: sealedShotURLs,
            startFrameTop: startFrameTop,
            startFrameBottom: startFrameBottom,
            sheenSeed: sheenSeed
        ) { url in
            sealedFrame(url: url)
        }
    }

    /// A single undeveloped negative, rendered in pure black-and-red: the real
    /// sealed shot stripped to greyscale, tinted red, and heavily blurred so you
    /// can *barely* make out a shape. As the card travels UP the screen (i.e. as
    /// you scroll down the feed) the reveal rises and the frame appears to
    /// "surface from the developer": the blur softens, the image lifts out of the
    /// dark, and the red safe-light loosens its grip — but it never fully resolves,
    /// always staying greyscale-into-red.
    ///
    /// The greyscale + both blur levels are baked at decode time and crossfaded
    /// inside `SealedFilmFrameImage`; the two glow layers below carry the rest
    /// of the reveal. Every scroll-position read here happens in `.visualEffect`,
    /// which runs during rendering and never invalidates a body — see the note
    /// above `DevelopingFilmStripCard`.
    @ViewBuilder
    private func sealedFrame(url: URL?) -> some View {
        // Locals: the `visualEffect` closures are @Sendable and must not
        // capture `self`.
        let vh = viewportHeight
        let rm = reduceMotion
        ZStack {
            Color.black
            if let url {
                SealedFilmFrameImage(url: url)
            }
            // Darkroom safe-light falloff — pure red so nothing but black/red
            // ever shows. Eases back as the frame surfaces so more is visible.
            //
            // Fading the whole (still semi-transparent) layer is algebraically
            // the same operation as scaling both stop opacities, which is what
            // this used to do: multiply blending with a source of alpha α gives
            // backdrop·(1−α) + backdrop·source·α either way. The old pair ran
            // 0.30→0.16 and 0.60→0.38, i.e. factors of 0.53 and 0.63; one
            // shared 0.58 is within a couple of percent of both and buys a
            // static, cacheable gradient layer.
            RadialGradient(
                colors: [
                    Color(red: 0.34, green: 0.0, blue: 0.0).opacity(0.30),
                    Color(red: 0.09, green: 0.0, blue: 0.0).opacity(0.60)
                ],
                center: .center, startRadius: 6, endRadius: 110
            )
            .visualEffect { content, proxy in
                let r = SealedReveal.progress(in: proxy, viewportHeight: vh, reduceMotion: rm)
                return content.opacity(1 - r * 0.42)
            }
            .blendMode(.multiply)
            // Soft red bloom — the developing-glow signature, swelling as it
            // surfaces. Painted at its MAX opacity (0.28) and faded back by the
            // reveal, which reproduces the old 0.16 → 0.28 ramp exactly while
            // leaving the fill and its fixed 16pt blur constant.
            Circle()
                .fill(Color(red: 0.55, green: 0.0, blue: 0.0).opacity(0.28))
                .frame(width: 56, height: 56)
                .blur(radius: 16)
                .visualEffect { content, proxy in
                    let r = SealedReveal.progress(in: proxy, viewportHeight: vh, reduceMotion: rm)
                    return content.opacity(0.571 + r * 0.429)
                }
        }
    }

    // MARK: Footer — DEVELOPING + countdown + ticker + members

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                PulsingDot()
                Text("DEVELOPING")
                    .font(.custom("Bebas Neue", size: 13)).tracking(3)
                    .foregroundStyle(Palette.red)
                Spacer()
                Text(revealCopy)
                    .font(.custom("Times New Roman", size: 13)).italic()
                    .foregroundStyle(Palette.textSecondary)
            }
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(Palette.gold.opacity(0.6)).frame(width: 4, height: 4)
                    Text(ticker)
                        .font(.custom("Times New Roman", size: 12)).italic()
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button(action: onTapMembers) {
                    RollMembersRow(memberIds: album.memberIds, max: 3, size: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("See \(album.memberIds.count) members")
            }
        }
        .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 18)
    }
}

// MARK: - REVEALED ROLL CARD
//
// Mirrors DevelopingFilmStripCard exactly in structure: header → sprocket strip
// → 5 horizontal film frames → sprocket strip → footer. The only differences:
//
//   • The film frames show the actual revealed photos, instead of the red
//     darkroom glow.
//   • The footer reads DEVELOPED + date instead of DEVELOPING + countdown.
//   • The middle "ticker" line shows the location (mirrors the live ticker
//     rhythm of the developing card).
//   • Row 3 has a Roll # stamp on the left and a TAP TO OPEN pill on the right
//     (mirrors developing's members strip + PREVIEW SUNRISE).
//
// The SHOT BY contributor credits plate stays below the film-strip object,
// exactly as before — a discrete plate with hairline rules.

struct RevealedRollCard: View {
    let album: Album
    let index: Int
    let onTapMembers: () -> Void

    /// Photo URLs loaded directly from the roll's shots when the album's
    /// denormalized `previewURLs` list is empty (see AlbumService.fetchShotURLs).
    @State private var fallbackURLs: [String] = []

    private var allShotURLs: [String] {
        album.stripPreviewURLs.isEmpty ? fallbackURLs : album.stripPreviewURLs
    }
    private var totalShots: Int { max(album.displayShotCount, fallbackURLs.count) }

    private var dateStamp: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d yyyy"
        return f.string(from: album.createdAt).uppercased()
    }

    private var startFrameTop: Int {
        2 + abs((album.id ?? album.name).hashValue) % 16
    }
    private var startFrameBottom: Int { startFrameTop + 6 }

    /// Stable per-card seed for the scroll sheen, derived from the album id so
    /// each post shimmers differently but consistently within a session.
    private var sheenSeed: Double {
        Double(abs((album.id ?? album.name).hashValue) % 997)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            stripSection
            footer
        }
        .background(Palette.surface)
        .overlay(LivingFilmGrain())
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Palette.border.opacity(0.7), lineWidth: 1)
        )
        // If the album has no denormalized preview list (older rolls), load the
        // shot URLs directly so the developed frames still render.
        .task(id: album.id) {
            prefetchStripFrames()
            guard album.stripPreviewURLs.isEmpty, let id = album.id else { return }
            fallbackURLs = await AlbumService.fetchShotURLs(albumId: id)
            // The URLs only just arrived — warm them too.
            prefetchStripFrames()
        }
    }

    /// Decode this card's visible frames off the main thread before first paint,
    /// rather than letting each cell hit the network + JPEG decoder during the
    /// flick that brought the card on screen (PERF_DIAGNOSIS §3c). One extra
    /// frame beyond the strip's `frameCount + 1` slots covers the cell waiting
    /// to slide in from the right.
    private func prefetchStripFrames() {
        let urls = allShotURLs
            .prefix(FilmStripMetrics.frameCount + 2)
            .compactMap { URL(string: $0) }
        FilmImageCache.prefetch(urls: urls, tier: .normal)
    }

    // MARK: Header — title + total shots + pills

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(album.name.uppercased())
                    .font(.custom("Bebas Neue", size: 42)).tracking(1)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .warmthFlicker()
                Spacer(minLength: 8)
                Text("\(totalShots) SHOTS")
                    .font(.custom("Menlo", size: 13)).tracking(2)
                    .foregroundStyle(Palette.gold)
            }
        }
        .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 14)
    }

    // MARK: Strip section — the whole strip (sprockets, edge numbers, photos)
    // pans as one piece of film. See `FilmStripSection`.

    private var stripSection: some View {
        FilmStripSection(
            photoURLs: allShotURLs,
            startFrameTop: startFrameTop,
            startFrameBottom: startFrameBottom,
            sheenSeed: sheenSeed
        ) { url in
            if let url {
                FilmFrameImage(url: url)
            } else {
                ZStack {
                    RadialGradient(
                        colors: [Color(white: 0.10), Color(white: 0.04)],
                        center: .center, startRadius: 4, endRadius: 90
                    )
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.10))
                }
            }
        }
    }

    // MARK: Footer — DEVELOPED + date + location ticker + members

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                PulsingDot(color: Palette.gold)
                Text("DEVELOPED")
                    .font(.custom("Bebas Neue", size: 13)).tracking(3)
                    .foregroundStyle(Palette.gold)
                Spacer()
                Text("on \(dateStamp)")
                    .font(.custom("Times New Roman", size: 13)).italic()
                    .foregroundStyle(Palette.textSecondary)
            }
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(Palette.gold.opacity(0.6)).frame(width: 4, height: 4)
                    Text(tickerText)
                        .font(.custom("Times New Roman", size: 12)).italic()
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button(action: onTapMembers) {
                    RollMembersRow(memberIds: album.memberIds, max: 3, size: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("See \(album.memberIds.count) members")
            }
        }
        .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 18)
    }

    private var tickerText: String {
        if let loc = album.mapLocationName {
            return "shot in \(loc.uppercased())"
        }
        return "roll \(String(format: "%02d", index + 1)) · \(totalShots) shots"
    }
}

// MARK: - Shared tiny avatar (used by both card variants)

struct AlbumMemberAvatar: View {
    let uid: String
    var size: CGFloat = 20
    @Environment(UserService.self) private var users

    var body: some View {
        Group {
            if uid == users.currentProfile?.id {
                ZStack {
                    Circle().fill(Palette.gold.opacity(0.25))
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.45))
                        .foregroundStyle(Palette.gold)
                }
            } else {
                realAvatar
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var realAvatar: some View {
        let profile = users.profile(for: uid)
        if let urlStr = profile?.photoURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Palette.surface
                }
            }
            .clipShape(Circle())
        } else {
            monogram(profile?.initials ?? "?")
        }
    }

    private func monogram(_ text: String) -> some View {
        ZStack {
            Circle().fill(Palette.surface)
            Text(text.uppercased())
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(Palette.textTertiary)
        }
    }
}
