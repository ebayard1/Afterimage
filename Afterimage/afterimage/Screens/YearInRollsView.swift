import SwiftUI

/// "Your year in rolls" — auto-advancing recap that walks through every shot
/// across all revealed sample albums, with the album name and date as a hero overlay.
struct YearInRollsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int = 0
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?
    @State private var dragOffset: CGFloat = 0
    @State private var dragStart: Date?

    private let secondsPerShot: Double = 2.4

    /// Flat list of (album, shot) pairs across every revealed sample album.
    private let entries: [(album: Album, shot: Shot)] = {
        let revealed = SampleData.albums.filter { $0.isRevealed }
        var pairs: [(Album, Shot)] = []
        for album in revealed {
            for shot in SampleData.shots(forAlbumId: album.id ?? "") {
                pairs.append((album, shot))
            }
        }
        return pairs
    }()

    private var currentYear: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: Date())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let entry = current {
                AsyncImage(url: URL(string: entry.shot.photoURL)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .scaleEffect(1.05 + 0.05 * progress)
                    default:
                        ShimmerPlaceholder()
                    }
                }
                .id(entry.shot.id)
                .ignoresSafeArea()
                .transition(.opacity)
            }

            LinearGradient(colors: [.black.opacity(0.75), .clear, .black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                topBar
                Spacer()
                heroOverlay
                Spacer().frame(height: 20)
                scrubBar
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if dragStart == nil { dragStart = Date() }
                    if abs(value.translation.height) > abs(value.translation.width) {
                        dragOffset = max(0, value.translation.height)
                    }
                }
                .onEnded { value in
                    // Velocity-based dismissal (Emil) — quick flick is enough.
                    let elapsedMs = max(1, Date().timeIntervalSince(dragStart ?? Date()) * 1000)
                    let velocity = abs(value.translation.height) / elapsedMs
                    dragStart = nil
                    if value.translation.height > 100 || (value.translation.height > 24 && velocity > 0.11) {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        dismiss()
                    } else {
                        withAnimation(Motion.tap) { dragOffset = 0 }
                    }
                }
        )
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .preferredColorScheme(.dark)
    }

    private var current: (album: Album, shot: Shot)? {
        guard !entries.isEmpty, index >= 0, index < entries.count else { return nil }
        return entries[index]
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                    Text("CLOSE")
                        .font(.custom("Bebas Neue", size: 13)).tracking(2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(.black.opacity(0.7))
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .pressEffect()
            .accessibilityLabel("Close year recap")

            Spacer()
            VStack(alignment: .center, spacing: 2) {
                Capsule().fill(.white.opacity(0.45))
                    .frame(width: 40, height: 4)
                Text("swipe down to close")
                    .font(.custom("Times New Roman", size: 10)).italic()
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("YOUR YEAR IN ROLLS")
                    .font(.custom("Bebas Neue", size: 11)).tracking(3)
                    .foregroundStyle(.white.opacity(0.7))
                Text(currentYear)
                    .font(.custom("Bebas Neue", size: 20)).tracking(2)
                    .foregroundStyle(Palette.gold)
            }
        }
        .padding(.horizontal, 14).padding(.top, 8)
    }

    private var heroOverlay: some View {
        if let entry = current {
            return AnyView(
                VStack(spacing: 6) {
                    Text(entry.album.name.uppercased())
                        .font(.custom("Bebas Neue", size: 32)).tracking(3)
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        Text(formattedDate(entry.album.createdAt))
                            .font(.custom("Menlo", size: 11)).tracking(2)
                            .foregroundStyle(.white.opacity(0.6))
                        if let loc = SampleData.location(forAlbumId: entry.album.id ?? "") {
                            Text("·").foregroundStyle(.white.opacity(0.4))
                            Text(loc.uppercased())
                                .font(.custom("Bebas Neue", size: 12)).tracking(2)
                                .foregroundStyle(Palette.gold)
                        }
                    }
                    if let note = entry.shot.note, !note.isEmpty {
                        Text("\u{201C}\(note)\u{201D}")
                            .font(.custom("Times New Roman", size: 14)).italic()
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24).padding(.vertical, 8)
                            .background(.black.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 20)
            )
        }
        return AnyView(EmptyView())
    }

    private var scrubBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18)).frame(height: 3)
                    Capsule().fill(Palette.gold).frame(width: geo.size.width * overallProgress, height: 3)
                }
            }
            .frame(height: 3)
            HStack {
                Text("\(index + 1) / \(entries.count)")
                    .font(.custom("Menlo", size: 10)).tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("\(SampleData.albums.filter { $0.isRevealed }.count) ROLLS")
                    .font(.custom("Bebas Neue", size: 11)).tracking(2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 18).padding(.bottom, 22)
    }

    private var overallProgress: CGFloat {
        guard !entries.isEmpty else { return 0 }
        let perShot = 1.0 / CGFloat(entries.count)
        return CGFloat(index) * perShot + progress * perShot
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d yyyy"
        return f.string(from: date)
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                progress += 0.05 / secondsPerShot
                if progress >= 1 {
                    progress = 0
                    if index < entries.count - 1 {
                        withAnimation(Motion.cinematic) { index += 1 }
                    } else {
                        withAnimation(Motion.cinematic) { index = 0 }
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
