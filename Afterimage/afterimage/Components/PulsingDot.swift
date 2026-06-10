import SwiftUI

/// Subtle perpetual pulse — used on the developing card's "DEVELOPING" status,
/// reveal-stage ripple anchors, and live-presence indicators. Uses an explicit
/// timingCurve (not easeInOut) for the breathing rhythm.
struct PulsingDot: View {
    var color: Color = Palette.red
    var size: CGFloat = 6
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: size * 2.2, height: size * 2.2)
                .scaleEffect(pulsing ? 1.0 : 0.6)
                .opacity(pulsing ? 0 : 0.7)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.9), radius: 4)
        }
        .frame(width: size * 2.2, height: size * 2.2)
        .onAppear {
            withAnimation(
                .timingCurve(0.4, 0, 0.6, 1, duration: 1.4)
                    .repeatForever(autoreverses: false)
            ) {
                pulsing = true
            }
        }
    }
}
