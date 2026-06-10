import SwiftUI

/// Sample-only animated waveform. Pure visual — no real audio plumbing yet.
/// Use isLive=true while recording (bars oscillate), isLive=false for playback
/// where bars highlight up to `progress` (0…1).
struct Waveform: View {
    let bars: Int
    var isLive: Bool = false
    var progress: Double = 1.0
    var color: Color = Palette.gold

    init(bars: Int = 28, isLive: Bool = false, progress: Double = 1.0, color: Color = Palette.gold) {
        self.bars = bars
        self.isLive = isLive
        self.progress = progress
        self.color = color
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isLive)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<bars, id: \.self) { i in
                    let phase = Double(i) * 0.42
                    let live = isLive ? (sin(t * 4.6 + phase) + sin(t * 2.7 + phase * 2)) / 2 : 0
                    let baseline = 0.3 + 0.7 * abs(sin(Double(i) * 0.91))  // deterministic baseline
                    let height = isLive
                        ? CGFloat(0.30 + 0.55 * (live * 0.5 + 0.5))
                        : CGFloat(baseline)
                    let onPart = Double(i) / Double(bars) <= progress
                    Capsule()
                        .fill(onPart ? color : color.opacity(0.25))
                        .frame(width: 3, height: 24 * height)
                }
            }
            .frame(height: 24)
        }
    }
}
