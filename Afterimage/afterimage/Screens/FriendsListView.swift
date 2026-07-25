import SwiftUI

// MARK: - FriendsListView (high-end-visual-design rebuild)
//
// Variance Engine roll:
//   Vibe:   Editorial Luxury
//   Layout: Asymmetrical Bento — REQUESTS lives in its own gold-glow plate
//           at top; YOUR NETWORK lives in a second Double-Bezel plate below.
//           No flat iOS list, no SectionLabel chrome.

struct FriendsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(UserService.self) private var users
    @State private var friendService = FriendService()
    @State private var presentedPerson: PersonRef?
    @State private var showAddFriend = false

    private struct Req: Identifiable {
        let id: String
        let handle: String
        let displayName: String
        let subtitle: String
        let onAccept: () -> Void
        let onDecline: () -> Void
    }

    /// Accepted friends as neutral refs.
    private var friends: [PersonRef] {
        let ids = users.currentProfile?.friendIds ?? []
        return ids.compactMap { users.profile(for: $0)?.asPersonRef }
    }

    /// Pending incoming requests as neutral rows.
    private var pending: [Req] {
        friendService.incoming.map { req in
            let p = users.profile(for: req.fromUid)
            return Req(id: req.id ?? UUID().uuidString,
                       handle: p?.handle ?? "@someone", displayName: p?.displayName ?? "Someone",
                       subtitle: "wants to connect",
                       onAccept: { Task { try? await friendService.accept(req) } },
                       onDecline: { Task { try? await friendService.decline(req) } })
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.background.ignoresSafeArea()

            // Continuity sunrise wash behind hero
            RadialGradient(
                colors: [Palette.gold.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 6,
                endRadius: 360
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                Color.clear.frame(height: 64)  // room for floating header
                VStack(alignment: .leading, spacing: 0) {
                    heroBlock
                        .padding(.horizontal, 22)
                        .padding(.bottom, 18)

                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        showAddFriend = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("ADD A FRIEND")
                                .font(.custom("Bebas Neue", size: 20)).tracking(3)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold)).opacity(0.7)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18).padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Palette.gold)
                        )
                        .warmShadow(radius: 12, y: 5, opacity: 0.4)
                    }
                    .buttonStyle(.plain)
                    .pressEffect()
                    .accessibilityLabel("Add a friend")
                    .padding(.horizontal, 22)
                    .padding(.bottom, 30)
                    if !pending.isEmpty {
                        requestsPlate
                            .padding(.horizontal, 18)
                            .padding(.bottom, 28)
                    }
                    networkPlate
                        .padding(.horizontal, 18)
                        .padding(.bottom, 32)
                    footerLine
                        .padding(.horizontal, 22)
                        .padding(.bottom, 36)
                }
            }
            .scrollIndicators(.hidden)

            VStack {
                floatingHeader
                Spacer()
            }
        }
        .task {
            if let uid = auth.uid {
                friendService.startListening(uid: uid)
            }
        }
        // Firestore listeners don't self-remove on dealloc.
        .onDisappear { friendService.stopListening() }
        .sheet(item: $presentedPerson) { person in
            OtherProfileView(person: person)
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet()
        }
    }

    // MARK: - Floating header (with add-friend button-in-button)

    private var floatingHeader: some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Palette.background.opacity(0.7))
                            .overlay(Circle().stroke(Palette.border.opacity(0.6), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .pressEffect(scale: 0.92, lift: 1)
            .accessibilityLabel("Back")

            Spacer()

            HStack(spacing: 6) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text("NETWORK")
                    .font(.custom("Bebas Neue", size: 12)).tracking(3)
                    .foregroundStyle(Palette.gold)
                Text("·  \(friends.count)")
                    .font(.custom("Menlo", size: 10)).tracking(1)
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()

            // Add friend — prominent labeled gold pill
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                showAddFriend = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("ADD")
                        .font(.custom("Bebas Neue", size: 15)).tracking(2)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(Palette.gold))
                .warmShadow(radius: 6, y: 2, opacity: 0.45)
            }
            .buttonStyle(.plain)
            .pressEffect(scale: 0.94, lift: 1)
            .accessibilityLabel("Add a friend")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            Capsule().fill(Palette.surface.opacity(0.75))
                .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 1))
                .warmShadow(radius: 18, y: 6, opacity: 0.35)
        )
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    // MARK: - Hero block

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text(eyebrowText)
                    .font(.custom("Menlo", size: 10)).tracking(3)
                    .foregroundStyle(Palette.gold)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                Capsule().fill(Palette.gold.opacity(0.10))
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1))
            )

            VStack(alignment: .leading, spacing: -2) {
                Text("THE PEOPLE")
                    .font(.custom("Bebas Neue", size: 50)).tracking(-1)
                    .foregroundStyle(Palette.textPrimary)
                Text("ON YOUR ROLLS.")
                    .font(.custom("Bebas Neue", size: 50)).tracking(-1)
                    .foregroundStyle(Palette.gold)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("who you shoot with. who's waiting. who's still in the queue.")
                .font(.custom("Times New Roman", size: 14)).italic()
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var eyebrowText: String {
        if pending.isEmpty {
            return "\(friends.count) IN YOUR NETWORK"
        }
        return "\(pending.count) WAITING · \(friends.count) IN YOUR NETWORK"
    }

    // MARK: - Requests plate — Double-Bezel with gold glow

    private var requestsPlate: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    ForEach(pending.prefix(3)) { r in
                        AvatarCircle(label: r.displayName, size: 24,
                                     bg: Palette.gold.opacity(0.18), fg: Palette.gold)
                            .overlay(Circle().stroke(Palette.gold.opacity(0.5), lineWidth: 1))
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("WAITING ON YOU")
                        .font(.custom("Bebas Neue", size: 13)).tracking(3)
                        .foregroundStyle(Palette.gold)
                    Text("\(pending.count) friend request\(pending.count == 1 ? "" : "s")")
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Rectangle().fill(Palette.gold.opacity(0.18)).frame(height: 1)

            VStack(spacing: 0) {
                ForEach(Array(pending.enumerated()), id: \.element.id) { idx, r in
                    ScrollFadeIn(delay: Double(idx) * 0.04, distance: 10) {
                        requestRow(r)
                    }
                    if idx < pending.count - 1 {
                        Rectangle().fill(Palette.border.opacity(0.5))
                            .frame(height: 1)
                            .padding(.horizontal, 14)
                    }
                }
            }
        }
        // Inner core (dark red glow)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(red: 0.10, green: 0.08, blue: 0))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                )
        )
        // Outer shell (gold)
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.background.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Palette.gold, lineWidth: 1)
                )
        )
        .warmShadow(radius: 12, y: 6, opacity: 0.4)
    }

    private func requestRow(_ r: Req) -> some View {
        HStack(spacing: 12) {
            AvatarCircle(label: r.displayName, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.handle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.gold)
                Text(r.subtitle)
                    .font(.custom("Times New Roman", size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(Motion.crisp) { r.onAccept() }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 28)
                    .background(Capsule().fill(Palette.success))
            }
            .buttonStyle(.plain)
            .pressEffect()
            .accessibilityLabel("Accept friend request from \(r.handle)")

            Button {
                withAnimation(Motion.crisp) { r.onDecline() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.textTertiary)
                    .frame(width: 30, height: 28)
                    .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .pressEffect()
            .accessibilityLabel("Decline friend request from \(r.handle)")
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // MARK: - Network plate — Double-Bezel container with all friends

    private var networkPlate: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Palette.textSecondary).frame(width: 5, height: 5)
                Text("YOUR NETWORK")
                    .font(.custom("Bebas Neue", size: 12)).tracking(3)
                    .foregroundStyle(Palette.textSecondary)
                Text("·  \(friends.count)")
                    .font(.custom("Menlo", size: 10)).tracking(1)
                    .foregroundStyle(Palette.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Rectangle().fill(Palette.border.opacity(0.5)).frame(height: 1)

            if friends.isEmpty {
                Text("no friends yet — add some above.")
                    .font(.custom("Times New Roman", size: 12)).italic()
                    .foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 22)
            }
            VStack(spacing: 0) {
                ForEach(Array(friends.enumerated()), id: \.element.id) { idx, f in
                    ScrollFadeIn(delay: Double(idx) * 0.04 + 0.05, distance: 10) {
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            presentedPerson = f
                        } label: {
                            friendRow(f)
                        }
                        .buttonStyle(.plain)
                        .pressEffect(scale: 0.985)
                        .accessibilityLabel("\(f.displayName), \(f.handle)")
                        .accessibilityHint("Opens \(f.displayName)'s profile")
                    }
                    if idx < friends.count - 1 {
                        Rectangle().fill(Palette.border.opacity(0.4))
                            .frame(height: 1)
                            .padding(.horizontal, 14)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                )
        )
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.background.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Palette.border.opacity(0.6), lineWidth: 1)
                )
        )
    }

    private func friendRow(_ f: PersonRef) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: friendAvatarURL(f)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    ShimmerPlaceholder()
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
                HStack(spacing: 6) {
                    Text(f.handle)
                        .font(.custom("Menlo", size: 10)).tracking(0.5)
                        .foregroundStyle(Palette.gold)
                    if let mutual = f.mutualAlbums {
                        Text("·").foregroundStyle(Palette.textTertiary)
                        Text("\(mutual) mutual roll\(mutual == 1 ? "" : "s")")
                            .font(.custom("Times New Roman", size: 10)).italic()
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }
            Spacer()
            ZStack {
                Circle().fill(Palette.background.opacity(0.6))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(width: 22, height: 22)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // MARK: - Footer

    private func friendAvatarURL(_ f: PersonRef) -> URL? {
        if let urlStr = f.photoURL, !urlStr.isEmpty { return URL(string: urlStr) }
        if let seed = f.photoSeed { return URL(string: "https://picsum.photos/seed/\(seed)/120/120") }
        return nil
    }

    private var footerLine: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Palette.border).frame(height: 1)
            Text("\(friends.count) FRIENDS · \(pending.count) WAITING")
                .font(.custom("Menlo", size: 9)).tracking(2.5)
                .foregroundStyle(Palette.textTertiary)
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }
}
