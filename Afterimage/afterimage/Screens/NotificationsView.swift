import SwiftUI

// MARK: - NotificationsView (high-end-visual-design rebuild)
//
// Variance Engine roll:
//   Vibe:   Editorial Luxury
//   Layout: Asymmetrical Bento — requests live in their own gold-glow plate
//           up top, then notifications flow into a single Double-Bezel "INBOX"
//           plate so the screen reads as two distinct artifacts instead of an
//           iOS-default flat list.
//
// Replaces the centered nav title + Divider-separated list with a hero block,
// dual nested plates, and a Menlo ledger footer.

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pendingRequests = SampleData.friendRequests
    @State private var showFriendsList = false
    @State private var showInviteDeepLink = false

    var body: some View {
        ZStack(alignment: .top) {
            Palette.background.ignoresSafeArea()

            // Warm sunrise wash behind the hero (same continuity as the rest
            // of the app)
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
                        .padding(.bottom, 32)
                    if !pendingRequests.isEmpty {
                        requestsPlate
                            .padding(.horizontal, 18)
                            .padding(.bottom, 28)
                    }
                    inboxPlate
                        .padding(.horizontal, 18)
                        .padding(.bottom, 28)
                    caughtUpFooter
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
        .sheet(isPresented: $showFriendsList) {
            FriendsListView()
        }
        .fullScreenCover(isPresented: $showInviteDeepLink) {
            InviteDeepLinkView(
                fromUsername: "@leo",
                albumName: "Camping",
                durationLabel: "2 days",
                shots: 24,
                members: ["L", "M", "K", "B", "N"]
            )
        }
    }

    // MARK: - Floating header

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
                Text("INBOX")
                    .font(.custom("Bebas Neue", size: 12)).tracking(3)
                    .foregroundStyle(Palette.gold)
                Text("·  \(totalCount) waiting")
                    .font(.custom("Times New Roman", size: 11)).italic()
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            // Visual balance with the back button — invisible spacer the same size
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            Capsule().fill(Palette.surface.opacity(0.75))
                .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 6)
        )
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    private var totalCount: Int {
        pendingRequests.count + SampleData.notifications.count
    }

    // MARK: - Hero block

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text("SINCE YOU LAST LOOKED")
                    .font(.custom("Menlo", size: 10)).tracking(3)
                    .foregroundStyle(Palette.gold)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                Capsule().fill(Palette.gold.opacity(0.10))
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1))
            )

            VStack(alignment: .leading, spacing: -2) {
                Text("WHAT YOU")
                    .font(.custom("Bebas Neue", size: 52)).tracking(-1)
                    .foregroundStyle(Palette.textPrimary)
                Text("MISSED.")
                    .font(.custom("Bebas Neue", size: 52)).tracking(-1)
                    .foregroundStyle(Palette.gold)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(taglineText)
                .font(.custom("Times New Roman", size: 14)).italic()
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var taglineText: String {
        let req = pendingRequests.count
        let n = SampleData.notifications.count
        if req == 0 && n == 0 { return "the inbox is empty." }
        if req == 0 { return "\(n) updates from your network." }
        if n == 0 { return "\(req) friend request\(req == 1 ? "" : "s") waiting." }
        return "\(req) request\(req == 1 ? "" : "s") and \(n) updates from your network."
    }

    // MARK: - Requests plate — Double-Bezel with gold glow

    private var requestsPlate: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Plate header
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    ForEach(pendingRequests.prefix(3)) { r in
                        AvatarCircle(label: r.displayName, size: 24,
                                     bg: Palette.gold.opacity(0.18), fg: Palette.gold)
                            .overlay(Circle().stroke(Palette.gold.opacity(0.5), lineWidth: 1))
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("FRIEND REQUESTS")
                        .font(.custom("Bebas Neue", size: 13)).tracking(3)
                        .foregroundStyle(Palette.gold)
                    Text("\(pendingRequests.count) waiting on you")
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                Button { showFriendsList = true } label: {
                    HStack(spacing: 4) {
                        Text("SEE ALL")
                            .font(.custom("Bebas Neue", size: 10)).tracking(2)
                        Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Palette.gold)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .pressEffect()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            // Inner hairline divider
            Rectangle().fill(Palette.gold.opacity(0.18)).frame(height: 1)

            // Request rows
            VStack(spacing: 0) {
                ForEach(Array(pendingRequests.enumerated()), id: \.element.id) { idx, r in
                    requestRow(r)
                    if idx < pendingRequests.count - 1 {
                        Rectangle().fill(Palette.border.opacity(0.5))
                            .frame(height: 1)
                            .padding(.horizontal, 14)
                    }
                }
            }
        }
        // Inner core
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(red: 0.10, green: 0.08, blue: 0))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                )
        )
        // Outer shell
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

    private func requestRow(_ r: SampleData.FriendRequest) -> some View {
        HStack(spacing: 12) {
            AvatarCircle(label: r.displayName, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.username)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.gold)
                Text(r.mutualNote)
                    .font(.custom("Times New Roman", size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            // Accept (gold pill — primary)
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(Motion.crisp) {
                    pendingRequests.removeAll { $0.id == r.id }
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 28)
                    .background(Capsule().fill(Palette.success))
            }
            .buttonStyle(.plain)
            .pressEffect()
            .accessibilityLabel("Accept request from \(r.username)")

            // Decline (ghost capsule — secondary)
            Button {
                withAnimation(Motion.crisp) {
                    pendingRequests.removeAll { $0.id == r.id }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.textTertiary)
                    .frame(width: 30, height: 28)
                    .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .pressEffect()
            .accessibilityLabel("Decline request from \(r.username)")
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - Inbox plate — Double-Bezel container for notification rows

    private var inboxPlate: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Palette.textSecondary.opacity(0.7))
                    .frame(width: 5, height: 5)
                Text("UPDATES")
                    .font(.custom("Bebas Neue", size: 12)).tracking(3)
                    .foregroundStyle(Palette.textSecondary)
                Text("·  \(SampleData.notifications.count)")
                    .font(.custom("Menlo", size: 10)).tracking(1)
                    .foregroundStyle(Palette.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Rectangle().fill(Palette.border.opacity(0.5)).frame(height: 1)

            VStack(spacing: 0) {
                ForEach(Array(SampleData.notifications.enumerated()), id: \.element.id) { idx, n in
                    ScrollFadeIn(delay: Double(idx) * 0.04, distance: 10) {
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            if n.kind == .invite { showInviteDeepLink = true }
                        } label: {
                            notificationRow(n)
                        }
                        .buttonStyle(.plain)
                        .pressEffect(scale: 0.985)
                        .accessibilityLabel("\(n.title). \(n.subtitle)")
                    }
                    if idx < SampleData.notifications.count - 1 {
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

    private func notificationRow(_ n: SampleData.AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(accent(for: n.kind).opacity(0.15))
                Image(systemName: n.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(accent(for: n.kind))
            }
            .frame(width: 32, height: 32)
            .overlay(Circle().stroke(accent(for: n.kind).opacity(0.45), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(n.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(n.kind == .revealReady ? Palette.gold : Palette.textPrimary)
                Text(n.subtitle)
                    .font(.custom("Times New Roman", size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer(minLength: 8)
            Text(n.timeAgo)
                .font(.custom("Menlo", size: 9)).tracking(0.5)
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func accent(for kind: SampleData.NotificationKind) -> Color {
        switch kind {
        case .revealReady:   return Palette.gold
        case .countdown:     return Palette.red
        case .invite:        return Palette.success
        case .friendRequest: return Palette.gold
        case .reaction:      return Palette.darkRed
        }
    }

    // MARK: - Ledger footer

    private var caughtUpFooter: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Palette.border).frame(height: 1)
            Text("ALL CAUGHT UP")
                .font(.custom("Menlo", size: 9)).tracking(2.5)
                .foregroundStyle(Palette.textTertiary)
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }
}
