import SwiftUI

/// Card-stack flow: after a reveal, surface every shot the user was tagged in
/// and let them confirm / untag. Sample-only — operates on
/// `SampleData.youAppearInShots` and the FaceTag generator.
struct FaceTagConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toast
    @State private var index: Int = 0
    /// Result per shot id: nil = pending, true = confirmed, false = untagged.
    @State private var decisions: [String: Bool] = [:]

    private var entries: [(albumName: String, shot: Shot)] {
        SampleData.youAppearInShots
    }

    private var current: (albumName: String, shot: Shot)? {
        guard index >= 0, index < entries.count else { return nil }
        return entries[index]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                if let entry = current {
                    VStack(spacing: 18) {
                        progressLine
                        cardStack(current: entry)
                        actionButtons
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                } else {
                    doneState
                }
            }
            .navigationTitle("tag review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.gold)
                }
            }
        }
    }

    private var progressLine: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Array(entries.enumerated()), id: \.offset) { idx, _ in
                    Capsule()
                        .fill(idx <= index ? Palette.gold : Palette.border)
                        .frame(height: 3)
                }
            }
            Text("\(index + 1) of \(entries.count) · you appear in")
                .font(.custom("Menlo", size: 10)).tracking(1.5)
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.top, 6)
    }

    private func cardStack(current entry: (albumName: String, shot: Shot)) -> some View {
        VStack(spacing: 12) {
            ZStack {
                AsyncImage(url: URL(string: entry.shot.photoURL)) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: ShimmerPlaceholder()
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipped()
                .overlay(Rectangle().stroke(Palette.gold, lineWidth: 2))

                // Highlight face boxes
                GeometryReader { geo in
                    let imgFrame = aspectFitFrame(of: geo.size, imageAspect: 3 / 4)
                    if let shotId = entry.shot.id {
                        ForEach(SampleData.faceTags(forShotId: shotId)) { tag in
                            let x = imgFrame.minX + tag.x * imgFrame.width
                            let y = imgFrame.minY + tag.y * imgFrame.height
                            let w = tag.width * imgFrame.width
                            let h = tag.height * imgFrame.height
                            Rectangle()
                                .stroke(Palette.gold, lineWidth: 1.5)
                                .frame(width: w, height: h)
                                .position(x: x + w / 2, y: y + h / 2)
                                .overlay(
                                    Text(tag.username)
                                        .font(.custom("Menlo", size: 9)).tracking(0.5)
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Palette.gold)
                                        .position(x: x + w / 2, y: y + h + 14)
                                )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.albumName.uppercased())
                    .font(.custom("Bebas Neue", size: 16)).tracking(2)
                    .foregroundStyle(Palette.textPrimary)
                if let note = entry.shot.note, !note.isEmpty {
                    Text("\u{201C}\(note)\u{201D}")
                        .font(.custom("Times New Roman", size: 13)).italic()
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.rectangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.gold)
                    Text("we think you're in this shot")
                        .font(.system(size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                if let id = current?.shot.id { decisions[id] = false }
                toast.show("untagged")
                advance()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                    Text("UNTAG ME")
                        .font(.custom("Bebas Neue", size: 14)).tracking(3)
                }
                .foregroundStyle(Palette.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .overlay(Capsule().stroke(Palette.red, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .pressEffect()

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                if let id = current?.shot.id { decisions[id] = true }
                advance()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                    Text("THAT'S ME")
                        .font(.custom("Bebas Neue", size: 14)).tracking(3)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Palette.gold)
                .clipShape(Capsule())
                .warmShadow(radius: 8, y: 4, opacity: 0.4)
            }
            .buttonStyle(.plain)
            .pressEffect(scale: 0.96, lift: 1)
        }
    }

    private var doneState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Palette.gold)
            Text("ALL CAUGHT UP")
                .font(.custom("Bebas Neue", size: 22)).tracking(4)
                .foregroundStyle(Palette.gold)
            let confirmed = decisions.values.filter { $0 }.count
            let untagged = decisions.values.filter { !$0 }.count
            VStack(spacing: 4) {
                Text("\(confirmed) confirmed · \(untagged) untagged")
                    .font(.custom("Menlo", size: 11)).tracking(1.5)
                    .foregroundStyle(Palette.textSecondary)
            }
            Button { dismiss() } label: {
                Text("close")
                    .font(.custom("Bebas Neue", size: 14)).tracking(3)
                    .foregroundStyle(Palette.gold)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .overlay(Capsule().stroke(Palette.gold, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .pressEffect()
            .padding(.top, 10)
        }
        .padding(28)
    }

    private func advance() {
        withAnimation(Motion.cinematic) {
            if index < entries.count - 1 {
                index += 1
            } else {
                index = entries.count  // moves into doneState
            }
        }
    }

    private func aspectFitFrame(of size: CGSize, imageAspect: CGFloat) -> CGRect {
        let containerAspect = size.width / size.height
        if containerAspect > imageAspect {
            let w = size.height * imageAspect
            return CGRect(x: (size.width - w) / 2, y: 0, width: w, height: size.height)
        } else {
            let h = size.width / imageAspect
            return CGRect(x: 0, y: (size.height - h) / 2, width: size.width, height: h)
        }
    }
}
