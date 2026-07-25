import SwiftUI

// MARK: - CameraTabView
//
// The camera tab is always the live camera — loaded with your one active roll
// (last used, falling back to the most recent developing roll). One roll at a
// time, so there's no roll selector on the camera. There is no "closed" screen
// and no ✕ — to leave, you just tap another tab. If you have no developing
// rolls, the editorial empty state shows instead.

struct CameraTabView: View {
    /// True only while the camera is the page on screen and the app is
    /// foregrounded. Forwarded straight to `CameraView`, which gates
    /// `startRunning`/`stopRunning` on it — the paged TabView keeps this view
    /// mounted on every tab, so visibility can't be inferred from the view
    /// lifecycle (see MainTabView).
    let isActive: Bool
    @Environment(AuthService.self) private var auth
    @State private var albumService = AlbumService()
    @State private var showCreate = false
    @State private var showJoin = false
    @AppStorage("lastUsedAlbumId") private var lastUsedAlbumId: String = ""

    private var activeAlbums: [Album] {
        albumService.albums.filter { !$0.isRevealed }
    }

    /// The roll the camera loads by default — last used, else most recent.
    private var defaultAlbum: Album? {
        activeAlbums.first(where: { $0.id == lastUsedAlbumId }) ?? activeAlbums.first
    }

    var body: some View {
        ZStack(alignment: .top) {
            // PURE black, not Palette.background — the warm dark reads as a
            // grey panel where it shows below the shell art; pure black lets
            // the area under the shell vanish the same way the top does.
            Color.black.ignoresSafeArea()

            if let album = defaultAlbum {
                // The live camera, always open. The shell artwork runs under
                // the status bar (top edge flush with the top of the screen)
                // and stops above the compact tab bar.
                CameraView(album: album, isActive: isActive)
                    .environment(auth)
            } else {
                RadialGradient(
                    colors: [Palette.gold.opacity(0.10), .clear],
                    center: UnitPoint(x: 0.5, y: 0.18), startRadius: 6, endRadius: 380
                )
                .ignoresSafeArea().allowsHitTesting(false)
                ScrollView { emptyState }.scrollIndicators(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if let uid = auth.uid { albumService.startListening(userId: uid) }
        }
        .sheet(isPresented: $showCreate) {
            CreateAlbumView().environment(auth)
        }
        .sheet(isPresented: $showJoin) {
            JoinAlbumView().environment(auth)
        }
    }

    // MARK: - Empty state (no developing rolls)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Color.clear.frame(height: 84)
            HStack(spacing: 6) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text("NOTHING LOADED")
                    .font(.custom("Menlo", size: 10)).tracking(3)
                    .foregroundStyle(Palette.gold)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                Capsule().fill(Palette.gold.opacity(0.10))
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1))
            )

            VStack(alignment: .leading, spacing: -2) {
                Text("THE CAMERA")
                    .font(.custom("Bebas Neue", size: 46)).tracking(-1)
                    .foregroundStyle(Palette.textPrimary)
                Text("IS EMPTY.")
                    .font(.custom("Bebas Neue", size: 46)).tracking(-1)
                    .foregroundStyle(Palette.gold)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.55)

            Text("there are no rolls waiting for shots. start a new one, or join a friend's.")
                .font(.custom("Times New Roman", size: 14)).italic()
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.leading)

            VStack(spacing: 12) {
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    showCreate = true
                } label: {
                    emptyActionLabel(icon: "plus.circle.fill", title: "CREATE ALBUM", filled: true)
                }
                .buttonStyle(.plain)
                .pressEffect()
                .accessibilityLabel("Create a new album")

                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    showJoin = true
                } label: {
                    emptyActionLabel(icon: "qrcode.viewfinder", title: "JOIN ALBUM", filled: false)
                }
                .buttonStyle(.plain)
                .pressEffect()
                .accessibilityLabel("Join a friend's album")
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Large, present call-to-action used in the empty state.
    private func emptyActionLabel(icon: String, title: String, filled: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
            Text(title)
                .font(.custom("Bebas Neue", size: 19)).tracking(3)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .opacity(0.7)
        }
        .foregroundStyle(filled ? .black : Palette.gold)
        .padding(.horizontal, 18).padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(filled ? Palette.gold : Palette.gold.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(filled ? .clear : Palette.gold.opacity(0.5), lineWidth: 1.5)
                )
        )
        .warmShadow(radius: filled ? 12 : 0, y: filled ? 5 : 0, opacity: filled ? 0.4 : 0)
    }
}
