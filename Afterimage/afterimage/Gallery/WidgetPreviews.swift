import SwiftUI

// MARK: - Live Activity (Dynamic Island + lock-screen card) preview
//
// These are pure SwiftUI mockups that render what the real ActivityKit widget
// would look like. Wiring them to ActivityKit requires adding a Widget Extension
// target in Xcode — outside the scope of sample-only mode.

struct LiveActivityPreviewDesign: View {
    @State private var progress: Double = 0.62

    var body: some View {
        VStack(spacing: 14) {
            Text("LIVE ACTIVITY · DYNAMIC ISLAND")
                .font(.custom("Menlo", size: 10)).tracking(2)
                .foregroundStyle(Palette.textTertiary)
            dynamicIsland
            Text("LIVE ACTIVITY · LOCK SCREEN CARD")
                .font(.custom("Menlo", size: 10)).tracking(2)
                .foregroundStyle(Palette.textTertiary)
                .padding(.top, 6)
            lockScreenCard
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Palette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
    }

    /// Pill island — expands to show the next-reveal countdown.
    private var dynamicIsland: some View {
        HStack(spacing: 8) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.gold)
            VStack(alignment: .leading, spacing: 1) {
                Text("NYE 2025 reveals in")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
                Text("4h 12m 8s")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(Palette.gold)
            }
            Spacer()
            ZStack {
                Circle().stroke(Palette.gold.opacity(0.3), lineWidth: 3)
                    .frame(width: 28, height: 28)
                Circle().trim(from: 0, to: progress)
                    .stroke(Palette.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(.black)
        .clipShape(Capsule())
    }

    private var lockScreenCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.gold)
                Text("AFTERIMAGE")
                    .font(.custom("Bebas Neue", size: 11)).tracking(3)
                    .foregroundStyle(Palette.gold)
                Spacer()
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Palette.red)
                    .clipShape(Capsule())
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NYE 2025")
                        .font(.custom("Bebas Neue", size: 22)).tracking(2)
                        .foregroundStyle(.white)
                    Text("18 of 24 shots · 4h 12m to reveal")
                        .font(.custom("Times New Roman", size: 12)).italic()
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("4:12")
                    .font(.system(size: 28, weight: .bold).monospacedDigit())
                    .foregroundStyle(Palette.gold)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(Palette.gold).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .padding(14)
        .background(.black)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.gold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Home screen widget preview (medium-size)

struct HomeWidgetPreviewDesign: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("HOME SCREEN WIDGET · MEDIUM")
                .font(.custom("Menlo", size: 10)).tracking(2)
                .foregroundStyle(Palette.textTertiary)
            widgetCard
            Text("HOME SCREEN WIDGET · SMALL")
                .font(.custom("Menlo", size: 10)).tracking(2)
                .foregroundStyle(Palette.textTertiary)
                .padding(.top, 8)
            HStack(spacing: 12) {
                widgetSmall
                widgetSmall
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Palette.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
    }

    private var widgetCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "film.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.gold)
                Text("DEVELOPING · 2")
                    .font(.custom("Bebas Neue", size: 11)).tracking(3)
                    .foregroundStyle(Palette.gold)
                Spacer()
                Text("4:12")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(Palette.red)
            }
            HStack(spacing: 8) {
                miniRoll(name: "NYE 2025",   countdown: "4h 12m", glow: Palette.red)
                miniRoll(name: "ROAD TRIP",  countdown: "1d 8h",  glow: Palette.darkRed.opacity(0.6))
            }
            HStack(spacing: 4) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.gold)
                Text("tap to open afterimage")
                    .font(.custom("Times New Roman", size: 10)).italic()
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.black)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.gold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func miniRoll(name: String, countdown: String, glow: Color) -> some View {
        ZStack {
            RadialGradient(colors: [glow.opacity(0.4), .clear],
                           center: .center, startRadius: 4, endRadius: 40)
            VStack(spacing: 2) {
                Text(name).font(.custom("Bebas Neue", size: 10)).tracking(1.5)
                    .foregroundStyle(.white)
                Text(countdown).font(.custom("Menlo", size: 9)).tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(.black.opacity(0.6))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(glow.opacity(0.5), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var widgetSmall: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.gold)
                Text("NEXT")
                    .font(.custom("Bebas Neue", size: 9)).tracking(2)
                    .foregroundStyle(Palette.gold)
                Spacer()
            }
            Spacer()
            Text("4:12:08")
                .font(.system(size: 20, weight: .bold).monospacedDigit())
                .foregroundStyle(Palette.gold)
            Text("NYE 2025")
                .font(.custom("Bebas Neue", size: 11)).tracking(1.5)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(.black)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.gold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
