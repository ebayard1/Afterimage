import SwiftUI

struct OtherProfileView: View {
    let friend: SampleData.SampleFriend
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toast
    @State private var isFollowing = false
    @State private var showBlockReport = false

    private var theirDispos: [Album] {
        // Pretend their public albums are a stable subset of the catalog.
        Array(SampleData.albums.shuffled().prefix(6))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        avatarRow
                        statsCard
                        SectionLabel(text: "PUBLIC DISPOS")
                        grid
                    }
                    .padding(16)
                }
            }
            .navigationTitle(friend.username)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(Palette.gold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Block / Report", role: .destructive) { showBlockReport = true }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showBlockReport) {
                BlockReportSheet(target: friend.username)
            }
        }
    }

    private var avatarRow: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: "https://picsum.photos/seed/\(friend.photoSeed)/200/200")) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: ShimmerPlaceholder()
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .overlay(Circle().stroke(Palette.darkRed, lineWidth: 2))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.displayName).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                Text("\(friend.mutualAlbums) mutual album\(friend.mutualAlbums == 1 ? "" : "s")")
                    .font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    isFollowing.toggle()
                    toast.show(isFollowing ? "following \(friend.username)" : "unfollowed")
                } label: {
                    Text(isFollowing ? "✓ following" : "+ follow")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isFollowing ? Palette.gold : .white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(isFollowing ? Color.clear : Palette.darkRed)
                        .overlay(Capsule().stroke(isFollowing ? Palette.gold : .clear, lineWidth: 1.5))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .pressEffect()
                Button {
                    toast.show("messaging coming soon")
                } label: {
                    Text("msg")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .pressEffect()
            }
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            stat("\(theirDispos.count)", "albums")
            divider
            stat("\(Int.random(in: 80...260))", "shots")
            divider
            stat("\(friend.mutualFriends + Int.random(in: 5...30))", "friends")
        }
        .padding(.vertical, 12)
        .background(Palette.surface)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
        .cornerRadius(6)
    }

    private var divider: some View {
        Rectangle().fill(Palette.border).frame(width: 1, height: 28)
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 18, weight: .bold)).foregroundStyle(Palette.textPrimary)
            Text(l).font(.system(size: 9)).foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
            ForEach(Array(theirDispos.enumerated()), id: \.element.id) { idx, album in
                ScrollFadeIn(delay: Double(idx) * 0.04, distance: 10) {
                    tile(album).pressEffect()
                }
            }
        }
    }

    private func tile(_ album: Album) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: URL(string: album.coverPhotoURL ?? "")) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: ShimmerPlaceholder()
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
            .accessibilityLabel("\(album.name) album cover")
            Text(album.name).font(.system(size: 9)).foregroundStyle(Palette.textSecondary).lineLimit(1)
        }
    }
}

struct BlockReportSheet: View {
    let target: String
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toast

    private let reasons: [(icon: String, label: String)] = [
        ("exclamationmark.triangle.fill", "spam or fake account"),
        ("hand.raised.fill", "harassment or bullying"),
        ("xmark.octagon.fill", "hate speech or symbols"),
        ("eye.slash.fill", "nudity or sexual content"),
        ("person.crop.circle.badge.exclamationmark.fill", "underage user"),
        ("ellipsis.bubble.fill", "something else"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 10) {
                    Text("why are you reporting \(target)?")
                        .font(.system(size: 13)).italic().foregroundStyle(Palette.textTertiary)
                    ForEach(Array(reasons.enumerated()), id: \.element.label) { idx, r in
                        ScrollFadeIn(delay: Double(idx) * 0.04, distance: 8) {
                            Button {
                                toast.success("report submitted")
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: r.icon).foregroundStyle(Palette.red).font(.system(size: 14))
                                    Text(r.label).font(.system(size: 13)).foregroundStyle(Palette.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Palette.textTertiary)
                                }
                                .padding(10)
                                .background(Palette.surface)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .pressEffect()
                            .accessibilityLabel("Report for \(r.label)")
                        }
                    }
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        toast.success("\(target) blocked")
                        dismiss()
                    } label: {
                        Text("BLOCK \(target.uppercased())")
                            .font(.system(size: 14, weight: .bold)).tracking(1)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Palette.red)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .pressEffect()
                    .accessibilityLabel("Block \(target)")
                    .accessibilityHint("Removes them from your network and prevents future contact")
                    Text("they won't be able to message you, join your albums, or see your profile")
                        .font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .navigationTitle("report \(target)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Palette.textTertiary)
                }
            }
        }
    }
}
