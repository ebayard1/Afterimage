import SwiftUI

/// Skeleton-style shimmer placeholder. Used as the default state for AsyncImage
/// loading inside album grids — never show a circular spinner per the audit rules.
struct ShimmerPlaceholder: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.04)) { _ in
            GeometryReader { geo in
                LinearGradient(
                    colors: [
                        Palette.surface,
                        Color(red: 0.13, green: 0.11, blue: 0.10),
                        Palette.surface
                    ],
                    startPoint: UnitPoint(x: phase, y: 0),
                    endPoint: UnitPoint(x: phase + 0.6, y: 0)
                )
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .onAppear { startShimmer() }
    }

    private func startShimmer() {
        withAnimation(
            .timingCurve(0.4, 0, 0.6, 1, duration: 1.4)
                .repeatForever(autoreverses: false)
        ) {
            phase = 1.6
        }
    }
}
