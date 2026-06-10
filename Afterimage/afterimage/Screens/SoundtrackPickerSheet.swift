import SwiftUI

/// Picker for the song attached to a roll. Plays under the reveal cinematic
/// and the Year-In-Rolls recap. Sample-only — no actual audio yet.
struct SoundtrackPickerSheet: View {
    @Binding var selection: Soundtrack?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [Soundtrack] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Soundtrack.catalog }
        return Soundtrack.catalog.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    ScrollView {
                        VStack(spacing: 6) {
                            if selection != nil {
                                clearRow
                            }
                            ForEach(filtered) { track in
                                row(track)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                }
            }
            .navigationTitle("attach a song")
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

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(searchFocused ? Palette.gold : Palette.textTertiary)
            TextField("", text: $query,
                      prompt: Text("search songs or artists")
                .foregroundStyle(Palette.textTertiary))
                .focused($searchFocused)
                .foregroundStyle(Palette.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Palette.surface)
        .overlay(Capsule().stroke(
            searchFocused ? Palette.gold : Palette.border,
            lineWidth: searchFocused ? 1.5 : 1
        ))
        .clipShape(Capsule())
        .animation(Motion.tap, value: searchFocused)
    }

    private var clearRow: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            selection = nil
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Palette.darkRed)
                Text("no soundtrack")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
            }
            .padding(10)
            .background(Palette.surface.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pressEffect()
    }

    private func row(_ track: Soundtrack) -> some View {
        let selected = selection == track
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            selection = track
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    LinearGradient(
                        colors: [Palette.gold.opacity(0.35), Palette.darkRed.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.gold)
                }
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(track.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textTertiary)
                            .lineLimit(1)
                        Text("·")
                            .foregroundStyle(Palette.textTertiary)
                        Text(track.formattedDuration)
                            .font(.custom("Menlo", size: 10))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.gold)
                }
            }
            .padding(8)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                selected ? Palette.gold : Palette.border,
                lineWidth: selected ? 1.5 : 1
            ))
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel("\(track.title) by \(track.artist)")
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}
