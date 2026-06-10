import SwiftUI

enum CoachMarkSurface {
    case feed, camera
}

struct CoachMarkOverlay: View {
    let surface: CoachMarkSurface
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            switch surface {
            case .feed: feedContent
            case .camera: cameraContent
            }
        }
        .transition(.opacity)
    }

    private var feedContent: some View {
        VStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("your developing albums")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                Text("tap an album to add shots while the window is open. only shown the first time you visit the feed.")
                    .font(.system(size: 10))
                    .foregroundStyle(.black.opacity(0.7))
            }
            .padding(12)
            .background(Palette.gold)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                Triangle().fill(Palette.gold)
                    .frame(width: 16, height: 10)
                    .offset(y: 26),
                alignment: .bottom
            )
            .padding(.horizontal, 16)
            .padding(.top, 80)
            Spacer()
            Text("tap anywhere to dismiss")
                .font(.system(size: 11)).italic()
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 100)
        }
    }

    private var cameraContent: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("tap to shoot")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                Text("you'll never see this photo again until reveal. add an optional caption above the shutter.")
                    .font(.system(size: 10))
                    .foregroundStyle(.black.opacity(0.7))
            }
            .padding(12)
            .background(Palette.gold)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)

            // Highlight ring around shutter area
            ZStack {
                Circle().stroke(Palette.gold, lineWidth: 3)
                    .frame(width: 100, height: 100)
            }
            .padding(.top, 30)
            .padding(.bottom, 100)

            Text("tap anywhere to dismiss")
                .font(.system(size: 11)).italic()
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 16)
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
