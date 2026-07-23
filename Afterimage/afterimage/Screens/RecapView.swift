import SwiftUI

/// Faux "recap video" experience for revealed albums.
/// We don't actually composite a real video — we ken-burns through the shots
/// on a timer with overlaid metadata + a scrub bar populated with reactions.
struct RecapView: View {
    let album: Album
    let shots: [Shot]
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int = 0
    @State private var progress: CGFloat = 0
    @State private var isPlaying: Bool = true
    @State private var timer: Timer?
    @State private var dragOffset: CGFloat = 0
    @State private var dragStart: Date?
    @State private var didFinish: Bool = false

    private let secondsPerShot: Double = 3.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Current "frame"
            if let shot = currentShot, let url = URL(string: shot.photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .scaleEffect(1.05 + 0.05 * progress) // subtle ken-burns
                    default:
                        ShimmerPlaceholder()
                    }
                }
                .ignoresSafeArea()
                .id(shot.id) // forces fade across shots
                .transition(.opacity)
            }

            // Vignette
            LinearGradient(colors: [.black.opacity(0.55), .clear, .black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
                if let shot = currentShot, let note = shot.note, !note.isEmpty {
                    Text("\u{201C}\(note)\u{201D}")
                        .font(.custom("Times New Roman", size: 16)).italic()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }
                Spacer().frame(height: 12)
                bottomBar
            }

            // End-of-recap overlay — final clear "DONE" CTA so the user can never
            // get stuck.
            if didFinish {
                doneOverlay
                    .transition(.opacity)
            }
        }
        .offset(y: dragOffset)
        .gesture(
            // Swipe DOWN to dismiss — only respond to vertical drags so we
            // don't swallow horizontal scrubs.
            DragGesture()
                .onChanged { value in
                    if dragStart == nil { dragStart = Date() }
                    if abs(value.translation.height) > abs(value.translation.width) {
                        dragOffset = max(0, value.translation.height)
                    }
                }
                .onEnded { value in
                    // Emil's velocity-based dismissal: a quick flick should be
                    // enough — don't require a long drag past a threshold.
                    //   velocity = |distance| / elapsed_ms
                    //   dismiss if velocity > 0.11 OR distance > 100pt
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

    private var currentShot: Shot? {
        guard index >= 0 && index < shots.count else { return nil }
        return shots[index]
    }

    /// Top chrome — large, high-contrast close affordance + drag-down hint.
    /// Sits inside the safe area so the notch / Dynamic Island never covers it.
    private var topBar: some View {
        HStack(alignment: .top) {
            // Big, obvious close button — uses "Done" word so it's unmissable.
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
            .accessibilityLabel("Close recap")
            Spacer()
            VStack(alignment: .center, spacing: 2) {
                // Drag indicator — visual cue that you can swipe down too.
                Capsule().fill(.white.opacity(0.45))
                    .frame(width: 40, height: 4)
                Text("swipe down to close")
                    .font(.custom("Times New Roman", size: 10)).italic()
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(album.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(shots.count) shots · \(album.memberIds.count) people")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: 140, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.top, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            // Scrub bar — plain progress line, no reaction markers.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18)).frame(height: 3)
                    Capsule().fill(Palette.gold).frame(width: geo.size.width * overallProgress, height: 3)
                }
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                Button {
                    isPlaying.toggle()
                    isPlaying ? startTimer() : stopTimer()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(Palette.gold)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .pressEffect()
                .accessibilityLabel(isPlaying ? "Pause recap" : "Resume recap")

                Text("\(index + 1) / \(shots.count)")
                    .font(.custom("Menlo", size: 11)).tracking(1)
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()

                // Backup close button at the bottom — second escape hatch.
                Button {
                    dismiss()
                } label: {
                    Text("DONE")
                        .font(.custom("Bebas Neue", size: 13)).tracking(3)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(.black.opacity(0.7))
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .pressEffect()
                .accessibilityLabel("Done with recap")
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 24)
    }

    /// Final overlay when the recap reaches its last shot — guarantees the user
    /// always sees an obvious exit even if they ignored everything else.
    private var doneOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Palette.gold)
            Text("THAT'S THE ROLL")
                .font(.custom("Bebas Neue", size: 22)).tracking(4)
                .foregroundStyle(Palette.gold)
            Text("\(shots.count) shots · \(album.memberIds.count) people")
                .font(.custom("Times New Roman", size: 13)).italic()
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 12) {
                Button {
                    didFinish = false
                    index = 0
                    progress = 0
                    isPlaying = true
                    startTimer()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("REPLAY")
                            .font(.custom("Bebas Neue", size: 14)).tracking(3)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .pressEffect()

                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text("CLOSE")
                            .font(.custom("Bebas Neue", size: 14)).tracking(3)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Palette.gold)
                    .clipShape(Capsule())
                    .warmShadow(radius: 8, y: 4, opacity: 0.45)
                }
                .buttonStyle(.plain)
                .pressEffect(scale: 0.96, lift: 1)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .background(.black.opacity(0.78))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.gold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 28)
    }

    private var overallProgress: CGFloat {
        let perShot = 1.0 / CGFloat(max(1, shots.count))
        return CGFloat(index) * perShot + progress * perShot
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                progress += 0.05 / secondsPerShot
                if progress >= 1.0 {
                    progress = 0
                    if index < shots.count - 1 {
                        withAnimation(Motion.cinematic) { index += 1 }
                    } else {
                        // Hit the end — stop and show the done overlay so the
                        // user has an obvious next step.
                        stopTimer()
                        isPlaying = false
                        withAnimation(Motion.cinematic) { didFinish = true }
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
