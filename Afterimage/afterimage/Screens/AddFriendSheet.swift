import SwiftUI

struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toast
    @Environment(AuthService.self) private var auth
    @Environment(UserService.self) private var users
    @State private var friendService = FriendService()
    @State private var query = ""
    @State private var sentTo: Set<String> = []
    @State private var searchResults: [UserProfile] = []
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    /// Live username search results.
    private var results: [PersonRef] {
        searchResults.map { $0.asPersonRef }
    }

    private var sectionTitle: String {
        query.isEmpty ? "SEARCH BY @USERNAME" : "RESULTS"
    }

    private func runSearch() {
        searchTask?.cancel()
        let q = query
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            let found = (try? await users.search(prefix: q, excluding: auth.uid)) ?? []
            if Task.isCancelled { return }
            await MainActor.run { searchResults = found }
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
                                .onChange(of: query) { _, _ in runSearch() }
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

                        SectionLabel(text: sectionTitle)
                        VStack(spacing: 8) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { idx, p in
                                ScrollFadeIn(delay: Double(idx) * 0.05, distance: 12) {
                                    row(p).pressEffect()
                                }
                            }
                            if !query.isEmpty && results.isEmpty {
                                Text("no one found for \u{201C}\(query)\u{201D}")
                                    .font(.custom("Times New Roman", size: 12)).italic()
                                    .foregroundStyle(Palette.textTertiary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 16)
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

    private func row(_ p: PersonRef) -> some View {
        HStack(spacing: 10) {
            AsyncImage(url: avatarURL(p)) { phase in
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
                Text(p.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(subtitle(for: p))
                    .font(.system(size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()

            let sent = sentTo.contains(p.id)
            Button { sendRequest(to: p, alreadySent: sent) } label: {
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

    private func avatarURL(_ p: PersonRef) -> URL? {
        if let urlStr = p.photoURL, !urlStr.isEmpty { return URL(string: urlStr) }
        if let seed = p.photoSeed { return URL(string: "https://picsum.photos/seed/\(seed)/120/120") }
        return nil
    }

    private func subtitle(for p: PersonRef) -> String {
        if let m = p.mutualFriends { return "\(p.handle) · \(m) mutual friend\(m == 1 ? "" : "s")" }
        return p.handle
    }

    private func sendRequest(to p: PersonRef, alreadySent: Bool) {
        guard !alreadySent else { return }
        sentTo.insert(p.id)
        guard let fromUid = auth.uid, let toUid = p.uid else { return }
        Task {
            do { try await friendService.sendRequest(from: fromUid, to: toUid)
                 toast.success("request sent to \(p.handle)") }
            catch { toast.error("couldn't send request") }
        }
    }
}
