import SwiftUI
import Combine

struct HomeView: View {
    @Environment(AuthService.self) private var auth
    @State private var albumService = AlbumService()
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var showNotifications = false
    @State private var membersSheetAlbum: Album?
    @State private var sunriseAlbum: Album?
    @State private var expandedAlbumIds: Set<String> = []
    @State private var now = Date()
    @State private var onThisDayAlbum: Album?
    @State private var isWindingFilm = false
    @AppStorage("hasSeenFeedCoach") private var hasSeenFeedCoach = false
    @State private var showFeedCoach = false

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    /// Sample-only mode — never reads from Firestore. The shoebox is curated.
    private var allAlbums: [Album] { SampleData.albums }
    private var developing: [Album] { allAlbums.filter { !$0.isRevealed } }
    private var revealed:   [Album] { allAlbums.filter {  $0.isRevealed } }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()

                // Ambient sunrise wash that breathes — same metaphor as the
                // detail surfaces, so the whole app shares a single living
                // backdrop instead of going neutral in the feed.
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { context in
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
                            ActivityRail(events: SampleData.activityEvents)
                                .padding(.bottom, 8)

                            VStack(alignment: .leading, spacing: 28) {
                                if let memory = SampleData.onThisDay {
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
                                    }
                                }
                                if !revealed.isEmpty {
                                    sectionHeader("DEVELOPED", count: revealed.count, color: Palette.gold)
                                        .padding(.top, 6)
                                    ForEach(Array(revealed.enumerated()), id: \.element.id) { idx, album in
                                        ScrollFadeIn(delay: Double(idx) * 0.08 + 0.1) {
                                        VStack(spacing: 14) {
                                            NavigationLink(value: album) {
                                                AlbumRow(
                                                    album: album, now: now, index: idx,
                                                    onTapMembers: { membersSheetAlbum = album },
                                                    onPreviewSunrise: { sunriseAlbum = album }
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("\(album.name), developed roll, \(album.memberIds.count) members")
                                            .accessibilityHint("Double-tap to open the roll. Long-press for more actions.")
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
            // Sample-only mode — no Firestore listener.
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
    }

    private var unreadCount: Int { SampleData.notifications.count }

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
        HStack(spacing: 14) {
            Text("AFTERIMAGE")
                .font(.custom("Bebas Neue", size: 22)).tracking(6)
                .foregroundStyle(Palette.gold)
                .warmthFlicker(period: 5.2, floor: 0.85)
            Spacer()
            Button { showNotifications = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Palette.textPrimary)
                    if unreadCount > 0 {
                        Circle().fill(Palette.red).frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Palette.background, lineWidth: 1.5))
                            .offset(x: 4, y: -2)
                    }
                }
            }
            Button { showJoin = true } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 18))
                    .foregroundStyle(Palette.textPrimary)
            }
            Button { showCreate = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.gold)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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

    var body: some View {
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
}

// MARK: - DEVELOPING: film strip with red safe-light glow + live ticker

struct DevelopingFilmStripCard: View {
    let album: Album
    let now: Date
    let onTapMembers: () -> Void
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
    /// Pseudo-live shot count that moves a little over time.
    private var fakeShotCount: Int {
        let id = album.id ?? album.name
        return abs(id.hashValue) % 22 + 2
    }
    /// Presence ticker — rotates every 30s with the parent ticker.
    private var ticker: String {
        let names = ["noah", "sam", "maya", "leo", "riley", "kim", "jake"]
        let id = album.id ?? album.name
        let n = abs(id.hashValue &+ Int(now.timeIntervalSince1970 / 30))
        let name = names[n % names.count]
        return "\(name) just used shot \(fakeShotCount)"
    }
    /// Stable first frame number derived from the album id so the labels
    /// don't shift across renders.
    private var startFrameTop: Int {
        2 + abs((album.id ?? album.name).hashValue) % 16
    }
    private var startFrameBottom: Int { startFrameTop + 6 }

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
    }

