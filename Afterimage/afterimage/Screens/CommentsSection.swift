import SwiftUI

struct CommentsSection: View {
    let album: Album
    let shots: [Shot]
    var highlightShotId: String? = nil
    let onJumpToShot: (Int) -> Void

    @Environment(AuthService.self) private var auth
    @Environment(UserService.self) private var users
    @Environment(ToastCenter.self) private var toast
    @State private var service = CommentService()
    @State private var draft: String = ""
    @State private var draftRefShotId: String? = nil
    @State private var showTagPicker: Bool = false
    @FocusState private var composerFocused: Bool

    /// A user is a "contributor" if they have at least one shot in this album.
    private var contributorIds: Set<String> {
        Set(shots.map { $0.userId })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header — scrapbook margin label
            HStack(alignment: .center, spacing: 8) {
                Rectangle().fill(Palette.border).frame(height: 1)
                Text("MARGIN NOTES")
                    .font(.custom("Bebas Neue", size: 12)).tracking(4)
                    .foregroundStyle(Palette.textSecondary)
                Text("\(service.comments.count)")
                    .font(.custom("Menlo", size: 10))
                    .foregroundStyle(Palette.textTertiary)
                Rectangle().fill(Palette.border).frame(height: 1)
            }
            .padding(.horizontal, 14).padding(.top, 20).padding(.bottom, 8)
            Text("one thread for the whole roll. tag any frame.")
                .font(.custom("Times New Roman", size: 11)).italic()
                .foregroundStyle(Palette.textTertiary)
                .padding(.horizontal, 14).padding(.bottom, 6)

            if service.comments.isEmpty {
                Text("no comments yet — start the thread.")
                    .font(.system(size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(service.comments) { c in
                        CommentRow(
                            comment: c,
                            isContributor: contributorIds.contains(c.userId),
                            referencedShotIndex: shotIndex(for: c.referencedShotId),
                            isHighlighted: highlightShotId != nil && c.referencedShotId == highlightShotId,
                            onTapReference: { idx in onJumpToShot(idx) }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .task {
            if let id = album.id { service.startListening(albumId: id) }
        }
        // Firestore listeners don't self-remove on dealloc.
        .onDisappear { service.stopListening() }
        .safeAreaInset(edge: .bottom) { composer }
        .sheet(isPresented: $showTagPicker) {
            TagShotPicker(
                shots: shots,
                currentlyTaggedShotId: draftRefShotId,
                onPicked: { shotId in
                    draftRefShotId = shotId
                    showTagPicker = false
                }
            )
        }
    }

    private func shotIndex(for shotId: String?) -> Int? {
        guard let id = shotId else { return nil }
        return shots.firstIndex(where: { $0.id == id })
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.border).frame(height: 1)
            if let refShotId = draftRefShotId, let idx = shotIndex(for: refShotId) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.fill").font(.system(size: 10)).foregroundStyle(Palette.gold)
                    Text("tagging shot \(idx + 1) of \(shots.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.gold)
                    Spacer()
                    Button { draftRefShotId = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Palette.gold.opacity(0.08))
            }
            HStack(spacing: 8) {
                Button { showTagPicker = true } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 16))
                        .foregroundStyle(draftRefShotId == nil ? Palette.textSecondary : Palette.gold)
                        .frame(width: 32, height: 32)
                        .background(Palette.surface)
                        .overlay(Circle().stroke(Palette.border, lineWidth: 1))
                        .clipShape(Circle())
                }
                TextField("", text: $draft, prompt: Text("add a comment…").foregroundStyle(Palette.textTertiary))
                    .focused($composerFocused)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .submitLabel(.send)
                    .onSubmit { submit() }
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(canPost ? Palette.gold : Palette.textTertiary)
                }
                .disabled(!canPost)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Palette.background)
        }
    }

    private var canPost: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canPost, let albumId = album.id else { return }
        // Always post under your real saved profile handle — never the login
        // email's local-part (that's what was surfacing the wrong name).
        let myUsername = users.currentProfile?.handle ?? "@you"
        let text = draft
        let ref = draftRefShotId
        draft = ""
        draftRefShotId = nil
        composerFocused = false
        Task {
            do {
                try await service.post(
                    text: text,
                    referencedShotId: ref,
                    albumId: albumId,
                    userId: auth.uid ?? "me",
                    username: myUsername
                )
                // The `onCommentCreated` Cloud Function fans this out to everyone
                // in the roll (activity feed + push).
                toast.show("comment sent to everyone in \(album.name)")
            } catch {
                toast.error("couldn't post")
            }
        }
    }
}

