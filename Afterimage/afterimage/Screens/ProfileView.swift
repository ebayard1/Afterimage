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
    @State private var albumService = AlbumService()
    @State private var showGallery = false
    @State private var showFriends = false
    @State private var showNotifications = false
    @State private var showSettings = false
    @State private var showYearRecap = false
    @State private var membersSheetAlbum: Album?
    @State private var sunriseAlbum: Album?
    @State private var presentedAlbum: Album?
    @State private var now = Date()
    @State private var showFaceTagReview = false
    @State private var showMap = false
    @State private var searchQuery = ""
    @FocusState private var searchFocused: Bool

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    /// Sample-only mode — never reads from Firestore.
    private var allAlbums: [Album] { SampleData.albums }
    private var developing: [Album] {
        allAlbums.filter { !$0.isRevealed }
            .sorted { $0.revealAt < $1.revealAt }
    }
    private var revealed: [Album] {
        allAlbums.filter { $0.isRevealed }
            .sorted { $0.createdAt > $1.createdAt }
    }
    private var totalShotCount: Int {
        SampleData.albums.reduce(0) { $0 + SampleData.shots(forAlbumId: $1.id ?? "").count }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 26, pinnedViews: []) {
                        identityHeader
                        ledgerStrip
                        yearInRollsCard

                        if !developing.isEmpty {
                            ledgerDivider(title: "DEVELOPING", count: developing.count, color: Palette.red)
                            VStack(spacing: 0) {
                                ForEach(Array(developing.enumerated()), id: \.element.id) { idx, album in
                                    ScrollFadeIn(delay: Double(idx) * 0.04, distance: 10) {
                                        developingRow(album, rollNumber: developing.count - idx)
                                    }
                                    if idx < developing.count - 1 {
                                        ledgerLine
                                    }
                                }
                            }
                            .background(Palette.surface.opacity(0.5))
                            .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
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
                        searchField
                        let visible = visibleRevealed
                        if visible.isEmpty {
                            emptySearchState
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(visible.enumerated()), id: \.element.id) { idx, album in
                                    ScrollFadeIn(delay: Double(idx) * 0.04 + 0.05, distance: 10) {
                                        archiveRow(album, rollNumber: revealed.count - (revealed.firstIndex(where: { $0.id == album.id }) ?? idx))
                                    }
                                    if idx < visible.count - 1 {
                                        ledgerLine
                                    }
                                }
                            }
                            .background(Palette.surface.opacity(0.5))
                            .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
                        }

                        if !savedShots.isEmpty {
                            ledgerDivider(title: "SAVED", count: savedShots.count, color: Palette.gold)
                            savedRail
                        }

                        if !SampleData.youAppearInShots.isEmpty {
                            HStack {
                                ledgerDivider(title: "YOU APPEAR IN",
                                              count: SampleData.youAppearInShots.count,
                                              color: Palette.textSecondary)
                                Button { showFaceTagReview = true } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "tag.fill")
                                            .font(.system(size: 9))
                                        Text("REVIEW TAGS")
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
                                .accessibilityLabel("Review face tags")
                            }
                            youAppearInRail
                        }

                        designGalleryCard
                        archiveFooter
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
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
                            if SampleData.notifications.count > 0 {
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
        }
        .onReceive(ticker) { now = $0 }
        // Sample-only mode — no Firestore listener.
        .sheet(isPresented: $showGallery) { DesignGalleryView() }
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
        .fullScreenCover(isPresented: $showYearRecap) {
            YearInRollsView()
        }
        .sheet(isPresented: $showFaceTagReview) {
            FaceTagConfirmSheet()
        }
        .fullScreenCover(isPresented: $showMap) {
            RollMapView()
        }
        .navigationDestination(isPresented: Binding(
            get: { presentedAlbum != nil },
            set: { if !$0 { presentedAlbum = nil } }
        )) {
            if let album = presentedAlbum {
                AlbumDetailView(album: album)
                    .environment(auth)
            }
        }
    }

    // MARK: - Identity header
    //
    // Large square avatar in a film-negative-style frame — corner ticks, gold
    // border, no circle. Different visual register from the Rolls feed header.

    private var identityHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            avatarFrame
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
                        Text("\(SampleData.friends.count) friends")
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
                .accessibilityLabel("\(SampleData.friends.count) friends — open list")
                .padding(.top, 2)

                if let email = auth.email, !email.isEmpty {
                    Text(email)
                        .font(.custom("Menlo", size: 10)).tracking(0.5)
                        .foregroundStyle(Palette.textTertiary)
                        .padding(.top, 2)
                } else {
                    HStack(spacing: 5) {
                        Circle().fill(Palette.gold).frame(width: 5, height: 5)
                        Text("demo mode · sample data only")
                            .font(.custom("Menlo", size: 10)).tracking(1)
                            .foregroundStyle(Palette.textTertiary)
                    }
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
            // Backing
            Rectangle()
                .fill(Palette.surface)
                .frame(width: 72, height: 72)
                .overlay(Rectangle().stroke(Palette.gold, lineWidth: 1.5))

            Image(systemName: "person.fill")
                .font(.system(size: 36))
                .foregroundStyle(Palette.gold.opacity(0.85))

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
        }
        .frame(width: 80, height: 80)
        .accessibilityHidden(true)
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
        if let email = auth.email, let prefix = email.split(separator: "@").first {
            return "@\(prefix)".uppercased()
        }
        return "@YOU"
    }

    private var longName: String {
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

    // MARK: - Year in rolls (compact)

    private var yearInRollsCard: some View {
        Button { showYearRecap = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    LinearGradient(
                        colors: [Palette.gold.opacity(0.35), Palette.darkRed.opacity(0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Palette.gold)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("YOUR YEAR IN ROLLS")
                        .font(.custom("Bebas Neue", size: 14)).tracking(3)
                        .foregroundStyle(Palette.gold)
                    Text("every revealed roll · one cinematic recap")
                        .font(.custom("Times New Roman", size: 12)).italic()
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.gold)
                    .padding(8)
                    .background(Palette.gold.opacity(0.15))
                    .clipShape(Circle())
            }
            .padding(12)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.gold.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel("Play your year in rolls recap")
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(searchFocused ? Palette.gold : Palette.textTertiary)
                .font(.system(size: 12))
            TextField("", text: $searchQuery,
                      prompt: Text("search rolls, locations…")
                .foregroundStyle(Palette.textTertiary))
                .focused($searchFocused)
                .foregroundStyle(Palette.textPrimary)
                .font(.system(size: 13))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.textTertiary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Palette.surface)
        .overlay(Capsule().stroke(
            searchFocused ? Palette.gold : Palette.border,
            lineWidth: searchFocused ? 1.5 : 1))
        .clipShape(Capsule())
        .animation(Motion.tap, value: searchFocused)
    }

    private var visibleRevealed: [Album] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return revealed }
        return revealed.filter { album in
            if album.name.lowercased().contains(q) { return true }
            if let loc = SampleData.location(forAlbumId: album.id ?? ""),
               loc.lowercased().contains(q) { return true }
            if let stock = album.filmStock,
               stock.displayName.lowercased().contains(q) { return true }
            if let track = album.soundtrack,
               (track.title.lowercased().contains(q) || track.artist.lowercased().contains(q)) { return true }
            return false
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(Palette.textTertiary)
            Text("no rolls match \u{201C}\(searchQuery)\u{201D}")
                .font(.system(size: 12)).italic()
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Palette.surface.opacity(0.3))
        .overlay(Rectangle().stroke(Palette.border, style: StrokeStyle(lineWidth: 1, dash: [3])))
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

    private var ledgerLine: some View {
        Rectangle().fill(Palette.border).frame(height: 1)
            .padding(.horizontal, 10)
    }

    // MARK: - Developing row — red-tinted entry with countdown instead of hero

    private func developingRow(_ album: Album, rollNumber: Int) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            presentedAlbum = album
        } label: {
            HStack(alignment: .center, spacing: 12) {
                developingGlyph
                VStack(alignment: .leading, spacing: 5) {
                    rollHeaderLine(rollNumber: rollNumber, dateOrCountdown: countdownString(album), color: Palette.red)
                    Text(album.name.uppercased())
                        .font(.custom("Bebas Neue", size: 18)).tracking(2)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 6) {
                        if let loc = SampleData.location(forAlbumId: album.id ?? "") {
                            Image(systemName: "mappin").font(.system(size: 8))
                                .foregroundStyle(Palette.textTertiary)
                            Text(loc.uppercased())
                                .font(.custom("Bebas Neue", size: 10)).tracking(1.5)
                                .foregroundStyle(Palette.textTertiary)
                            dotSeparator
                        }
                        PulsingDot(color: Palette.red, size: 5)
                        Text("DEVELOPING")
                            .font(.custom("Bebas Neue", size: 10)).tracking(2)
                            .foregroundStyle(Palette.red)
                    }
                    contributorRow(album.memberIds)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
                chevron
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pressEffect(scale: 0.98)
        .accessibilityLabel("\(album.name), developing roll \(rollNumber), \(album.memberIds.count) members")
        .accessibilityHint("Double-tap to open. Long-press for more actions.")
        .contextMenu { rollContextMenu(album: album) }
    }

    /// Red-glow film-canister glyph used in place of the hero photo for developing rolls.
    private var developingGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(RadialGradient(
                    colors: [
                        Color(red: 0.28, green: 0.06, blue: 0.04),
                        Color(red: 0.09, green: 0.02, blue: 0.02)
                    ],
                    center: .center, startRadius: 4, endRadius: 60
                ))
                .frame(width: 76, height: 76)
            Circle()
                .fill(Palette.darkRed.opacity(0.4))
                .frame(width: 32, height: 32)
                .blur(radius: 9)
            Image(systemName: "camera.aperture")
                .font(.system(size: 22))
                .foregroundStyle(Palette.darkRed)
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.darkRed.opacity(0.4), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private func countdownString(_ album: Album) -> String {
        let interval = max(0, album.revealAt.timeIntervalSince(now))
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        if days > 0 { return "REVEALS IN \(days)D \(hours)H" }
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "REVEALS IN \(hours)H \(minutes)M" }
        return "REVEALS IN \(minutes)M"
    }

    // MARK: - Archive row — hero photo + metadata + contributor row

    private func archiveRow(_ album: Album, rollNumber: Int) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            presentedAlbum = album
        } label: {
            HStack(alignment: .center, spacing: 12) {
                heroPhoto(album)
                VStack(alignment: .leading, spacing: 5) {
                    rollHeaderLine(rollNumber: rollNumber, dateOrCountdown: dateStamp(album), color: Palette.gold)
                    Text(album.name.uppercased())
                        .font(.custom("Bebas Neue", size: 18)).tracking(2)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 6) {
                        if let loc = SampleData.location(forAlbumId: album.id ?? "") {
                            Image(systemName: "mappin").font(.system(size: 8))
                                .foregroundStyle(Palette.textTertiary)
                            Text(loc.uppercased())
                                .font(.custom("Bebas Neue", size: 10)).tracking(1.5)
                                .foregroundStyle(Palette.textTertiary)
                            dotSeparator
                        }
                        Text("\(shotCount(album)) SHOTS")
                            .font(.custom("Menlo", size: 10)).tracking(1)
                            .foregroundStyle(Palette.gold)
                    }
                    contributorRow(album.memberIds)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
                chevron
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pressEffect(scale: 0.98)
        .accessibilityLabel("\(album.name), roll \(rollNumber), \(shotCount(album)) shots, \(album.memberIds.count) members")
        .accessibilityHint("Double-tap to open. Long-press for more actions.")
        .contextMenu { rollContextMenu(album: album) }
    }

    private func heroPhoto(_ album: Album) -> some View {
        AsyncImage(url: URL(string: album.coverPhotoURL ?? "")) { phase in
            switch phase {
            case .success(let img): img.resizable().scaledToFill()
            default: ShimmerPlaceholder()
            }
        }
        .frame(width: 76, height: 76)
        .clipped()
        .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
        .accessibilityHidden(true)
    }

    /// "ROLL 07  ──────────  MAY 14 2026" header line shared between archive and developing rows.
    private func rollHeaderLine(rollNumber: Int, dateOrCountdown: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text("ROLL \(String(format: "%02d", rollNumber))")
                .font(.custom("Menlo", size: 9)).tracking(2)
                .foregroundStyle(color)
            Rectangle().fill(color.opacity(0.3)).frame(height: 1)
            Text(dateOrCountdown)
                .font(.custom("Menlo", size: 9)).tracking(1.5)
                .foregroundStyle(color.opacity(0.85))
        }
    }

    private func dateStamp(_ album: Album) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d yyyy"
        return f.string(from: album.createdAt).uppercased()
    }

    private func shotCount(_ album: Album) -> Int {
        SampleData.shots(forAlbumId: album.id ?? "").count
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.textTertiary)
    }

    private var dotSeparator: some View {
        Circle().fill(Palette.textTertiary.opacity(0.4)).frame(width: 3, height: 3)
    }

    /// Contributors row — clean, no overlap, names visible up to 4 then "+N".
    private func contributorRow(_ memberIds: [String]) -> some View {
        let display = Array(memberIds.prefix(4))
        let extra = memberIds.count - display.count
        return HStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Array(display.enumerated()), id: \.offset) { _, uid in
                    AlbumMemberAvatar(uid: uid, size: 20)
                        .overlay(Circle().stroke(Palette.border, lineWidth: 1))
                }
            }
            // Show first contributor's name as a textual handle, with "+N" for the rest.
            if let firstName = memberLabel(memberIds.first ?? "") {
                Text(firstName)
                    .font(.custom("Times New Roman", size: 11)).italic()
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
            if extra > 0 {
                Text("+ \(extra)")
                    .font(.custom("Menlo", size: 9)).tracking(0.5)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }

    /// Translates a memberId into a short readable label.
    private func memberLabel(_ uid: String) -> String? {
        if uid == "me" { return "you" }
        if let friend = SampleData.friend(forMemberId: uid) {
            return friend.username
        }
        return nil
    }

    // MARK: - Saved shots rail
    //
    // Reads bookmarked shot ids out of SavedShotsStore and walks every sample
    // album to find matching shots. Small per-tile cards on a horizontal scroll.

    private var savedShots: [(album: Album, shot: Shot)] {
        let saved = SavedShotsStore.shared.savedShotIds
        guard !saved.isEmpty else { return [] }
        var out: [(Album, Shot)] = []
        for album in SampleData.albums {
            let shots = SampleData.shots(forAlbumId: album.id ?? "")
            for s in shots where (s.id.map { saved.contains($0) } ?? false) {
                out.append((album, s))
            }
        }
        return out
    }

    private var savedRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(savedShots.enumerated()), id: \.offset) { idx, pair in
                    ScrollFadeIn(delay: Double(idx) * 0.04, distance: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: URL(string: pair.shot.photoURL)) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFill()
                                    default: ShimmerPlaceholder()
                                    }
                                }
                                .frame(width: 92, height: 92)
                                .clipped()
                                .filmStockGrade(pair.album.filmStock)
                                .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Palette.gold)
                                    .padding(4)
                                    .background(.black.opacity(0.65))
                                    .clipShape(Circle())
                                    .padding(4)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(pair.album.name.uppercased())
                                    .font(.custom("Bebas Neue", size: 10)).tracking(1.5)
                                    .foregroundStyle(Palette.textPrimary)
                                    .lineLimit(1)
                                if let by = memberLabel(pair.shot.userId) {
                                    Text("by \(by)")
                                        .font(.custom("Times New Roman", size: 9)).italic()
                                        .foregroundStyle(Palette.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 92, alignment: .leading)
                        }
                        .pressEffect()
                        .accessibilityLabel("Saved shot from \(pair.album.name)")
                    }
                }
            }
        }
    }

    // MARK: - You appear in — horizontal scroll with names visible (no gradient overlay)

    private var youAppearInRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(SampleData.youAppearInShots.enumerated()), id: \.offset) { idx, entry in
                    ScrollFadeIn(delay: Double(idx) * 0.04, distance: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            AsyncImage(url: URL(string: entry.shot.photoURL)) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                default: ShimmerPlaceholder()
                                }
                            }
                            .frame(width: 92, height: 92)
                            .clipped()
                            .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
                            .pressEffect()
                            .accessibilityLabel("Photo from \(entry.albumName)")
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.albumName.uppercased())
                                    .font(.custom("Bebas Neue", size: 10)).tracking(1.5)
                                    .foregroundStyle(Palette.textPrimary)
                                    .lineLimit(1)
                                if let by = memberLabel(entry.shot.userId) {
                                    Text("by \(by)")
                                        .font(.custom("Times New Roman", size: 9)).italic()
                                        .foregroundStyle(Palette.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 92, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Footer: design gallery + archive metadata

    private var designGalleryCard: some View {
        Button { showGallery = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Palette.gold.opacity(0.12)
                    Image(systemName: "rectangle.grid.2x2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.gold)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("DESIGN GALLERY")
                        .font(.custom("Bebas Neue", size: 13)).tracking(3)
                        .foregroundStyle(Palette.textPrimary)
                    Text("38 wireframe screens · sample data")
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(10)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel("Design gallery, 38 wireframe screens")
    }

    /// Tiny ledger footer — archive stats stamped in monospace.
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
