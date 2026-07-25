import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @Environment(AuthService.self) private var auth
    @Environment(UserService.self) private var users
    @Environment(ToastCenter.self) private var toast
    /// Only forwarded on to `AlbumSettingsView` (rename / leave / delete) —
    /// this screen's own data comes from `shotService`. Held here so the
    /// settings sheet is handed the app's single shared instance explicitly.
    @Environment(AlbumService.self) private var albumService
    /// The app's shared 30 s clock. This screen used to run a **one-second**
    /// `Timer.publish` of its own, so the entire page — hero, bento grid,
    /// comments — was invalidated every second for as long as it was open
    /// (PERF_DIAGNOSIS §5.1). The only thing that needed that resolution was
    /// the countdown, which now owns its own clock; see `DevelopingCountdown`.
    @Environment(FeedClock.self) private var clock
    /// Published by `MainTabView` — false only while this page's tab is the one
    /// on screen and the app is foregrounded. See `AmbientMotion.swift`.
    @Environment(\.ambientMotionPaused) private var ambientPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var shotService = ShotService()
    @State private var showCamera = false
    @State private var selectedShotIndex: Int?
    @State private var showShare = false
    @State private var showSettings = false
    @State private var showRecap = false
    /// Set by the one-shot timer in `body` at the exact instant the roll's
    /// window closes — see the note there.
    @State private var revealArrived = false

    private var now: Date { clock.now }

    /// The roll's live shots.
    private var displayShots: [Shot] { shotService.shots }
    private var myDisplayShotCount: Int { shotService.myShotCount }

    var body: some View {
        ZStack(alignment: .top) {
            (isRevealed ? Palette.background : Color(red: 0.09, green: 0.02, blue: 0.02))
                .ignoresSafeArea()
            // Subtle radial wash behind the hero so the title sits in a
            // pool of warm light. Editorial Luxury vibe.
            if isRevealed {
                RadialGradient(
                    colors: [Palette.gold.opacity(0.10), .clear],
                    center: UnitPoint(x: 0.5, y: 0.18),
                    startRadius: 6,
                    endRadius: 380
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            if isRevealed {
                revealedScroll
            } else {
                VStack(spacing: 0) {
                    floatingHeader
                    developingView
                }
            }

            // The floating header always sits ABOVE the scroll content for
            // revealed state — it's a glass island, not an edge-to-edge bar.
            if isRevealed {
                VStack {
                    floatingHeader
                    Spacer()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if let uid = auth.uid, let albumId = album.id {
                shotService.startListening(albumId: albumId, currentUserId: uid)
            }
        }
        // The shared clock ticks every 30 s, which is the right cadence for
        // everything else here but would leave a roll sitting at "00:00:00" for
        // up to half a minute after it actually developed. One sleep, scheduled
        // for the exact instant, closes that gap without a repeating timer —
        // and `.task` cancels it the moment the screen goes away.
        //
        // `revealAt` comes off the wire and is NOT trustworthy: a Timestamp
        // written in milliseconds instead of seconds, or a `distantFuture`
        // default left by a partial write, decodes to a date centuries out.
        // This used to sleep `UInt64(delay * 1_000_000_000)` — and
        // `UInt64(_: Double)` *traps* on anything out of range or NaN, which
        // `try?` cannot catch, so one malformed roll crashed this screen on
        // open, every time, with no way back in. `Task.sleep(for:)` takes a
        // `Duration` and the delay is clamped below, so no arithmetic here can
        // trap on any value Firestore can hand us.
        .task(id: album.id) {
            // Already developed: `isRevealed` is true from the shared clock and
            // there is nothing to wait for. Also the NaN exit — every comparison
            // against NaN is false.
            guard album.revealAt.timeIntervalSinceNow > 0 else { return }
            while !Task.isCancelled {
                let delay = album.revealAt.timeIntervalSinceNow
                guard delay.isFinite else { return }   // ±infinite date: never fires
                guard delay > 0 else { break }         // the moment arrived
                // Cap each pass at an hour and re-arm. Real windows are hours to
                // days, so this costs one extra wake per hour the screen is left
                // open, and an absurd date just means the roll keeps waiting
                // instead of taking the app down with it.
                try? await Task.sleep(for: .seconds(min(delay, 3600)))
            }
            guard !Task.isCancelled else { return }
            revealArrived = true
        }
        // Firestore listeners don't self-remove on dealloc — every push/pop
        // without this leaked a live listener and its snapshot traffic.
        .onDisappear { shotService.stopListening() }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(album: album, showsCloseButton: true)
                // Pure black behind the shell, matching the camera tab.
                .background(Color.black.ignoresSafeArea())
                .environment(auth)
                .environment(toast)
                // Camera mode hides the status bar here too, matching the tab.
                .statusBarHidden(true)
        }
        .fullScreenCover(item: Binding(
            get: { selectedShotIndex.map { IndexBox(value: $0) } },
            set: { selectedShotIndex = $0?.value }
        )) { box in
            PhotoViewerView(
                album: album,
                shots: displayShots,
                startIndex: box.value
            )
            .environment(auth)
            .environment(toast)
        }
        .sheet(isPresented: $showShare) {
            if let id = album.id {
                AlbumShareSheet(albumId: id, albumName: album.name)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showSettings) {
            AlbumSettingsView(album: album) {
                dismiss()
            }
            .environment(auth)
            .environment(toast)
            .environment(albumService)
        }
        .fullScreenCover(isPresented: $showRecap) {
            RecapView(album: album, shots: displayShots)
        }
    }

    private var isRevealed: Bool { revealArrived || now >= album.revealAt }

    // MARK: - Floating header (fluid island, detached from top edge)

    private var floatingHeader: some View {
        HStack(spacing: 10) {
            islandButton(icon: "chevron.left",
                         label: "Back to feed") { dismiss() }
            Spacer()
            // Title pill — quiet, monospace caption inside a capsule glass plate
            HStack(spacing: 6) {
                Circle().fill(isRevealed ? Palette.gold : Palette.darkRed)
                    .frame(width: 5, height: 5)
                Text(album.name.uppercased())
                    .font(.custom("Bebas Neue", size: 12)).tracking(2)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(.ultraThinMaterial)
            .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
            .clipShape(Capsule())
            .accessibilityHidden(true)
            Spacer()
            if isRevealed {
                islandButton(icon: "play.fill", tint: Palette.red,
                             label: "Play album recap") { showRecap = true }
            }
            islandButton(icon: "square.and.arrow.up", tint: Palette.gold,
                         label: "Share album",
                         hint: "Opens QR code and album code") { showShare = true }
            islandButton(icon: "ellipsis", tint: Palette.textSecondary,
                         label: "Album settings") { showSettings = true }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(
            // Glass plate — Double-Bezel outer shell + inner highlight
            Capsule().fill(Palette.surface.opacity(0.75))
                .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 1))
                .warmShadow(radius: 18, y: 6, opacity: 0.35)
        )
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    /// 36pt circle button with backdrop blur — the "island" style used in
    /// the floating header. Includes magnetic press physics.
    private func islandButton(icon: String,
                              tint: Color = Palette.textSecondary,
                              label: String,
                              hint: String? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Palette.background.opacity(0.7))
                        .overlay(Circle().stroke(Palette.border.opacity(0.6), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .pressEffect(scale: 0.92, lift: 1)
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
    }

    private var developingView: some View {
        VStack(spacing: 20) {
            Spacer()
            // The darkroom "breathing" aperture. 12 Hz, not the 30 it ran at:
            // the cycle is ~4.5 s long and only drives opacities and a 4%
            // scale, so a tick moves things by well under a thousandth — a
            // multi-second sine does not need 30 wakeups a second. Gated like
            // every other ambient clock (see `AmbientMotion.swift`); it was
            // never brought into the gate when the rest of the app was.
            TimelineView(.animation(minimumInterval: 1.0 / 12.0,
                                    paused: ambientPaused || reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let breathe = (sin(t * 1.4) + 1) / 2  // 0…1, ~4.5s cycle
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Palette.darkRed.opacity(0.25 + 0.12 * breathe), .clear],
                            center: .center, startRadius: 4, endRadius: 80))
                        .frame(width: 160, height: 160)
                    ForEach([60.0, 90.0, 120.0], id: \.self) { r in
                        Circle()
                            .stroke(Palette.darkRed.opacity(0.18 + 0.12 * breathe), lineWidth: 1)
                            .frame(width: r, height: r)
                    }
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 38))
                        .foregroundStyle(Palette.darkRed)
                        .scaleEffect(1.0 + 0.04 * breathe)
                }
                .accessibilityHidden(true)
            }
            .frame(width: 160, height: 160)
            VStack(spacing: 4) {
                Text("DEVELOPING")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(3)
                    .foregroundStyle(Palette.darkRed)
                DevelopingCountdown(revealAt: album.revealAt)
                Text("reveals \(formattedReveal)")
                    .font(.system(size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)
            }
            Text("\(myDisplayShotCount) of your shot\(myDisplayShotCount == 1 ? "" : "s") on the roll")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)

            if myDisplayShotCount == 0 {
                VStack(spacing: 6) {
                    HStack(spacing: 3) {
                        ForEach(0..<12, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Palette.border, lineWidth: 1)
                                .frame(width: 12, height: 16)
                        }
                    }
                    Text("0 / 24 SHOTS · be the first")
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Palette.textTertiary)
                }
                .padding(.top, 6)
            }
            Spacer()
            Button { showCamera = true } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("OPEN CAMERA")
                        .font(.custom("Bebas Neue", size: 16)).tracking(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Palette.gold)
                .foregroundStyle(.black)
                .cornerRadius(8)
                .padding(.horizontal, 24)
                .warmShadow(radius: 10, y: 6, opacity: 0.5)
            }
            .buttonStyle(.plain)
            .pressEffect(scale: 0.96, lift: 1)
            .accessibilityLabel("Open camera for \(album.name)")
            .accessibilityHint("Locks the camera to this roll. No retakes.")
            .padding(.bottom, 30)
        }
    }

    // MARK: - Revealed scroll
    //
    // Asymmetrical Bento composition with macro-whitespace between sections.
    // Floating header sits above; the scroll content starts roughly 76pt down
    // so it never collides with the island.

    private var revealedScroll: some View {
        ScrollView {
            // Leave room for the floating header island + 24pt breath
            Color.clear.frame(height: 76)

            if displayShots.isEmpty {
                emptyShotsState
                    .padding(.horizontal, 24)
                    .padding(.vertical, 96)
            } else {
                VStack(spacing: 0) {
                    heroBlock
                        .padding(.horizontal, 22)
                        .padding(.bottom, 36)
                    statsBento
                        .padding(.horizontal, 18)
                        .padding(.bottom, 36)
                    BentoPhotoGrid(
                        shots: displayShots,
                        onTapShot: { idx in selectedShotIndex = idx }
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 48)
                    commentsPlate
                        .padding(.horizontal, 18)
                        .padding(.bottom, 48)
                }
            }
        }
    }

    /// Eyebrow + massive Bebas title + italic Times sub. Sits in macro-whitespace.
    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Eyebrow tag — pill-shaped, monospace, generously tracked
            HStack(spacing: 6) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text(eyebrowText)
                    .font(.custom("Menlo", size: 10)).tracking(3)
                    .foregroundStyle(Palette.gold)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                Capsule().fill(Palette.gold.opacity(0.10))
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1))
            )

            // Massive Bebas Neue title — locked to 2 lines max
            Text(album.name.uppercased())
                .font(.custom("Bebas Neue", size: 52)).tracking(-1)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            // Italic Times tagline — location / stock / soundtrack distilled
            Text(taglineText)
                .font(.custom("Times New Roman", size: 14)).italic()
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var eyebrowText: String {
        "REVEALED · \(Formatters.albumHeroDate.string(from: album.createdAt).uppercased())"
    }

    private var taglineText: String {
        var parts: [String] = []
        if let loc = album.mapLocationName {
            parts.append("shot in \(loc.lowercased())")
        }
        return parts.isEmpty
            ? "\(displayShots.count) shots, sealed until sunrise."
            : parts.joined(separator: " · ")
    }

    // MARK: - Stats bento
    //
    // Two Double-Bezel cards in a row: shot count · contributors.

    private var statsBento: some View {
        HStack(spacing: 8) {
            statCard(
                eyebrow: "SHOTS",
                value: "\(displayShots.count)",
                sub: "across the roll",
                tint: Palette.gold
            )
            statCard(
                eyebrow: "PEOPLE",
                value: "\(album.memberIds.count)",
                sub: contributorNamesString,
                tint: Palette.textPrimary
            )
        }
    }

    private var contributorNamesString: String {
        let names = album.memberIds.compactMap { uid -> String? in
            if uid == users.currentProfile?.id { return "you" }
            return users.profile(for: uid)?.handle
        }
        let firstTwo = names.prefix(2).joined(separator: ", ")
        let extra = max(0, names.count - 2)
        return extra > 0 ? "\(firstTwo) +\(extra)" : firstTwo
    }

    /// Double-Bezel stat card. Outer shell wraps inner core with concentric
    /// curves and a subtle inset highlight.
    private func statCard(
        eyebrow: String,
        value: String,
        sub: String,
        tint: Color,
        valueFont: Font = .custom("Bebas Neue", size: 26)
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 4, height: 4)
                Text(eyebrow)
                    .font(.custom("Menlo", size: 9)).tracking(2.5)
                    .foregroundStyle(tint.opacity(0.85))
            }
            Text(value)
                .font(valueFont).tracking(1)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(sub)
                .font(.custom("Times New Roman", size: 10)).italic()
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            // Inner core
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                        .blendMode(.plusLighter)
                )
        )
        .padding(3)
        .background(
            // Outer shell
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.background.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Palette.border.opacity(0.6), lineWidth: 1)
                )
        )
    }

    // MARK: - Comments plate — Double-Bezel container

    private var commentsPlate: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text("CONVERSATION")
                    .font(.custom("Menlo", size: 10)).tracking(3)
                    .foregroundStyle(Palette.gold)
                Rectangle().fill(Palette.gold.opacity(0.2)).frame(height: 1)
            }
            .padding(.bottom, 14)

            CommentsSection(album: album, shots: displayShots) { idx in
                selectedShotIndex = idx
            }
            .environment(auth)
            .environment(toast)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.surface.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                )
        )
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Palette.background.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(Palette.border.opacity(0.5), lineWidth: 1)
                )
        )
    }

    // MARK: - Empty state

    private var emptyShotsState: some View {
        VStack(spacing: 14) {
            Image(systemName: "film")
                .font(.system(size: 48))
                .foregroundStyle(Palette.textTertiary)
            Text("the roll developed empty")
                .font(.custom("Bebas Neue", size: 20)).tracking(2)
                .foregroundStyle(Palette.textSecondary)
            Text("the window closed but no one shot anything")
                .font(.custom("Times New Roman", size: 12)).italic()
                .foregroundStyle(Palette.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedReveal: String {
        Formatters.revealMoment.string(from: album.revealAt)
    }
}

// MARK: - Developing countdown
//
// The seconds-resolution counter under the breathing aperture, and the ONLY
// thing on this screen that wants a 1 Hz clock. It used to get one by ticking
// `AlbumDetailView`'s `now`, so a `Text` that changes one digit a second was
// dragging the hero, the bento grid and the comments plate through a body
// re-evaluation with it. Owning the clock down here scopes the per-second
// redraw to this label and nothing else.
private struct DevelopingCountdown: View {
    let revealAt: Date

    /// True when the app is backgrounded or this page's tab isn't the one on
    /// screen — a countdown nobody can see does not need to keep counting, and
    /// it re-reads the wall clock on resume, so it can't drift.
    @Environment(\.ambientMotionPaused) private var ambientPaused

    var body: some View {
        // `.animation(minimumInterval:paused:)` rather than `.periodic(from:by:)`:
        // `PeriodicTimelineSchedule` takes no `paused:`, and every clock in this
        // app has to be gateable (see `AmbientMotion.swift`).
        //
        // Deliberately NOT OR'd with `accessibilityReduceMotion` — this is
        // information, not decoration. Freezing a countdown for Reduce Motion
        // would be a bug, not an accommodation.
        //
        // Two details that a seconds counter, unlike a decorative tick, actually
        // notices:
        //
        //   • `minimumInterval` is 0.5, not 1. `.animation` fires on the first
        //     display frame AFTER the interval elapses, so a 1 s minimum really
        //     ticks every ~1.008 s and the phase walks. Once the accumulated
        //     drift crosses a second boundary two ticks land inside the same
        //     integer second, the label holds for 2 s and then jumps 2 — a
        //     visible stutter on the one number here people watch. Sampling
        //     twice a second means the gap between samples (~0.52 s) is always
        //     shorter than the value's 1 s lifetime, so no integer second can be
        //     skipped or repeated. The extra wakeup is scoped to this one `Text`.
        //
        //   • The string comes from a freshly read `Date()`, not `context.date`.
        //     `context.date` is the schedule's frame time, which is what carries
        //     the drift; the wall clock does not. It also means the first tick
        //     after `ambientPaused` releases shows the true remaining time
        //     rather than a stale scheduled instant.
        TimelineView(.animation(minimumInterval: 0.5, paused: ambientPaused)) { _ in
            Text(Self.countdown(to: revealAt, from: Date()))
                .font(.system(size: 26, weight: .bold).monospacedDigit())
                .foregroundStyle(Palette.gold)
        }
    }

    /// Unchanged from the version that lived on `AlbumDetailView`: days + hours
    /// + minutes while the roll is more than a day out, a zero-padded clock
    /// once it's inside a day.
    private static func countdown(to revealAt: Date, from now: Date) -> String {
        let interval = max(0, revealAt.timeIntervalSince(now))
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

private struct IndexBox: Identifiable {
    let value: Int
    var id: Int { value }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - QR-based share sheet

struct AlbumShareSheet: View {
    let albumId: String
    let albumName: String
    @Environment(ToastCenter.self) private var toast
    @State private var showSystemShare = false

    private var qrImage: UIImage? {
        QRCodeGenerator.image(from: albumId, size: 300)
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("invite to album")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.gold)
                    .padding(.top, 16)
                Text(albumName)
                    .font(.system(size: 13)).italic()
                    .foregroundStyle(Palette.textSecondary)

                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .padding(16)
                        .background(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Palette.gold, lineWidth: 2)
                        )
                }

                VStack(spacing: 4) {
                    Text("ALBUM CODE")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(Palette.textTertiary)
                    Text(albumId)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Palette.surface)
                        .cornerRadius(6)
                        .onTapGesture {
                            UIPasteboard.general.string = albumId
                            toast.success("code copied")
                        }
                }

                Button { showSystemShare = true } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("share")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Palette.gold)
                    .cornerRadius(8)
                    .padding(.horizontal, 24)
                }
                .padding(.top, 8)

                Text("friends scan the QR — or paste the code in the Camera tab → Join.")
                    .font(.system(size: 10)).italic()
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()
            }
        }
        .sheet(isPresented: $showSystemShare) {
            ShareSheet(items: ["Join my afterimage album \"\(albumName)\"\nCode: \(albumId)"])
        }
    }
}
