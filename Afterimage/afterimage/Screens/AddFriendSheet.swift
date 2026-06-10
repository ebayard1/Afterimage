import SwiftUI

struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toast
    @State private var query = ""
    @State private var sentTo: Set<String> = []
    @FocusState private var searchFocused: Bool

    /// Sample "people you might know" — friends-of-friends in the network.
    private let suggested: [SampleData.SampleFriend] = [
        .init(username: "@parker", displayName: "Parker Adams", mutualAlbums: 0, mutualFriends: 4, photoSeed: "parker"),
        .init(username: "@quinn",  displayName: "Quinn Diaz",   mutualAlbums: 0, mutualFriends: 3, photoSeed: "quinn"),
        .init(username: "@rae",    displayName: "Rae Park",     mutualAlbums: 0, mutualFriends: 6, photoSeed: "rae"),
        .init(username: "@oliver", displayName: "Oliver Schmidt", mutualAlbums: 0, mutualFriends: 2, photoSeed: "oliver"),
        .init(username: "@iris",   displayName: "Iris Bell",    mutualAlbums: 0, mutualFriends: 5, photoSeed: "iris"),
    ]

    private var filtered: [SampleData.SampleFriend] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return suggested }
        return suggested.filter {
            $0.username.lowercased().contains(q) ||
            $0.displayName.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Search field
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(searchFocused ? Palette.gold : Palette.textTertiary)
                            TextField("", text: $query,
                                      prompt: Text("search by @username")
                                .foregroundStyle(Palette.textTertiary))
                                .focused($searchFocused)
                                .foregroundStyle(Palette.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(Palette.surface)
                        .overlay(
                            Capsule().stroke(
                                searchFocused ? Palette.gold : Palette.border,
                                lineWidth: searchFocused ? 1.5 : 1
                            )
                        )
                        .clipShape(Capsule())
                        .animation(Motion.tap, value: searchFocused)

                        SectionLabel(text: "PEOPLE YOU MAY KNOW")
                        VStack(spacing: 8) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, f in
                                ScrollFadeIn(delay: Double(idx) * 0.05, distance: 12) {
                                    row(f).pressEffect()
                                }
                            }
                        }

                        Divider().background(Palette.border).padding(.vertical, 6)

                        // Share my profile
                        Button {
                            toast.success("link copied — share to invite")
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(Palette.gold)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("share your afterimage")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Palette.textPrimary)
                                    Text("send a link to someone not on afterimage yet")
                                        .font(.system(size: 11)).italic()
                                        .foregroundStyle(Palette.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.textTertiary)
                            }
                            .padding(12)
                            .background(Palette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("add a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
        }
    }

    private func row(_ f: SampleData.SampleFriend) -> some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: "https://picsum.photos/seed/\(f.photoSeed)/120/120")) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: ShimmerPlaceholder()
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(Circle().stroke(Palette.border, lineWidth: 1))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(f.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text("\(f.username) · \(f.mutualFriends) mutual friend\(f.mutualFriends == 1 ? "" : "s")")
                    .font(.system(size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()

            let sent = sentTo.contains(f.username)
            Button {
                if !sent {
                    sentTo.insert(f.username)
                    toast.success("request sent to \(f.username)")
                }
            } label: {
                Text(sent ? "REQUESTED" : "+ ADD")
                    .font(.custom("Bebas Neue", size: 12)).tracking(2)
                    .foregroundStyle(sent ? Palette.textTertiary : .black)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(sent ? Palette.surface : Palette.gold)
                    .overlay(Capsule().stroke(sent ? Palette.border : .clear, lineWidth: 1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(sent)
        }
        .padding(10)
        .background(Palette.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.border, lineWidth: 1))
    }
}
