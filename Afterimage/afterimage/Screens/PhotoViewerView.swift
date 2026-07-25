import SwiftUI
import AVFoundation

struct PhotoViewerView: View {
    let album: Album
    let shots: [Shot]
    @State var startIndex: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @State private var shotService = ShotService()
    @State private var commentService = CommentService()
    @State private var showComments = false
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
                            if shot.isVideo, let vurl = shot.videoURL, !vurl.isEmpty {
                                // Poster + play button; plays inline on tap.
                                VideoFrame(posterURL: shot.photoURL, videoURL: vurl,
                                           isActive: idx == startIndex)
                            } else {
                                AsyncImage(url: URL(string: shot.photoURL)) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFit()
                                            .frame(width: geo.size.width, height: geo.size.height)
                                    default:
                                        ProgressView().tint(Palette.gold)
                                    }
                                }
                            }
                            // Caption printed on the frame — the author's note from shutter time.
                            if let note = shot.note, !note.isEmpty {
                                VStack {
                                    Spacer()
                                    captionOverlay(note)
                                }
                                .frame(width: geo.size.width, height: geo.size.height)
                            }
                        }
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .never))

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
        // Firestore listeners don't self-remove on dealloc.
        .onDisappear {
            shotService.stopListening()
            commentService.stopListening()
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
            HStack(spacing: 10) {
                commentsButton
                bookmarkButton
            }
            .padding(.bottom, 24)
        }
    }

    /// The author's caption, printed onto the bottom of the frame with a soft scrim.
    private func captionOverlay(_ note: String) -> some View {
        Text("\u{201C}\(note)\u{201D}")
            .font(.custom("Times New Roman", size: 16)).italic()
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 60)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .top, endPoint: .bottom
                )
            )
    }

    /// Bookmark toggle for the current shot.
    private var bookmarkButton: some View {
        Button {
            guard let shot = currentShot, let id = shot.id else { return }
            Haptics.selectionChanged()
            savedStore.toggle(id: id, photoURL: shot.photoURL,
                              albumName: album.name)
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
}

// MARK: - Tap-to-play video frame (poster still + play button, loops on play)

private struct VideoFrame: View {
    let posterURL: String
    let videoURL: String
    let isActive: Bool

    @State private var playing = false
    @State private var player = AVPlayer()
    @State private var loopObserver: NSObjectProtocol?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if playing {
                    VideoLayer(player: player)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    AsyncImage(url: URL(string: posterURL)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                        default:
                            ProgressView().tint(Palette.gold)
                        }
                    }
                    Button { start() } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 62))
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.5), radius: 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: isActive) { _, active in
            if !active { stop() }
        }
        .onDisappear { stop() }
    }

    private func start() {
        guard let u = URL(string: videoURL) else { return }
        let item = AVPlayerItem(url: u)
        removeLoop()
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { _ in
            player.seek(to: .zero); player.play()   // loop
        }
        player.replaceCurrentItem(with: item)
        player.play()
        playing = true
    }

    private func stop() {
        player.pause()
        playing = false
        removeLoop()
    }

    private func removeLoop() {
        if let o = loopObserver {
            NotificationCenter.default.removeObserver(o)
            loopObserver = nil
        }
    }
}

/// Thin AVPlayerLayer wrapper — fills the frame, no system controls.
private struct VideoLayer: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerUIView {
        let v = PlayerUIView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspect
        return v
    }
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
