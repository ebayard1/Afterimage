import SwiftUI

/// Skeleton-style shimmer placeholder. Used as the default state for AsyncImage
/// loading inside album grids — never show a circular spinner per the audit rules.
struct ShimmerPlaceholder: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        // The repeatForever animation on `phase` drives the sweep by itself —
        // the old 25 Hz TimelineView wrapper was pure redundant re-render (and
        // a cold feed can have a hundred of these on screen at once).
        LinearGradient(
            colors: [
                Palette.surface,
                Color(red: 0.13, green: 0.11, blue: 0.10),
                Palette.surface
            ],
            startPoint: UnitPoint(x: phase, y: 0),
            endPoint: UnitPoint(x: phase + 0.6, y: 0)
        )
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