// MARK: - Comment row

private struct CommentRow: View {
    let comment: Comment
    let isContributor: Bool
    let referencedShotIndex: Int?
    var isHighlighted: Bool = false
    let onTapReference: (Int) -> Void

    @Environment(AuthService.self) private var auth
    @Environment(UserService.self) private var users

    var body: some View {
        let body = HStack(alignment: .top, spacing: 12) {
            // Margin rule — gold for contributors, faded ink for everyone else.
            Rectangle()
                .fill(isHighlighted ? Palette.gold
                      : isContributor ? Palette.goldDeep.opacity(0.7)
                      : Palette.border)
                .frame(width: 1.5)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    avatar
                    Text(comment.username)
                        .font(.custom("Bebas Neue", size: 13)).tracking(2)
                        .foregroundStyle(isContributor ? Palette.gold : Palette.textPrimary)
                    if isContributor {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.gold.opacity(0.8))
                    }
                    Spacer()
                    Text(relativeTime.uppercased())
                        .font(.custom("Menlo", size: 9)).tracking(1)
                        .foregroundStyle(Palette.textTertiary)
                }
                // Body in serif italic — diary-like, with @mentions highlighted
                MentionText(raw: comment.text, size: 15, color: Palette.textPrimary)
                    .italic()
                if let idx = referencedShotIndex {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.right").font(.system(size: 9))
                        Text("re: shot \(String(format: "%02d", idx + 1))")
                            .font(.custom("Menlo", size: 10)).tracking(0.5)
                    }
                    .foregroundStyle(Palette.gold)
                    .padding(.top, 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isHighlighted ? Palette.gold.opacity(0.06) : Color.clear)

        if let idx = referencedShotIndex {
            Button { onTapReference(idx) } label: { body }
                .buttonStyle(.plain)
        } else {
            body
        }
    }

    @ViewBuilder
    private var avatar: some View {
        let profile = users.profile(for: comment.userId)
        ZStack {
            if let urlStr = profile?.photoURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Palette.surface
                    }
                }
            } else if comment.userId == auth.uid {
                Circle().fill(Palette.gold.opacity(0.25))
                Image(systemName: "person.fill").foregroundStyle(Palette.gold).font(.system(size: 11))
            } else {
                Circle().fill(Palette.surface)
                Text(comment.username.dropFirst().prefix(1).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(Circle())
        .overlay(Circle().stroke(isContributor ? Palette.gold : Palette.border, lineWidth: isContributor ? 1.5 : 1))
    }

    private var relativeTime: String {
        let secs = -comment.createdAt.timeIntervalSinceNow
        if secs < 60        { return "just now" }
        if secs < 3600      { return "\(Int(secs / 60))m" }
        if secs < 86400     { return "\(Int(secs / 3600))h" }
        if secs < 604800    { return "\(Int(secs / 86400))d" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: comment.createdAt)
    }
}

// MARK: - Tag-a-shot picker

private struct TagShotPicker: View {
    let shots: [Shot]
    let currentlyTaggedShotId: String?
    let onPicked: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4)
                    ], spacing: 4) {
                        ForEach(Array(shots.enumerated()), id: \.element.id) { idx, shot in
                            Button {
                                onPicked(shot.id)
                            } label: {
                                ZStack(alignment: .topLeading) {
                                    AsyncImage(url: URL(string: shot.photoURL)) { phase in
                                        switch phase {
                                        case .success(let img): img.resizable().scaledToFill()
                                        default: Palette.surface
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                                    Text(String(format: "%02d", idx + 1))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 4).padding(.vertical, 1)
                                        .background(Palette.gold)
                                    if shot.id == currentlyTaggedShotId {
                                        Rectangle().stroke(Palette.gold, lineWidth: 3)
                                    }
                                }
                            }
                        }
                    }
                    .padding(4)
                }
            }
            .navigationTitle("tag a shot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Palette.textTertiary)
                }
                if currentlyTaggedShotId != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") { onPicked(nil); dismiss() }.foregroundStyle(Palette.red)
                    }
                }
            }
        }
    }
}
