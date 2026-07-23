import SwiftUI

/// Tappable on the feed: shows every album member's avatar + name in one expanded list.
/// X button in the corner clears it.
struct AlbumMembersSheet: View {
    let album: Album
    @Environment(\.dismiss) private var dismiss
    @Environment(UserService.self) private var users
    @State private var presentedPerson: PersonRef?

    /// Resolve a member uid to a display reference (nil = you/unknown → no tap).
    private func person(for uid: String) -> PersonRef? {
        if uid == users.currentProfile?.id { return nil }
        return users.profile(for: uid)?.asPersonRef
    }

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
            .sheet(item: $presentedPerson) { person in
                OtherProfileView(person: person)
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
        let ref = person(for: uid)
        let isMe = uid == users.currentProfile?.id
        let isCreator = uid == album.creatorId
        let body = HStack(spacing: 12) {
            AlbumMemberAvatar(uid: uid, size: 38)
                .overlay(Circle().stroke(isCreator ? Palette.gold : Palette.border,
                                         lineWidth: isCreator ? 1.5 : 1))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayName(for: uid, ref: ref, isMe: isMe))
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
                if let ref {
                    Text(ref.handle)
                        .font(.system(size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            Spacer()
            if ref != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(10)
        .background(Palette.surface)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
        .cornerRadius(6)

        if let ref {
            Button { presentedPerson = ref } label: { body }
                .buttonStyle(.plain)
        } else {
            body
        }
    }

    private func displayName(for uid: String, ref: PersonRef?, isMe: Bool) -> String {
        if isMe { return "you" }
        if let ref { return ref.displayName }
        return String(uid.prefix(8)) + "…"
    }
}
