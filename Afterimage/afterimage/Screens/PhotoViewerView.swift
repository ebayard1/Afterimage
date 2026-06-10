import SwiftUI

struct PhotoViewerView: View {
    let album: Album
    let shots: [Shot]
    @State var startIndex: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @State private var shotService = ShotService()
    @State private var commentService = CommentService()
    @State private var zoom: CGFloat = 1.0
    @State private var pendingZoom: CGFloat = 1.0
    @State private var presentedFriend: SampleData.SampleFriend?
    @State private var showComments = false
    @State private var isPlayingVoice = false
    @State private var voiceProgress: Double = 0
    @State private var voiceTimer: Timer?
    private var savedStore: SavedShotsStore { .shared }

    private var albumId: String { album.id ?? "" }

    private var liveShots: [Shot] {
        shotService.shots.isEmpty ? shots : shotService.shots
    }

    private var currentShot: Shot? {
        guard startIndex >= 0, startIndex < liveShots.count else { return nil }
        return liveShots[startIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $startIndex) {
                ForEach(Array(liveShots.enumerated()), id: \.offset) { idx, shot in
                    GeometryReader { geo in
                        ZStack {
                            AsyncImage(url: URL(string: shot.photoURL)) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFit()
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .scaleEffect(idx == startIndex ? zoom * pendingZoom : 1.0)
                                default:
                                    ProgressView().tint(Palette.gold)
                                }
                            }
                            // Tappable face tags (only at 1x to avoid drift)
                            if zoom == 1.0, let shotId = shot.id {
                                let tags = SampleData.faceTags(forShotId: shotId)
                                ForEach(tags) { tag in
                                    let imgFrame = aspectFitFrame(of: geo.size)
                                    let originX = imgFrame.minX + tag.x * imgFrame.width
                                    let originY = imgFrame.minY + tag.y * imgFrame.height
                                    let w = tag.width * imgFrame.width
                                    let h = tag.height * imgFrame.height
                                    Button {
                                        if let friend = SampleData.friend(byUsername: tag.username) {
                                            presentedFriend = friend
                                        }
                                    } label: {
                                        ZStack(alignment: .bottom) {
                                            Rectangle().stroke(Palette.gold.opacity(0.7), lineWidth: 1.5)
                                                .frame(width: w, height: h)
                                            Text(tag.username)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Palette.gold)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(.black.opacity(0.65))
                                                .clipShape(Capsule())
                                                .offset(y: 10)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .position(x: originX + w / 2, y: originY + h / 2)
                                }
                            }
                        }
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in pendingZoom = value }
                                .onEnded { _ in
                                    zoom = max(1.0, min(4.0, zoom * pendingZoom))
                                    pendingZoom = 1.0
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation { zoom = zoom > 1.0 ? 1.0 : 2.0 }
                        }
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .onChange(of: startIndex) { _, _ in
                zoom = 1.0
                pendingZoom = 1.0
            }

            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .task {
            shotService.startListening(albumId: albumId, currentUserId: auth.uid ?? "")
            commentService.startListening(albumId: albumId)
        }
        .sheet(item: $presentedFriend) { friend in
            OtherProfileView(friend: friend)
        }
        .sheet(isPresented: $showComments) {
            NavigationStack {
                ZStack {
                    Palette.background.ignoresSafeArea()
                    ScrollView {
                        CommentsSection(
                            album: album,
                            shots: liveShots,
                            highlightShotId: currentShot?.id
                        ) { idx in
                            showComments = false
                            startIndex = idx
                        }
                        .environment(auth)
                    }
                }
                .navigationTitle("comments")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Palette.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showComments = false } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let shot = currentShot, let shotId = shot.id,
               let duration = SampleData.voiceNoteDuration(forShotId: shotId) {
                voiceNotePlayer(shotId: shotId, duration: duration)
                    .padding(.horizontal, 20)
            }
            if let shot = currentShot, let note = shot.note, !note.isEmpty {
                Text("\u{201C}\(note)\u{201D}")
                    .font(.system(size: 14)).italic()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 20)
            }
            HStack(spacing: 10) {
                commentsButton
                bookmarkButton
            }
            .padding(.bottom, 24)
        }
    }

    /// Voice-note playback row — sample-only, animates a fake progress bar.
    private func voiceNotePlayer(shotId: String, duration: Double) -> some View {
        HStack(spacing: 10) {
            Button {
                toggleVoicePlayback(shotId: shotId, duration: duration)
            } label: {
                Image(systemName: isPlayingVoice ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 30)
                    .background(Palette.gold)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlayingVoice ? "Pause voice note" : "Play voice note")

            Waveform(bars: 26, isLive: false, progress: voiceProgress, color: Palette.gold)
                .frame(maxWidth: .infinity)
            Text(String(format: "%0.1fs", duration))
                .font(.custom("Menlo", size: 10)).tracking(1)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.black.opacity(0.55))
        .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1))
        .clipShape(Capsule())
        .onChange(of: startIndex) { _, _ in
            voiceTimer?.invalidate()
            isPlayingVoice = false
            voiceProgress = 0
        }
    }

    /// Bookmark toggle for the current shot.
    private var bookmarkButton: some View {
        Button {
            guard let id = currentShot?.id else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            savedStore.toggle(id)
        } label: {
            let saved = (currentShot?.id).map { savedStore.isSaved($0) } ?? false
            Image(systemName: saved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 14))
                .foregroundStyle(saved ? Palette.gold : .white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.black.opacity(0.6))
                .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel((currentShot?.id).map { savedStore.isSaved($0) } == true ? "Remove bookmark" : "Bookmark this shot")
    }

    private func toggleVoicePlayback(shotId: String, duration: Double) {
        if isPlayingVoice {
            voiceTimer?.invalidate()
            voiceTimer = nil
            isPlayingVoice = false
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        voiceProgress = 0
        isPlayingVoice = true
        let step = 0.05
        voiceTimer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { _ in
            Task { @MainActor in
                voiceProgress += step / duration
                if voiceProgress >= 1 {
                    voiceProgress = 1
                    voiceTimer?.invalidate()
                    voiceTimer = nil
                    isPlayingVoice = false
                }
            }
        }
    }

    private var commentsButton: some View {
        let total = commentService.comments.count
        let aboutThisShot = currentShot.flatMap { shot in
            commentService.comments.filter { $0.referencedShotId == shot.id }.count
        } ?? 0
        return Button { showComments = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 13))
                if total == 0 {
                    Text("be the first to comment")
                        .font(.system(size: 12, weight: .medium))
                } else if aboutThisShot > 0 {
                    Text("\(total) comment\(total == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(aboutThisShot) about this shot")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.gold)
                } else {
                    Text("\(total) comment\(total == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.black.opacity(0.6))
            .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
            .clipShape(Capsule())
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
            }
            Spacer()
            Text("\(startIndex + 1) / \(liveShots.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.black.opacity(0.5))
                .clipShape(Capsule())
        }
        .padding()
    }

    /// Photos are scaledToFit inside the geometry. We approximate the visible image rect
    /// using a 3:4 aspect (matches our picsum photo aspect) so face-tag overlays land roughly right.
    private func aspectFitFrame(of size: CGSize) -> CGRect {
        let imgAspect: CGFloat = 3.0 / 4.0
        let containerAspect = size.width / size.height
        if containerAspect > imgAspect {
            let w = size.height * imgAspect
            return CGRect(x: (size.width - w) / 2, y: 0, width: w, height: size.height)
        } else {
            let h = size.width / imgAspect
            return CGRect(x: 0, y: (size.height - h) / 2, width: size.width, height: h)
        }
    }
}
