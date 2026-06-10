import SwiftUI
import Combine

// MARK: - CameraTabView (high-end-visual-design rebuild)
//
// Variance Engine roll:
//   Vibe:   Editorial Luxury (warm charcoal + gold + Times italic)
//   Layout: Z-Axis Cascade — album cards stack as discrete Double-Bezel
//           plates with macro-whitespace between them. Each card surfaces
//           the countdown + stock + soundtrack so a shooter has full
//           context before tapping in.
//
// Replaces the LLM-default productivity-app list (centered nav title +
// 11pt eyebrow + plain cards) with a cinematic darkroom waiting room.

struct CameraTabView: View {
    @Environment(AuthService.self) private var auth
    @State private var albumService = AlbumService()
    @State private var pickedAlbum: Album?
    @State private var now = Date()

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    /// Sample-only mode — never reads from Firestore.
    private var activeAlbums: [Album] {
        SampleData.albums.filter { !$0.isRevealed }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.background.ignoresSafeArea()

            // Soft warm wash behind the hero — same Editorial Luxury sunrise
            // backdrop as AlbumDetailView for surface continuity.
            RadialGradient(
                colors: [Palette.gold.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 6,
                endRadius: 380
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if activeAlbums.isEmpty {
                ScrollView { emptyState }
                    .scrollIndicators(.hidden)
            } else {
                ScrollView {
                    Color.clear.frame(height: 64)  // room for floating header
                    VStack(alignment: .leading, spacing: 0) {
                        heroBlock
                            .padding(.horizontal, 22)
                            .padding(.bottom, 32)
                        cardStack
                            .padding(.horizontal, 18)
                            .padding(.bottom, 32)
                        footerLine
                            .padding(.horizontal, 22)
                            .padding(.bottom, 36)
                    }
                }
                .scrollIndicators(.hidden)
            }

            // Floating island header — never edge-to-edge.
            VStack {
                floatingHeader
                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(ticker) { now = $0 }
        // Sample-only mode — no Firestore listener.
        //
        // If the user is only in one developing roll, skip the picker and
        // jump straight into the camera. The picker is meaningless when
        // there's nothing to pick between. Fires on every tab activation
        // (so dismissing the camera + switching tabs + coming back re-opens
        // it) but never re-fires mid-session, so users can still get back to
        // the picker by dismissing without leaving the tab.
        .onAppear {
            if pickedAlbum == nil, activeAlbums.count == 1,
               let only = activeAlbums.first {
                pickedAlbum = only
            }
        }
        .fullScreenCover(item: $pickedAlbum) { album in
            CameraView(album: album)
                .environment(auth)
        }
    }

    // MARK: - Floating header (Editorial Luxury glass island)

    private var floatingHeader: some View {
        HStack(spacing: 8) {
            Circle().fill(Palette.gold).frame(width: 5, height: 5)
            Text("CAMERA")
                .font(.custom("Bebas Neue", size: 12)).tracking(3)
                .foregroundStyle(Palette.gold)
            Text("·  \(activeAlbums.count) waiting")
                .font(.custom("Times New Roman", size: 11)).italic()
                .foregroundStyle(Palette.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            Capsule().fill(Palette.surface.opacity(0.75))
                .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 6)
        )
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    // MARK: - Hero — eyebrow + 2-line iron rule title + italic tagline

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text("CHOOSE A ROLL")
                    .font(.custom("Menlo", size: 10)).tracking(3)
                    .foregroundStyle(Palette.gold)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                Capsule().fill(Palette.gold.opacity(0.10))
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1))
            )

            VStack(alignment: .leading, spacing: -2) {
                Text("LOAD THE")
                    .font(.custom("Bebas Neue", size: 52)).tracking(-1)
                    .foregroundStyle(Palette.textPrimary)
                Text("CAMERA.")
                    .font(.custom("Bebas Neue", size: 52)).tracking(-1)
                    .foregroundStyle(Palette.gold)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("each shot is locked to one roll. pick before you press the shutter.")
                .font(.custom("Times New Roman", size: 14)).italic()
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Card stack (Z-Axis cascade with macro-whitespace)

    private var cardStack: some View {
        VStack(spacing: 16) {
            ForEach(Array(activeAlbums.enumerated()), id: \.element.id) { idx, album in
                ScrollFadeIn(delay: Double(idx) * 0.05, distance: 14) {
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        pickedAlbum = album
                    } label: {
                        albumPlate(album: album)
                    }
                    .buttonStyle(.plain)
                    .pressEffect(scale: 0.98, lift: 1)
                    .accessibilityLabel("Shoot for \(album.name)")
                    .accessibilityHint("\(album.memberIds.count) members. Opens the camera locked to this album.")
                }
            }
        }
    }

    /// Album card — Double-Bezel plate with eyebrow countdown + Bebas title +
    /// metadata strip + button-in-button gold camera trailing icon.
    private func albumPlate(album: Album) -> some View {
        HStack(spacing: 14) {
            developingGlyph(for: album)
                .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 6) {
                // Eyebrow: countdown — essential context for a shooter
                HStack(spacing: 6) {
                    PulsingDot(color: Palette.darkRed, size: 5)
                    Text(countdownString(for: album))
                        .font(.custom("Menlo", size: 10)).tracking(2)
                        .foregroundStyle(Palette.darkRed)
                }

                // Title — Bebas Neue display, never system font
                Text(album.name.uppercased())
                    .font(.custom("Bebas Neue", size: 20)).tracking(2)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Metadata strip — members + stock + soundtrack
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "person.2.fill").font(.system(size: 8))
                        Text("\(album.memberIds.count)")
                            .font(.custom("Menlo", size: 10)).tracking(0.5)
                    }
                    .foregroundStyle(Palette.textTertiary)

                    if let stock = album.filmStock {
                        Text("·").foregroundStyle(Palette.textTertiary)
                        HStack(spacing: 3) {
                            Circle().fill(stock.accent).frame(width: 5, height: 5)
                            Text(stock.shortCode)
                                .font(.custom("Bebas Neue", size: 9)).tracking(1.5)
                        }
                        .foregroundStyle(Palette.textSecondary)
                    }
                    if let track = album.soundtrack {
                        Text("·").foregroundStyle(Palette.textTertiary)
                        HStack(spacing: 3) {
                            Image(systemName: "music.note").font(.system(size: 8))
                            Text(track.title.uppercased())
                                .font(.custom("Bebas Neue", size: 9)).tracking(1.5)
                                .lineLimit(1)
                        }
                        .foregroundStyle(Palette.gold.opacity(0.85))
                    }
                }
            }

            Spacer(minLength: 0)

            // Button-in-button trailing — gold camera circle inside the card.
            // This is the high-end-visual-design "Island" CTA pattern.
            ZStack {
                Circle().fill(Palette.gold)
                Image(systemName: "camera.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .frame(width: 36, height: 36)
            .warmShadow(radius: 6, y: 3, opacity: 0.45)
        }
        .padding(12)
        // Inner core
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                )
        )
        // Double-Bezel outer shell
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.background.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Palette.gold.opacity(0.18), lineWidth: 1)
                )
        )
    }

    /// Red darkroom glow square — same visual language as the developing card
    /// in the Rolls feed, so the picker and the feed share a vocabulary.
    private func developingGlyph(for album: Album) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.28, green: 0.06, blue: 0.04),
                            Color(red: 0.09, green: 0.02, blue: 0.02)
                        ],
                        center: .center, startRadius: 4, endRadius: 60
                    )
                )
            Circle()
                .fill(Palette.darkRed.opacity(0.4))
                .frame(width: 32, height: 32)
                .blur(radius: 9)
            Image(systemName: "camera.aperture")
                .font(.system(size: 22))
                .foregroundStyle(Palette.darkRed)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Palette.darkRed.opacity(0.4), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private func countdownString(for album: Album) -> String {
        let interval = max(0, album.revealAt.timeIntervalSince(now))
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        if days > 0 { return "REVEALS IN \(days)D \(hours)H" }
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "REVEALS IN \(hours)H \(minutes)M" }
        return "REVEALS IN \(minutes)M"
    }

    // MARK: - Footer + empty state (editorial, not template)

    private var footerLine: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Palette.border).frame(height: 1)
            Text("NO PREVIEW · NO RETAKES")
                .font(.custom("Menlo", size: 9)).tracking(3)
                .foregroundStyle(Palette.textTertiary)
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Color.clear.frame(height: 84)  // room for floating header
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

            Text("there are no rolls waiting for shots. start one in the Rolls tab, or scan a friend's QR to join theirs.")
                .font(.custom("Times New Roman", size: 14)).italic()
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.leading)

            HStack(spacing: 16) {
                Rectangle().fill(Palette.gold.opacity(0.4)).frame(height: 1)
                Text("WAITING")
                    .font(.custom("Bebas Neue", size: 12)).tracking(3)
                    .foregroundStyle(Palette.gold)
                Rectangle().fill(Palette.gold.opacity(0.4)).frame(height: 1)
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
