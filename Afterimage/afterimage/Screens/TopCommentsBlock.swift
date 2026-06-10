import SwiftUI

/// Collapsible "TOP COMMENTS" panel that sits inline beneath each developed roll
/// on the Rolls tab. Shows threaded replies, heart-likes, and an inline composer.
struct TopCommentsBlock: View {
    let album: Album
    @Binding var isExpanded: Bool

    @Environment(AuthService.self) private var auth
    @Environment(ToastCenter.self) private var toast
    @State private var service = CommentService()
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    private var topLevel: [Comment] {
        service.comments.filter { $0.parentId == nil }
    }
    private func replies(to id: String) -> [Comment] {
        service.comments.filter { $0.parentId == id }
    }
    /// Two most-recent top-level comments, always visible as a preview.
    private var previewComments: [Comment] { Array(topLevel.prefix(2)) }
    /// Comments beyond the preview — only shown when expanded.
    private var remainingTopLevel: [Comment] { Array(topLevel.dropFirst(2)) }
    private var hasMore: Bool {
        service.comments.count > previewComments.count
    }

    /// Wraps a comment row in an erased view so we can index + stagger animations.
    private struct ExpandedRow: Identifiable {
        let id: String
        let view: AnyView
    }
    private var expandedRows: [ExpandedRow] {
        var out: [ExpandedRow] = []
        for c in previewComments {
            for reply in replies(to: c.id ?? "") {
                out.append(.init(
                    id: reply.id ?? UUID().uuidString,
                    view: AnyView(CommentBlockRow(comment: reply, indented: true, onLike: like))
                ))
            }
        }
        for c in remainingTopLevel {
            out.append(.init(
                id: c.id ?? UUID().uuidString,
                view: AnyView(CommentBlockRow(comment: c, indented: false, onLike: like))
            ))
            for reply in replies(to: c.id ?? "") {
                out.append(.init(
                    id: reply.id ?? UUID().uuidString,
                    view: AnyView(CommentBlockRow(comment: reply, indented: true, onLike: like))
                ))
            }
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            // Always-visible preview of the first two comments.
            if !previewComments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(previewComments) { c in
                        CommentBlockRow(comment: c, indented: false, onLike: like)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)
            }

            // "View all" link when there's more
            if !isExpanded && hasMore {
                Button {
                    withAnimation(Motion.expressive) { isExpanded = true }
                } label: {
                    Text("view all \(service.comments.count) comments")
                        .font(.system(size: 12)).italic()
                        .foregroundStyle(Palette.textTertiary)
                        .padding(.vertical, 8)
                        .padding(.leading, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            // Expanded: the rest of the thread + composer, staggered in
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(expandedRows.enumerated()), id: \.offset) { idx, row in
                        row.view
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)).animation(Motion.staggered(idx)),
                                removal: .opacity
                            ))
                    }
                    composer
                        .transition(.opacity.animation(Motion.staggered(expandedRows.count)))
                }
                .padding(.horizontal, 4)
                .padding(.top, 10)
            }
        }
        .task {
            if let id = album.id { service.startListening(albumId: id) }
        }
    }

    private var headerBar: some View {
        Button {
            withAnimation(Motion.expressive) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Text("TOP COMMENTS")
                    .font(.custom("Bebas Neue", size: 13)).tracking(3)
                    .foregroundStyle(Palette.textSecondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.textTertiary)
                    Text("\(service.comments.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Palette.gold)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            HStack {
                TextField("",
                          text: $draft,
                          prompt: Text("Add a comment…")
                            .foregroundStyle(Palette.textTertiary))
                    .focused($composerFocused)
                    .foregroundStyle(Palette.textPrimary)
                Image(systemName: "face.smiling")
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Palette.surface)
            .overlay(
                Capsule().stroke(
                    composerFocused ? Palette.gold : Palette.border,
                    lineWidth: composerFocused ? 1.5 : 1
                )
            )
            .clipShape(Capsule())
            .animation(Motion.tap, value: composerFocused)

            Button {
                submit()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(canPost ? .black : Palette.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(canPost ? Palette.gold : Palette.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .pressEffect()
            .disabled(!canPost)
        }
        .padding(.top, 4)
    }

    private var canPost: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canPost, let albumId = album.id else { return }
        let username: String = {
            if let email = auth.email, let p = email.split(separator: "@").first {
                return "@\(p)"
            }
            return "@you"
        }()
        let text = draft
        draft = ""
        composerFocused = false
        Task {
            try? await service.post(
                text: text, referencedShotId: nil, parentId: nil,
                albumId: albumId, userId: auth.uid ?? "me", username: username
            )
        }
    }

    private func like(_ c: Comment) {
        guard let albumId = album.id, let cid = c.id else { return }
        Task {
            try? await service.toggleLike(
                commentId: cid, albumId: albumId, userId: auth.uid ?? "me"
            )
        }
    }
}

// MARK: - One comment row in the block (top-level or threaded reply)

private struct CommentBlockRow: View {
    let comment: Comment
    let indented: Bool
    let onLike: (Comment) -> Void

    @Environment(AuthService.self) private var auth

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if indented {
                Color.clear.frame(width: 24)
            }
            avatar
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(comment.username.replacingOccurrences(of: "@", with: ""))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(relativeTime)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textTertiary)
                }
                MentionText(raw: comment.text, size: 13, color: Palette.textPrimary)
            }
            Spacer(minLength: 8)
            Button { onLike(comment) } label: {
                HStack(spacing: 4) {
                    Image(systemName: didLike ? "heart.fill" : "heart")
                        .font(.system(size: 13))
                        .foregroundStyle(didLike ? Palette.red : Palette.textTertiary)
                    if comment.likeCount > 0 {
                        Text("\(comment.likeCount)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .frame(minWidth: 28, alignment: .trailing)
            }
            .buttonStyle(.plain)
        }
    }

    private var didLike: Bool {
        comment.didLike(auth.uid ?? "me")
    }

    @ViewBuilder
    private var avatar: some View {
        let seed = SampleData.friend(byUsername: comment.username)?.photoSeed
        ZStack {
            if let seed {
                AsyncImage(url: URL(string: "https://picsum.photos/seed/\(seed)/120/120")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Palette.surface
                    }
                }
            } else if comment.userId == "me" {
                Circle().fill(Palette.gold.opacity(0.25))
                Image(systemName: "person.fill").foregroundStyle(Palette.gold).font(.system(size: 12))
            } else {
                Circle().fill(Palette.surface)
                Text(comment.username.dropFirst().prefix(1).uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
    }

    private var relativeTime: String {
        let s = -comment.createdAt.timeIntervalSinceNow
        if s < 60        { return "\(Int(s))s" }
        if s < 3600      { return "\(Int(s / 60))m" }
        if s < 86400     { return "\(Int(s / 3600))h" }
        return "\(Int(s / 86400))d"
    }
}
