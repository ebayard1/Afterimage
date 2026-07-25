import SwiftUI

/// The sacred moment — what plays when a roll crosses its `revealAt` time.
/// Three stages auto-advance with timed delays: developing → almost ready → ready.
struct SunriseRevealView: View {
    let album: Album
    @Environment(\.dismiss) private var dismiss
    @State private var stage: Int = 1

    var body: some View {
        ZStack {
            (stage == 3 ? Palette.background : Color(red: 0.09, green: 0.02, blue: 0.02))
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer().frame(height: 40)

                Text(album.name.uppercased())
                    .font(.custom("Bebas Neue", size: 18)).tracking(3)
                    .foregroundStyle(stage == 3 ? Palette.gold.opacity(0.7) : Palette.darkRed.opacity(0.7))

                // Central animated burst — ripples + icon
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let breathe = (sin(t * 1.6) + 1) / 2  // 0…1
                    ZStack {
                        if stage < 3 {
                            ForEach(Array([110.0, 150.0, 190.0, 230.0].enumerated()), id: \.offset) { i, r in
                                Circle()
                                    .stroke(Palette.darkRed.opacity(0.10 + 0.22 * breathe), lineWidth: 1)
                                    .frame(width: r, height: r)
                                    .scaleEffect(1.0 + 0.03 * breathe * (Double(i) + 1) / 4)
                            }
                        }
                        Circle()
                            .fill(RadialGradient(
                                colors: [
                                    (stage == 3 ? Palette.gold : Palette.darkRed).opacity(stage == 3 ? 0.32 : 0.20 + 0.18 * breathe),
                                    .clear
                                ],
                                center: .center, startRadius: 8, endRadius: 120
                            ))
                            .frame(width: 240, height: 240)
                        Image(systemName: stage == 3 ? "film" : "camera.aperture")
                            .font(.system(size: stage == 3 ? 56 : 44))
                            .foregroundStyle(stage == 3 ? Palette.gold : Palette.darkRed)
                            .scaleEffect(stage == 3 ? 1.0 : 1.0 + 0.05 * breathe)
                    }
                    .accessibilityHidden(true)
                }
                .frame(height: 240)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.custom("Bebas Neue", size: 30)).tracking(3)
                        .foregroundStyle(stage == 3 ? Palette.gold : Palette.darkRed)
                    Text(sub)
                        .font(.custom("Times New Roman", size: 14)).italic()
                        .foregroundStyle(stage == 3 ? Palette.textSecondary : Palette.darkRed.opacity(0.8))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.6))
                        Capsule()
                            .fill(stage == 3 ? Palette.gold : Palette.darkRed)
                            .frame(width: geo.size.width * progress)
                            .animation(Motion.expressive, value: progress)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 48)

                Text("\(Int(progress * 100))% DEVELOPED")
                    .font(.custom("Menlo", size: 11)).tracking(2)
                    .foregroundStyle(stage == 3 ? Palette.textTertiary : Palette.darkRed.opacity(0.7))

                Spacer()

                if stage == 3 {
                    Button { dismiss() } label: {
                        HStack(spacing: 10) {
                            Text("OPEN ROLL")
                                .font(.custom("Bebas Neue", size: 18)).tracking(4)
                                .foregroundStyle(.black)
                            ZStack {
                                Circle().fill(.black.opacity(0.18))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                            .frame(width: 26, height: 26)
                        }
                        .padding(.leading, 30).padding(.trailing, 12).padding(.vertical, 10)
                        .background(Palette.gold)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .pressEffect()
                    .warmShadow(radius: 12, y: 8, opacity: 0.5)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .accessibilityLabel("Open \(album.name)")
                    .accessibilityHint("Reveals the roll")
                    .padding(.bottom, 40)
                } else {
                    Text("do not close the app")
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.darkRed.opacity(0.6))
                        .padding(.bottom, 40)
                }
            }

            // Close affordance top-left
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(10)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Skip reveal")
                    .accessibilityHint("Closes the cinematic and returns to the roll")
                    Spacer()
                }
                Spacer()
            }
            .padding(16)
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            Haptics.selectionChanged()
            withAnimation(Motion.cinematic) { stage = 2 }
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            // The reveal moment — the app's heaviest haptic, at full intensity.
            // `Haptics` keeps the generator prepared across taps, so the manual
            // `prepare()` that used to sit here is no longer needed.
            Haptics.heavy(intensity: 1.0)
            withAnimation(Motion.cinematic) { stage = 3 }
            // Soft notification "success" feedback a beat after.
            try? await Task.sleep(nanoseconds: 200_000_000)
            Haptics.notify(.success)
        }
        .preferredColorScheme(.dark)
    }

    private var title: String {
        switch stage {
        case 1: return "developing…"
        case 2: return "almost ready"
        case 3: return "ready to reveal"
        default: return ""
        }
    }
    private var sub: String {
        switch stage {
        case 1: return "the roll is in the bath"
        case 2: return "images surfacing"
        case 3: return "tap to open your roll"
        default: return ""
        }
    }
    private var progress: Double {
        switch stage {
        case 1: return 0.30
        case 2: return 0.75
        case 3: return 1.0
        default: return 0
        }
    }
}
