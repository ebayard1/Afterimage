import SwiftUI

// MARK: - BentoPhotoGrid
//
// Editorial magazine-spread layout for the in-album photo composition. Breaks
// the LLM-default symmetric 3×3 grid by rotating through three asymmetric row
// patterns:
//
//   Pattern A (7 photos): hero (full-width 16:9) + row of 3 equal
//   Pattern B (5 photos): big tile (2/3 width) + stacked pair (1/3 width) + row of 2
//   Pattern C (4 photos): row of 2 (equal, tall) + row of 2 (equal, short)
//
// Photos cycle through these patterns until the buffer is empty. The result
// reads as a curated spread, never a contact sheet — every "page" is composed
// differently.
//
// Each tile is wrapped in a Double-Bezel container (outer shell + inner core)
// and gets the album's film-stock grade, magnetic press physics, and a smooth
// 800ms blur-fade scroll entry animation.

struct BentoPhotoGrid: View {
    let shots: [Shot]
    let filmStock: FilmStock?
    var onTapShot: (Int) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 20) {
            ForEach(Array(rowGroups.enumerated()), id: \.offset) { groupIdx, group in
                ScrollFadeIn(delay: Double(groupIdx) * 0.08, distance: 22) {
                    composedRow(for: group, baseIndex: indexOffset(groupIdx: groupIdx))
                }
            }
        }
    }

    // MARK: Row composition

    /// Three asymmetric patterns that rotate. Each pattern consumes a different
    /// number of photos so the rhythm constantly changes.
    private enum Pattern {
        case heroPlusTrio       // 1 + 3 = 4 photos in 2 visual rows
        case featurePlusStacked // 1 (large) + 2 (stacked) + 2 = 5 photos in 2 visual rows
        case quartetSplit       // 2 + 2 = 4 photos in 2 visual rows
    }

    private struct PhotoGroup {
        let pattern: Pattern
        let shots: [Shot]
    }

    private var rowGroups: [PhotoGroup] {
        var out: [PhotoGroup] = []
        var i = 0
        let patterns: [Pattern] = [.heroPlusTrio, .featurePlusStacked, .quartetSplit]
        var p = 0
        while i < shots.count {
            let pattern = patterns[p % patterns.count]
            let needed: Int
            switch pattern {
            case .heroPlusTrio:       needed = 4
            case .featurePlusStacked: needed = 5
            case .quartetSplit:       needed = 4
            }
            let slice = Array(shots[i..<min(i + needed, shots.count)])
            out.append(PhotoGroup(pattern: pattern, shots: slice))
            i += slice.count
            p += 1
        }
        return out
    }

    private func indexOffset(groupIdx: Int) -> Int {
        rowGroups.prefix(groupIdx).reduce(0) { $0 + $1.shots.count }
    }

    @ViewBuilder
    private func composedRow(for group: PhotoGroup, baseIndex: Int) -> some View {
        switch group.pattern {
        case .heroPlusTrio:
            heroPlusTrio(shots: group.shots, baseIndex: baseIndex)
        case .featurePlusStacked:
            featurePlusStacked(shots: group.shots, baseIndex: baseIndex)
        case .quartetSplit:
            quartetSplit(shots: group.shots, baseIndex: baseIndex)
        }
    }

    // MARK: Pattern A — hero + trio
    //
    // One full-width 16:9 hero photo on top, then a row of three equal photos
    // beneath it. This is the "open the magazine to a full spread" beat.

    private func heroPlusTrio(shots: [Shot], baseIndex: Int) -> some View {
        VStack(spacing: 6) {
            if let hero = shots.first {
                tile(shot: hero, index: baseIndex, aspect: 16.0/9.0, isHero: true)
            }
            if shots.count > 1 {
                HStack(spacing: 6) {
                    ForEach(Array(shots.dropFirst().prefix(3).enumerated()), id: \.offset) { i, s in
                        tile(shot: s, index: baseIndex + 1 + i, aspect: 1, isHero: false)
                    }
                }
            }
        }
    }

    // MARK: Pattern B — feature + stacked + duo
    //
    // Big feature tile on the left (2/3 width, tall) with two stacked small
    // tiles on the right (1/3 width each), then beneath it a row of two equal
    // square tiles. Most "editorial magazine" of the three.

    private func featurePlusStacked(shots: [Shot], baseIndex: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                if let feature = shots.first {
                    tile(shot: feature, index: baseIndex, aspect: 0.85, isHero: true)
                        .frame(maxWidth: .infinity)
                        .layoutPriority(2)
                }
                VStack(spacing: 6) {
                    ForEach(Array(shots.dropFirst().prefix(2).enumerated()), id: \.offset) { i, s in
                        tile(shot: s, index: baseIndex + 1 + i, aspect: 1, isHero: false)
                    }
                }
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
            }
            if shots.count > 3 {
                HStack(spacing: 6) {
                    ForEach(Array(shots.dropFirst(3).prefix(2).enumerated()), id: \.offset) { i, s in
                        tile(shot: s, index: baseIndex + 3 + i, aspect: 1.3, isHero: false)
                    }
                }
            }
        }
    }

    // MARK: Pattern C — quartet split
    //
    // Two rows of two equal tiles, but the first row is portrait-aspect and
    // the second row is landscape-aspect. The aspect change is the surprise.

    private func quartetSplit(shots: [Shot], baseIndex: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Array(shots.prefix(2).enumerated()), id: \.offset) { i, s in
                    tile(shot: s, index: baseIndex + i, aspect: 0.85, isHero: false)
                }
            }
            if shots.count > 2 {
                HStack(spacing: 6) {
                    ForEach(Array(shots.dropFirst(2).prefix(2).enumerated()), id: \.offset) { i, s in
                        tile(shot: s, index: baseIndex + 2 + i, aspect: 1.55, isHero: false)
                    }
                }
            }
        }
    }

    // MARK: Tile — Double-Bezel + magnetic press + film-stock grade
    //
    // Outer shell is a thin gold-tinted hairline; inner core is a clipped photo
    // with the album's film stock grade applied. Hero tiles get a larger outer
    // radius (24pt) and the others get a smaller one (10pt) so the hierarchy
    // is visible at first glance.

    private func tile(shot: Shot, index: Int, aspect: CGFloat, isHero: Bool) -> some View {
        let outerRadius: CGFloat = isHero ? 18 : 10
        let innerRadius: CGFloat = outerRadius - 3
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            onTapShot(index)
        } label: {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: shot.photoURL)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .filmStockGrade(filmStock)
                    default:
                        ShimmerPlaceholder()
                    }
                }
                .aspectRatio(aspect, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
                // Inner highlight — subtle white inset at the top to simulate
                // a glass plate sitting in an aluminum tray.
                .overlay(
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )

                if shot.note?.isEmpty == false {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.gold)
                        .padding(5)
                        .background(.black.opacity(0.5))
                        .clipShape(Circle())
                        .padding(7)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .fill(Palette.surface.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .stroke(Palette.gold.opacity(isHero ? 0.30 : 0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pressEffect(scale: isHero ? 0.985 : 0.96, lift: isHero ? 0 : 1)
        .accessibilityLabel("Shot \(index + 1)\(shot.note?.isEmpty == false ? ", has caption" : "")")
    }
}