    // MARK: Header — title + shot count + stock/soundtrack pills

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
                Text("\(fakeShotCount) / 24 SHOTS")
                    .font(.custom("Menlo", size: 13)).tracking(2)
                    .foregroundStyle(Palette.gold)
            }
            HStack(spacing: 8) {
                if let stock = album.filmStock {
                    StockPill(stock: stock)
                }
                if let track = album.soundtrack {
                    SoundtrackPill(soundtrack: track)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 14)
    }

    // MARK: Strip section — sprocket → frame numbers → photos → frame numbers → sprocket

    private var stripSection: some View {
        VStack(spacing: 0) {
            LivingSprocketStrip(height: 8, holeHeight: 4)
            FrameNumberTrack(
                prefix: album.filmStock?.shortCode ?? "AFTERIMAGE",
                startFrame: startFrameTop
            )
            filmFrames
            FrameNumberTrack(
                prefix: "→ \(album.name.uppercased())",
                startFrame: startFrameBottom
            )
            LivingSprocketStrip(height: 8, holeHeight: 4)
        }
        .background(Color.black)
    }

    private var filmFrames: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { _ in
                ZStack {
                    RadialGradient(
                        colors: [
                            Color(red: 0.32, green: 0.07, blue: 0.05),
                            Color(red: 0.10, green: 0.02, blue: 0.02)
                        ],
                        center: .center, startRadius: 4, endRadius: 90
                    )
                    Circle()
                        .fill(Palette.darkRed.opacity(0.45))
                        .frame(width: 50, height: 50)
                        .blur(radius: 14)
                }
            }
        }
        // Frame height tuned to match the target's frame aspect on iPhone.
        // ~70pt wide × 160pt tall ≈ 0.44 portrait — closer to the target's
        // moderate portrait rather than the extreme 1:3 we had at 200pt.
        .frame(height: 160)
        .background(Color.black)
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
//   • The film frames show the actual revealed photos (with the album's film
//     stock grade applied), instead of the red darkroom glow.
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

    private var allShotURLs: [String] {
        guard let id = album.id else { return [] }
        let shots = album.isSample
            ? SampleData.shots(forAlbumId: id)
            : SampleData.demoShots(forAlbumId: id, count: 9)
        return shots.map { $0.photoURL }
    }
    /// The 5 photos that go in the film-strip frames.
    private var stripShots: [String] { Array(allShotURLs.prefix(5)) }
    private var totalShots: Int { allShotURLs.count }

    private var dateStamp: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d yyyy"
        return f.string(from: album.createdAt).uppercased()
    }

    private var startFrameTop: Int {
        2 + abs((album.id ?? album.name).hashValue) % 16
    }
    private var startFrameBottom: Int { startFrameTop + 6 }

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
            HStack(spacing: 8) {
                if let stock = album.filmStock {
                    StockPill(stock: stock)
                }
                if let track = album.soundtrack {
                    SoundtrackPill(soundtrack: track)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 14)
    }

    // MARK: Strip section — sprocket → frame numbers → photos → frame numbers → sprocket

    private var stripSection: some View {
        VStack(spacing: 0) {
            LivingSprocketStrip(height: 8, holeHeight: 4)
            FrameNumberTrack(
                prefix: album.filmStock?.shortCode ?? "AFTERIMAGE",
                startFrame: startFrameTop
            )
            filmFrames
            FrameNumberTrack(
                prefix: "→ \(album.name.uppercased())",
                startFrame: startFrameBottom
            )
            LivingSprocketStrip(height: 8, holeHeight: 4)
        }
        .background(Color.black)
    }

    /// 5 portrait film frames showing actual photos with the album's film
    /// stock grade applied. Landscape photos rotate sideways via
    /// `FilmFrameImage` so every cell stays full.
    ///
    /// Height matches the developing card so developed + developing posts
    /// have identical strip geometry.
    private var filmFrames: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                frameCell(at: i)
            }
        }
        .frame(height: 160)
        .background(Color.black)
    }

    @ViewBuilder
    private func frameCell(at i: Int) -> some View {
        if i < stripShots.count, let url = URL(string: stripShots[i]) {
            FilmFrameImage(url: url, stockGrade: album.filmStock)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        if let loc = SampleData.location(forAlbumId: album.id ?? "") {
            return "shot in \(loc.uppercased())"
        }
        return "roll \(String(format: "%02d", index + 1)) · \(totalShots) shots"
    }
}

// MARK: - Shared tiny avatar (used by both card variants)

struct AlbumMemberAvatar: View {
    let uid: String
    var size: CGFloat = 20

    var body: some View {
        Group {
            if uid == "me" {
                ZStack {
                    Circle().fill(Palette.gold.opacity(0.25))
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.45))
                        .foregroundStyle(Palette.gold)
                }
            } else if let seed = SampleData.avatarSeed(forMemberId: uid) {
                AsyncImage(url: URL(string: "https://picsum.photos/seed/\(seed)/120/120")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Palette.surface
                    }
                }
                .clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(Palette.surface)
                    Text(uid.prefix(1).uppercased())
                        .font(.system(size: size * 0.45, weight: .bold))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}
