import SwiftUI

/// Tappable on the feed: shows every album member's avatar + name in one expanded list.
/// X button in the corner clears it.
struct AlbumMembersSheet: View {
    let album: Album
    @Environment(\.dismiss) private var dismiss
    @State private var presentedFriend: SampleData.SampleFriend?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        VStack(spacing: 6) {
                            ForEach(album.memberIds, id: \.self) { uid in
                                row(uid: uid)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("members")
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
            .sheet(item: $presentedFriend) { friend in
                OtherProfileView(friend: friend)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(album.name.uppercased())
                .font(.custom("Bebas Neue", size: 26)).tracking(3)
                .foregroundStyle(Palette.textPrimary)

            // Inline-avatar typography: "shot by" with avatar pills inline
            HStack(alignment: .center, spacing: 6) {
                Text("shot by")
                    .font(.custom("Times New Roman", size: 13)).italic()
                    .foregroundStyle(Palette.textTertiary)
                HStack(spacing: -6) {
                    ForEach(Array(album.memberIds.prefix(5).enumerated()), id: \.offset) { _, uid in
                        AlbumMemberAvatar(uid: uid, size: 22)
                            .overlay(Circle().stroke(Palette.background, lineWidth: 1.5))
                    }
                }
                Text("· \(album.memberIds.count) total")
                    .font(.custom("Times New Roman", size: 12)).italic()
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func row(uid: String) -> some View {
        let friend = SampleData.friend(forMemberId: uid)
        let isMe = uid == "me"
        let isCreator = uid == album.creatorId
        let body = HStack(spacing: 12) {
            avatar(for: uid, friend: friend)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayName(for: uid, friend: friend))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                    if isCreator {
                        Text("creator")
                            .font(.system(size: 8, weight: .medium)).tracking(1)
                            .foregroundStyle(Palette.gold)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Palette.gold.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    if isMe {
                        Text("you")
                            .font(.system(size: 8, weight: .medium)).tracking(1)
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Palette.surface)
                            .clipShape(Capsule())
                    }
                }
                if let friend {
                    Text(friend.username)
                        .font(.system(size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            Spacer()
            if friend != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(10)
        .background(Palette.surface)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
        .cornerRadius(6)

        if let friend {
            Button { presentedFriend = friend } label: { body }
                .buttonStyle(.plain)
        } else {
            body
        }
    }

    @ViewBuilder
    private func avatar(for uid: String, friend: SampleData.SampleFriend?) -> some View {
        ZStack {
            if let seed = friend?.photoSeed {
                AsyncImage(url: URL(string: "https://picsum.photos/seed/\(seed)/120/120")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Palette.surface
                    }
                }
            } else if uid == "me" {
                Circle().fill(Palette.gold.opacity(0.25))
                Image(systemName: "person.fill").foregroundStyle(Palette.gold).font(.system(size: 14))
            } else {
                Circle().fill(Palette.surface)
                Text(uid.prefix(1).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(Circle())
        .overlay(Circle().stroke(uid == album.creatorId ? Palette.gold : Palette.border,
                                 lineWidth: uid == album.creatorId ? 1.5 : 1))
    }

    private func displayName(for uid: String, friend: SampleData.SampleFriend?) -> String {
        if let friend { return friend.displayName }
        if uid == "me" { return "you" }
        return String(uid.prefix(8)) + "…"
    }
}
