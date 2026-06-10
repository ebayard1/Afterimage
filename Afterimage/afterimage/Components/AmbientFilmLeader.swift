import SwiftUI

/// A perpetually-moving horizontal strip of 35mm sprocket holes — like a
/// projector warming up at the top of the auth screen. Pure ambient motion,
/// never interactive.
///
/// Driven by TimelineView so the motion runs without state updates and never
/// stutters when the rest of the view re-renders.
struct AmbientFilmLeader: View {
    /// Tunable cycle period in seconds — one full sprocket-hole cycle.
    var period: Double = 1.8
    var height: CGFloat = 22

    private let holeWidth: CGFloat = 9
    private let holeSpacing: CGFloat = 5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: period)) / period   // 0…1
            GeometryReader { geo in
                let pitch = holeWidth + holeSpacing
                let count = Int(geo.size.width / pitch) + 2
                let offset = -CGFloat(phase) * pitch
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(white: 0.05))
                    HStack(spacing: holeSpacing) {
                        ForEach(0..<count, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Palette.background)
                                .frame(width: holeWidth, height: height * 0.45)
                        }
                    }
                    .offset(x: offset)
                    // Faint gold edge that catches the leader strip's identity.
                    Rectangle()
                        .fill(Palette.gold.opacity(0.35))
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
