import SwiftUI

// MARK: - OnboardingFlow (Editorial Luxury rebuild)
//
// Replaces the centered LLM-default productivity-app intro with three
// cinematic chapters. Each step uses the canonical hero anatomy:
//   ambient leader → backdrop wash → centered icon module → left-aligned
//   eyebrow + Bebas 52pt title + italic Times body → film-leader progress
//   strip → Editorial Luxury CTA with button-in-button trailing arrow.

struct OnboardingFlow: View {
    let onFinish: () -> Void
    @State private var step: Int = 0
    @State private var revealed = false

    private let steps: [OnboardingStep] = [
        .init(
            kicker: "WELCOME",
            titleTop: "SHOOT BLIND.",
            titleBottom: "DEVELOP TOGETHER.",
            body: "afterimage is a disposable camera for groups. you shoot, you wait, you reveal — all at once, at sunrise.",
            icon: "camera.aperture",
            tint: Palette.gold
        ),
        .init(
            kicker: "HOW IT WORKS",
            titleTop: "NO PREVIEW.",
            titleBottom: "NO RETAKES.",
            body: "every shot is sealed the moment you press the shutter. nobody sees anything — not even you — until the roll develops.",
            icon: "film.fill",
            tint: Palette.darkRed
        ),
        .init(
            kicker: "GATHER",
            titleTop: "REVEAL AT",
            titleBottom: "SUNRISE.",
            body: "your roll opens at the next sunrise after the window closes. everyone sees the full set at once.",
            icon: "sunrise.fill",
            tint: Palette.gold
        ),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            backdrop

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 24)
                iconModule
                    .padding(.bottom, 32)
                textBlock
                    .padding(.horizontal, 22)
                Spacer(minLength: 28)
                bottomBar
            }

            // Ambient leader sits above the whole flow — same continuity as
            // SignInView's intro.
            VStack {
                AmbientFilmLeader()
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(Motion.cinematic.delay(0.12)) { revealed = true }
        }
    }

    private var currentStep: OnboardingStep { steps[step] }

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let pulse = (sin(t * (2 * .pi / 6.8)) + 1) / 2
                RadialGradient(
                    colors: [
                        currentStep.tint.opacity(0.28 + 0.10 * pulse),
                        currentStep.tint.opacity(0.14 + 0.06 * pulse),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.30),
                    startRadius: 4,
                    endRadius: 400
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(Motion.cinematic, value: step)
            }
        }
    }

    // MARK: - Top bar (floating skip island)

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onFinish()
            } label: {
                HStack(spacing: 5) {
                    Text("SKIP")
                        .font(.custom("Bebas Neue", size: 11)).tracking(2)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(
                    Capsule().fill(Palette.surface.opacity(0.7))
                        .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .pressEffect()
            .accessibilityLabel("Skip onboarding")
        }
        .padding(.trailing, 18)
        .padding(.top, 16)
    }

    // MARK: - Icon module (breathing ambient ring + Double-Bezel)

    private var iconModule: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let breathe = (sin(t * 1.4) + 1) / 2
            ZStack {
                // Outer ring
                Circle()
                    .stroke(currentStep.tint.opacity(0.12 + 0.10 * breathe), lineWidth: 1)
                    .frame(width: 200, height: 200)
                Circle()
                    .stroke(currentStep.tint.opacity(0.18 + 0.08 * breathe), lineWidth: 1)
                    .frame(width: 160, height: 160)
                // Inner glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [currentStep.tint.opacity(0.22 + 0.08 * breathe), .clear],
                            center: .center, startRadius: 4, endRadius: 80
                        )
                    )
                    .frame(width: 180, height: 180)
                // Icon plate (Double-Bezel)
                ZStack {
                    Circle()
                        .fill(Palette.surface)
                        .overlay(
                            Circle().stroke(.white.opacity(0.06), lineWidth: 1)
                        )
                    Image(systemName: currentStep.icon)
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(currentStep.tint)
                        .scaleEffect(1.0 + 0.04 * breathe)
                }
                .frame(width: 96, height: 96)
                .padding(3)
                .background(
                    Circle()
                        .fill(Palette.background.opacity(0.6))
                        .overlay(Circle().stroke(currentStep.tint.opacity(0.4), lineWidth: 1))
                )
                .frame(width: 110, height: 110)
            }
            .id(step)
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
        .animation(Motion.cinematic, value: step)
    }

    // MARK: - Text block (eyebrow + 2-line Bebas title + italic Times body)

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(currentStep.tint).frame(width: 5, height: 5)
                Text(currentStep.kicker)
                    .font(.custom("Menlo", size: 10)).tracking(3)
                    .foregroundStyle(currentStep.tint)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                Capsule().fill(currentStep.tint.opacity(0.10))
                    .overlay(Capsule().stroke(currentStep.tint.opacity(0.4), lineWidth: 1))
            )

            VStack(alignment: .leading, spacing: -2) {
                Text(currentStep.titleTop)
                    .font(.custom("Bebas Neue", size: 50)).tracking(-1)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(currentStep.titleBottom)
                    .font(.custom("Bebas Neue", size: 50)).tracking(-1)
                    .foregroundStyle(currentStep.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(currentStep.body)
                .font(.custom("Times New Roman", size: 14)).italic()
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .id(step)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 14)
        .animation(Motion.cinematic, value: step)
    }

    // MARK: - Bottom bar (film leader progress + Editorial Luxury CTA)

    private var bottomBar: some View {
        VStack(spacing: 18) {
            // Film leader progress strip — three capsules that "fill in" gold
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Palette.gold : Palette.border)
                        .frame(width: i == step ? 32 : 16, height: 4)
                        .animation(Motion.expressive, value: step)
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                if step < steps.count - 1 {
                    withAnimation(Motion.expressive) { step += 1 }
                } else {
                    onFinish()
                }
            } label: {
                HStack(spacing: 10) {
                    Text(step < steps.count - 1 ? "NEXT" : "BEGIN")
                        .font(.custom("Bebas Neue", size: 17)).tracking(4)
                        .foregroundStyle(.black)
                    ZStack {
                        Circle().fill(.black.opacity(0.18))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    .frame(width: 26, height: 26)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(Palette.gold))
                .warmShadow(radius: 12, y: 7, opacity: 0.5)
            }
            .buttonStyle(.plain)
            .pressEffect(scale: 0.97, lift: 1)
            .padding(.horizontal, 22)
            .accessibilityLabel(step < steps.count - 1 ? "Next step" : "Begin Afterimage")

            // Tiny ledger footnote
            HStack(spacing: 6) {
                Rectangle().fill(Palette.border).frame(height: 1)
                Text("CHAPTER \(String(format: "%02d", step + 1)) OF \(String(format: "%02d", steps.count))")
                    .font(.custom("Menlo", size: 9)).tracking(2.5)
                    .foregroundStyle(Palette.textTertiary)
                Rectangle().fill(Palette.border).frame(height: 1)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
        }
    }

    // MARK: - Step model

    private struct OnboardingStep {
        let kicker: String
        let titleTop: String
        let titleBottom: String
        let body: String
        let icon: String
        let tint: Color
    }
}
