import SwiftUI
import Combine

// MARK: - ProfileView
//
// The personal archive — distinct from the Rolls magazine-feed.
// The Rolls page is a *spread*: full-bleed film-strip cards with polaroid grids.
// The Profile is a *ledger*: a chronological catalog index of every roll you've
// touched, with one hero shot per entry, full contributor lists shown clearly,
// and a typographic rhythm closer to an old film archive than a social feed.
//
// Same actions as the feed: tap a row to open the album, long-press for the
// roll context menu (members / sunrise preview / copy code / leave).

struct ProfileView: View {
    @Environment(AuthService.self) private var auth
    @Environment(UserService.self) private var users
    @State private var albumService = AlbumService()
    @State private var notifService = NotificationService()

    private var friendCount: Int { users.currentProfile?.friendIds.count ?? 0 }

    @State private var showFriends = false
    @State private var showNotifications = false
    @State private var showSettings = false
    @State private var membersSheetAlbum: Album?
    @State private var sunriseAlbum: Album?
    /// Developed roll opened as a full-screen slideshow — exactly like the feed.
    @State private var slideshowAlbum: Album?
    @State private var now = Date()
    @State private var showMap = false
    @State private var showPhotoCapture = false
    /// True while the archive is actively scrolling — drives the film-strip
    /// glare fade (full while scrolling, subtle at rest). See `ScrollSheen`.
    @State private var feedScrolling = false

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var allAlbums: [Album] { albumService.albums }
    private var developing: [Album] {
        allAlbums.filter { !$0.isRevealed }
            .sorted { $0.revealAt < $1.revealAt }
    }
    private var revealed: [Album] {
        allAlbums.filter { $0.isRevealed }
            .sorted { $0.createdAt > $1.createdAt }
    }
    private var totalShotCount: Int {
        allAlbums.reduce(0) { $0 + $1.displayShotCount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    // The card rows (rollCard) span the FULL width so their film
                    // strips run edge-to-edge — the LazyVStack carries no side
                    // inset (a lazy list clips the old negative-padding breakout).
                    // Every NON-card sibling re-applies the 16pt ledger margin so
                    // text and dividers keep their inset.
                    LazyVStack(alignment: .leading, spacing: 26, pinnedViews: []) {
                        identityHeader
                            .padding(.horizontal, 16)
                        ledgerStrip
                            .padding(.horizontal, 16)

                        if !developing.isEmpty {
                            ledgerDivider(title: "DEVELOPING", count: developing.count, color: Palette.red)
                                .padding(.horizontal, 16)
                            ForEach(Array(developing.enumerated()), id: \.element.id) { idx, album in
                                ScrollFadeIn(delay: Double(idx) * 0.04, distance: 10) {
                                    rollCard(album, index: idx)
                                        // Stops the strip drift, grain and
                                        // flicker on cards scrolled off
                                        // screen. Environment only — no
                                        // layout effect.
                                        .ambientVisibilityGate()
                                }
                            }
                        }

                        HStack {
                            ledgerDivider(title: "THE REEL", count: revealed.count, color: Palette.gold)
                            Button { showMap = true } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "map.fill").font(.system(size: 9))
                                    Text("MAP")
                                        .font(.custom("Bebas Neue", size: 10)).tracking(2)
                                }
                                .foregroundStyle(Palette.gold)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Palette.gold.opacity(0.10))
                                .overlay(Capsule().stroke(Palette.gold.opacity(0.5), lineWidth: 1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .pressEffect()
                            .accessibilityLabel("Open map of roll locations")
                        }
                        .padding(.horizontal, 16)
                        ForEach(Array(revealed.enumerated()), id: \.element.id) { idx, album in
                            ScrollFadeIn(delay: Double(idx) * 0.04 + 0.05, distance: 10) {
                                rollCard(album, index: idx)
                                    .ambientVisibilityGate()
                            }
                        }

                        if !savedShots.isEmpty {
                            ledgerDivider(title: "SAVED", count: savedShots.count, color: Palette.gold)
                                .padding(.horizontal, 16)
                            savedRail
                                .padding(.horizontal, 16)
                        }

                        archiveFooter
                            .padding(.top, 8)
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 32)
                }
                .onScrollPhaseChange { _, newPhase in
                    feedScrolling = (newPhase != .idle)
                }
                .environment(\.isFeedScrolling, feedScrolling)
            }
            .navigationTitle("profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showNotifications = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(Palette.textPrimary)
                            if notifService.unreadCount > 0 {
                                Circle().fill(Palette.red).frame(width: 8, height: 8)
                                    .overlay(Circle().stroke(Palette.background, lineWidth: 1.5))
                                    .offset(x: 5, y: -2)
                            }
                        }
                    }
                    .accessibilityLabel("Notifications")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            // Developing rolls push the album detail — identical to the Rolls feed.
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(album: album)
                    .environment(auth)
            }
        }
        .onReceive(ticker) { now = $0 }
        .task {
            if let uid = auth.uid {
                albumService.startListening(userId: uid)
                notifService.startListening(uid: uid)
            }
        }
        .sheet(isPresented: $showFriends) { FriendsListView() }
        .sheet(isPresented: $showNotifications) { NotificationsView() }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(auth)
        }
        .sheet(item: $membersSheetAlbum) { album in
            AlbumMembersSheet(album: album)
        }
        .fullScreenCover(item: $sunriseAlbum) { album in
            SunriseRevealView(album: album)
        }
        .fullScreenCover(isPresented: $showMap) {
            RollMapView()
        }
        .fullScreenCover(isPresented: $showPhotoCapture) {
            ProfilePhotoCaptureView()
                .environment(auth)
        }
        .fullScreenCover(item: $slideshowAlbum) { album in
            RollSlideshowView(album: album, shots: [])
                .environment(auth)
        }
    }

    // MARK: - Identity header
    //
    // Large square avatar in a film-negative-style frame — corner ticks, gold
    // border, no circle. Different visual register from the Rolls feed header.

    private var identityHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                showPhotoCapture = true
            } label: {
                avatarFrame
            }
            .buttonStyle(.plain)
            .pressEffect(scale: 0.95, lift: 1)
            .accessibilityLabel("Change profile photo")
            .accessibilityHint("Opens the camera to take a new profile photo")
            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(.custom("Bebas Neue", size: 24)).tracking(2)
                    .foregroundStyle(Palette.textPrimary)

                Text(longName)
                    .font(.custom("Times New Roman", size: 13)).italic()
                    .foregroundStyle(Palette.textSecondary)

                Button { showFriends = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 9))
                        Text("\(friendCount) friends")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Palette.gold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Palette.gold.opacity(0.12))
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .pressEffect()
                .accessibilityLabel("\(friendCount) friends — open list")
                .padding(.top, 2)

                if let email = auth.email, !email.isEmpty {
                    Text(email)
                        .font(.custom("Menlo", size: 10)).tracking(0.5)
                        .foregroundStyle(Palette.textTertiary)
                        .padding(.top, 2)
                }
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    /// Square avatar in a "film-negative" frame — gold corner ticks, no circle.
    /// Mirrors the way a single 35mm slide sits in a viewing mount.
    private var avatarFrame: some View {
        ZStack {
            // Backing — the saved profile photo, or the monogram fallback.
            ZStack {
                Rectangle().fill(Palette.surface)
                if let urlStr = users.currentProfile?.photoURL,
                   let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default:
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Palette.gold.opacity(0.85))
                        }
                    }
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Palette.gold.opacity(0.85))
                }
            }
            .frame(width: 72, height: 72)
            .clipped()
            .overlay(Rectangle().stroke(Palette.gold, lineWidth: 1.5))

            // Corner ticks (top-left, top-right, bottom-left, bottom-right)
            ForEach(Array(corners.enumerated()), id: \.offset) { _, c in
                Path { p in
                    p.move(to: .zero); p.addLine(to: CGPoint(x: 8, y: 0))
                    p.move(to: .zero); p.addLine(to: CGPoint(x: 0, y: 8))
                }
                .stroke(Palette.gold, lineWidth: 2)
                .frame(width: 8, height: 8)
                .rotationEffect(.degrees(c.rotation))
                .offset(x: c.dx, y: c.dy)
            }

            // Camera badge — signals the avatar is tappable to change the photo.
            Image(systemName: "camera.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Palette.gold))
                .overlay(Circle().stroke(Palette.background, lineWidth: 1.5))
                .offset(x: 28, y: 28)
        }
        .frame(width: 80, height: 80)
    }

    private var corners: [(dx: CGFloat, dy: CGFloat, rotation: Double)] {
        [
            (-36, -36, 0),     // top-left
            (36, -36, 90),     // top-right
            (-36, 36, 270),    // bottom-left
            (36, 36, 180),     // bottom-right
        ]
    }

    private var displayName: String {
        // Prefer the real saved profile handle; only fall back to the email
        // local-part if the profile hasn't loaded / doesn't exist yet.
        if let handle = users.currentProfile?.username, !handle.isEmpty {
            return "@\(handle)".uppercased()
        }
        if let email = auth.email, let prefix = email.split(separator: "@").first {
            return "@\(prefix)".uppercased()
        }
        return "@YOU"
    }

    private var longName: String {
        if let name = users.currentProfile?.displayName, !name.isEmpty {
            return name
        }
        if let email = auth.email, !email.isEmpty,
           let prefix = email.split(separator: "@").first {
            return String(prefix).capitalized
        }
        return "the keeper of this archive"
    }

    // MARK: - Ledger strip — quiet stats line

    private var ledgerStrip: some View {
        HStack(spacing: 0) {
            ledgerStat(value: "\(allAlbums.count)", label: "ROLLS")
            ledgerSeparator
            ledgerStat(value: "\(totalShotCount)", label: "SHOTS")
            ledgerSeparator
            ledgerStat(value: "\(developing.count)", label: "DEVELOPING", tint: Palette.red)
            ledgerSeparator
            ledgerStat(value: "\(revealed.count)", label: "DEVELOPED", tint: Palette.gold)
        }
        .padding(.vertical, 12)
        .background(
            // Subtle ledger paper-line — single horizontal rule top and bottom
            VStack {
                Rectangle().fill(Palette.border).frame(height: 1)
                Spacer()
                Rectangle().fill(Palette.border).frame(height: 1)
            }
        )
    }

    private func ledgerStat(value: String, label: String, tint: Color = Palette.textPrimary) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.custom("Bebas Neue", size: 22)).tracking(1)
                .foregroundStyle(tint)
            Text(label)
                .font(.custom("Menlo", size: 9)).tracking(2)
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var ledgerSeparator: some View {
        Rectangle().fill(Palette.border).frame(width: 1, height: 28)
    }

    // MARK: - Roll card — identical to the feed's film-strip post

    /// Renders a roll using the exact film-strip card from the feed (`AlbumRow`),
    /// and — critically — opens it EXACTLY the way the Rolls feed does: a
    /// developing roll pushes the album detail via the NavigationStack, a
    /// developed roll opens the full-screen slideshow. (It used to pop a modal
    /// sheet, which read differently from the feed — the thing being fixed here.)
    @ViewBuilder
    private func rollCard(_ album: Album, index: Int) -> some View {
        Group {
            if album.isRevealed {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    slideshowAlbum = album
                } label: {
                    rollCardBody(album, index: index)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: album) {
                    rollCardBody(album, index: index)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityLabel("\(album.name), \(album.isRevealed ? "developed" : "developing") roll, \(album.memberIds.count) members")
        .accessibilityHint(album.isRevealed
            ? "Double-tap to play the slideshow. Long-press for more actions."
            : "Double-tap to open the roll. Long-press for more actions.")
        .contextMenu { rollContextMenu(album: album) }
    }

    private func rollCardBody(_ album: Album, index: Int) -> some View {
        AlbumRow(
            album: album, now: now, index: index,
            onTapMembers: { membersSheetAlbum = album },
            onPreviewSunrise: { sunriseAlbum = album },
            // The profile's LazyVStack no longer insets the card rows, so the
            // strip is already full-bleed — no negative breakout needed (it
            // would overflow the screen in a lazy list).
            sideBreakout: 0
        )
    }

    // MARK: - Ledger dividers + horizontal lines

    private func ledgerDivider(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(color).frame(width: 22, height: 1)
            Text(title)
                .font(.custom("Bebas Neue", size: 13)).tracking(4)
                .foregroundStyle(color)
            Text("· \(count)")
                .font(.custom("Menlo", size: 10)).tracking(1)
                .foregroundStyle(color.opacity(0.6))
            Rectangle().fill(color.opacity(0.3)).frame(height: 1)
        }
        .padding(.top, 4)
    }

    // MARK: - Saved shots rail
    //
    // Bookmarked shots, persisted locally on the device (`SavedShotsStore`).

    private var savedShots: [SavedShot] { SavedShotsStore.shared.saved }

    private var savedRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(savedShots.enumerated()), id: \.offset) { idx, shot in
                    ScrollFadeIn(delay: Double(idx) * 0.04, distance: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: URL(string: shot.photoURL)) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFill()
                                    default: ShimmerPlaceholder()
                                    }
                                }
                                .frame(width: 92, height: 92)
                                .clipped()
                                .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Palette.gold)
                                    .padding(4)
                                    .background(.black.opacity(0.65))
                                    .clipShape(Circle())
                                    .padding(4)
                            }
                            Text(shot.albumName.uppercased())
                                .font(.custom("Bebas Neue", size: 10)).tracking(1.5)
                                .foregroundStyle(Palette.textPrimary)
                                .lineLimit(1)
                                .frame(width: 92, alignment: .leading)
                        }
                        .pressEffect()
                        .accessibilityLabel("Saved shot from \(shot.albumName)")
                    }
                }
            }
        }
    }

    // MARK: - Footer: archive metadata
    private var archiveFooter: some View {
        HStack {
            Rectangle().fill(Palette.border).frame(height: 1)
            Text("ARCHIVE · \(displayName)")
                .font(.custom("Menlo", size: 9)).tracking(2)
                .foregroundStyle(Palette.textTertiary)
            Rectangle().fill(Palette.border).frame(height: 1)
        }
        .padding(.top, 4)
    }

    // MARK: - Roll context menu (mirrors HomeView)

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
            // Sample-only — no destructive write
        } label: {
            Label("Leave roll", systemImage: "rectangle.portrait.and.arrow.right")
        }
    }
}
