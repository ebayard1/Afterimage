import SwiftUI

struct CoachCameraDesign: View {
    var body: some View {
        ZStack {
            // Fake camera background
            Rectangle().fill(LinearGradient(colors: [Color(white: 0.05), Color(white: 0.02)],
                                            startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack {
                Spacer()
                Text("tap to shoot").font(.system(size: 16, weight: .bold)).foregroundStyle(.black) +
                Text("").font(.system(size: 13))
                Spacer().frame(height: 200)
            }
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("tap to shoot").font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                    Text("only shown first time you shoot in a new album")
                        .font(.system(size: 10)).foregroundStyle(.black.opacity(0.7))
                }
                .padding(10)
                .background(Palette.gold)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    Triangle().fill(Palette.gold).frame(width: 14, height: 8)
                        .offset(y: 30),
                    alignment: .bottom
                )
                .padding(.horizontal, 24)
                Spacer().frame(height: 110)
                ZStack {
                    Circle().stroke(Palette.gold, lineWidth: 2).frame(width: 64, height: 64)
                    Circle().fill(.white.opacity(0.05)).frame(width: 64, height: 64)
                }
                Spacer().frame(height: 50)
                Text("tap anywhere to dismiss").font(.system(size: 10)).italic().foregroundStyle(.white.opacity(0.4))
                Spacer().frame(height: 14)
            }
        }
    }
}

struct CoachFeedDesign: View {
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            // Mock feed underneath
            VStack(spacing: 8) {
                Spacer().frame(height: 60)
                ForEach(0..<3, id: \.self) { _ in
                    HStack {
                        RoundedRectangle(cornerRadius: 4).fill(Palette.surface).frame(width: 50, height: 50)
                        VStack(alignment: .leading, spacing: 4) {
                            Rectangle().fill(Palette.border).frame(width: 100, height: 4)
                            Rectangle().fill(Palette.border).frame(width: 70, height: 4)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Palette.surface)
                    .padding(.horizontal, 12)
                }
                Spacer()
            }
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack {
                Spacer().frame(height: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("your developing albums").font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                    Text("tap an album to add shots while the window is open")
                        .font(.system(size: 10)).foregroundStyle(.black.opacity(0.7))
                }
                .padding(10)
                .background(Palette.gold)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 12)
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Palette.gold, lineWidth: 2)
                    .frame(height: 80)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                Spacer()
                Text("tap anywhere to dismiss").font(.system(size: 10)).italic().foregroundStyle(.white.opacity(0.4))
                Spacer().frame(height: 30)
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct ShotViewerDesign: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ImgPlaceholder(label: "shot 3 of 14", dark: true, height: 720)
                .ignoresSafeArea()
            VStack {
                HStack {
                    Image(systemName: "chevron.left").font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("3 / 14").font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Image(systemName: "ellipsis").foregroundStyle(.white.opacity(0.6))
                }
                .padding(12)
                .background(LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
                Spacer()
            }
            // Face tag overlay
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().stroke(Palette.gold.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 100, height: 130)
                    .overlay(
                        Text("@sam").font(.system(size: 10)).foregroundStyle(Palette.gold)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.black.opacity(0.6))
                            .offset(y: 75),
                        alignment: .bottom
                    )
            }
            .offset(x: -40, y: -60)
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                HStack(spacing: 8) {
                    AvatarCircle(label: "M", bg: Color(white: 0.20), fg: .white)
                    Text("@maya · 8:22 PM").font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                }
                Text("\u{201C}the moment we found the rooftop 🌙\u{201D}")
                    .font(.system(size: 13)).italic().foregroundStyle(.white)
                HStack(spacing: 6) {
                    ForEach(["❤️ 4", "🔥 2", "😂 1"], id: \.self) { r in
                        Text(r).font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text("+ react").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.white.opacity(0.06))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct PhotoSwipeDesign: View {
    private let kodak = Color(red: 0.91, green: 0.44, blue: 0.13)
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ImgPlaceholder(label: "", dark: true, height: 720).ignoresSafeArea()
            // Kodak negative border
            Rectangle().stroke(kodak, lineWidth: 6)
                .padding(40)
                .frame(maxHeight: 460)
            Text("05/16/26").font(.system(size: 12, design: .monospaced)).tracking(2).foregroundStyle(kodak)
                .offset(x: 100, y: 180)
            VStack {
                HStack {
                    Image(systemName: "xmark").font(.system(size: 16)).foregroundStyle(.white)
                    Spacer()
                    Text("03 / 14").font(.system(size: 12, design: .monospaced)).foregroundStyle(kodak)
                    Spacer()
                    Image(systemName: "ellipsis").foregroundStyle(.white.opacity(0.7))
                }
                .padding(14)
                Text("swipe ← → · pinch to zoom")
                    .font(.system(size: 10)).italic().foregroundStyle(.white.opacity(0.4))
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<14, id: \.self) { i in
                        Capsule().fill(i == 2 ? kodak : .white.opacity(0.3))
                            .frame(width: i == 2 ? 16 : 5, height: 3)
                    }
                }
                .padding(.bottom, 16)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        AvatarCircle(label: "M", bg: Color(white: 0.20), fg: .white)
                        Text("@maya · 8:22 PM").font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                    }
                    Text("\u{201C}the rooftop moment 🌙\u{201D}")
                        .font(.system(size: 12)).italic().foregroundStyle(.white)
                    HStack(spacing: 5) {
                        ForEach(["❤️ 4", "🔥 2", "😂 1", "+ react"], id: \.self) { r in
                            Text(r).font(.system(size: 10)).foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.white.opacity(r == "+ react" ? 0.05 : 0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(14)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom))
            }
        }
    }
}

struct PinchZoomDesign: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Rectangle().fill(
                LinearGradient(colors: [Color(white: 0.15), Color(white: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .scaleEffect(1.8)
            .ignoresSafeArea()
            Circle().fill(.white.opacity(0.25)).overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 2))
                .frame(width: 28, height: 28)
                .offset(x: -80, y: -60)
            Circle().fill(.white.opacity(0.25)).overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 2))
                .frame(width: 28, height: 28)
                .offset(x: 80, y: 60)
            Rectangle().fill(.white.opacity(0.3))
                .frame(width: 160, height: 1)
                .offset(y: 0)
            VStack {
                HStack {
                    Image(systemName: "xmark").font(.system(size: 14)).foregroundStyle(.white)
                    Spacer()
                    Text("1.8x").font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.gold)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                }
                .padding(14)
                Spacer()
                Text("double-tap to reset · pinch to zoom")
                    .font(.system(size: 11)).italic().foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 24)
            }
        }
    }
}
