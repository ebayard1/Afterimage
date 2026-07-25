import SwiftUI

// MARK: - NotificationsView
//
// Editorial Luxury: hero block → gold-glow requests plate → Double-Bezel inbox
// plate → Menlo footer. Sourced from sample data in sample mode, and from the
// live `NotificationService` + `FriendService` in real mode (unified behind the
// neutral `NotifRow`/`ReqRow` structs below).

private struct NotifRow: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let time: String
    let accent: Color
    let isReveal: Bool
}

private struct ReqRow: Identifiable {
    let id: String
    let handle: String
    let displayName: String
    let subtitle: String
    let onAccept: () -> Void
    let onDecline: () -> Void
}

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(UserService.self) private var users
    @State private var notifService = NotificationService()
    @State private var friendService = FriendService()
    @State private var showFriendsList = false

    var body: some View {
        ZStack(alignment: .top) {
            Palette.background.ignoresSafeArea()
            RadialGradient(
                colors: [Palette.gold.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: 0.18), startRadius: 6, endRadius: 360
            )
            .ignoresSafeArea().allowsHitTesting(false)

            ScrollView {
                Color.clear.frame(height: 64)
                VStack(alignment: .leading, spacing: 0) {
                    heroBlock.padding(.horizontal, 22).padding(.bottom, 32)
                    if !reqRows.isEmpty {
                        requestsPlate.padding(.horizontal, 18).padding(.bottom, 28)
                    }
                    inboxPlate.padding(.horizontal, 18).padding(.bottom, 28)
                    caughtUpFooter.padding(.horizontal, 22).padding(.bottom, 36)
                }
            }
            .scrollIndicators(.hidden)

            VStack { floatingHeader; Spacer() }
        }
        .task {
            if let uid = auth.uid {
                notifService.startListening(uid: uid)
                friendService.startListening(uid: uid)
            }
        }
        // Firestore listeners don't self-remove on dealloc.
        .onDisappear {
            notifService.stopListening()
            friendService.stopListening()
        }
        .sheet(isPresented: $showFriendsList) { FriendsListView() }
    }

    // MARK: - Unified data sources

    private var reqRows: [ReqRow] {
        friendService.incoming.map { req in
            let p = users.profile(for: req.fromUid)
            return ReqRow(
                id: req.id ?? UUID().uuidString,
                handle: p?.handle ?? "@someone",
                displayName: p?.displayName ?? "Someone",
                subtitle: "wants to connect",
                onAccept: { Task { try? await friendService.accept(req) } },
                onDecline: { Task { try? await friendService.decline(req) } }
            )
        }
    }

    private var notifRows: [NotifRow] {
        notifService.items.map { n in
            NotifRow(id: n.id ?? UUID().uuidString, icon: n.icon, title: n.title,
                     subtitle: n.subtitle, time: n.relativeTime,
                     accent: accent(forKind: n.kind), isReveal: n.kind == "revealReady")
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
                    .background(Circle().fill(Palette.background.opacity(0.7))
                        .overlay(Circle().stroke(Palette.border.opacity(0.6), lineWidth: 1)))
            }
            .buttonStyle(.plain).pressEffect(scale: 0.92, lift: 1)
            .accessibilityLabel("Back")
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text("INBOX").font(.custom("Bebas Neue", size: 12)).tracking(3)
                    .foregroundStyle(Palette.gold)
                Text("·  \(totalCount) waiting")
                    .font(.custom("Times New Roman", size: 11)).italic()
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Capsule().fill(Palette.surface.opacity(0.75))
            .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 1))
            .warmShadow(radius: 18, y: 6, opacity: 0.35))
        .padding(.horizontal, 14).padding(.top, 10)
    }

    private var totalCount: Int { reqRows.count + notifRows.count }

    // MARK: - Hero

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text("SINCE YOU LAST LOOKED")
                    .font(.custom("Menlo", size: 10)).tracking(3).foregroundStyle(Palette.gold)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Palette.gold.opacity(0.10))
                .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1)))

            VStack(alignment: .leading, spacing: -2) {
                Text("WHAT YOU").font(.custom("Bebas Neue", size: 52)).tracking(-1)
                    .foregroundStyle(Palette.textPrimary)
                Text("MISSED.").font(.custom("Bebas Neue", size: 52)).tracking(-1)
                    .foregroundStyle(Palette.gold)
            }
            .lineLimit(1).minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(taglineText)
                .font(.custom("Times New Roman", size: 14)).italic()
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var taglineText: String {
        let req = reqRows.count, n = notifRows.count
        if req == 0 && n == 0 { return "the inbox is empty." }
        if req == 0 { return "\(n) updates from your network." }
        if n == 0 { return "\(req) friend request\(req == 1 ? "" : "s") waiting." }
        return "\(req) request\(req == 1 ? "" : "s") and \(n) updates from your network."
    }

    // MARK: - Requests plate

    private var requestsPlate: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    ForEach(reqRows.prefix(3)) { r in
                        AvatarCircle(label: r.displayName, size: 24,
                                     bg: Palette.gold.opacity(0.18), fg: Palette.gold)
                            .overlay(Circle().stroke(Palette.gold.opacity(0.5), lineWidth: 1))
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("FRIEND REQUESTS").font(.custom("Bebas Neue", size: 13)).tracking(3)
                        .foregroundStyle(Palette.gold)
                    Text("\(reqRows.count) waiting on you")
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                Button { showFriendsList = true } label: {
                    HStack(spacing: 4) {
                        Text("SEE ALL").font(.custom("Bebas Neue", size: 10)).tracking(2)
                        Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Palette.gold)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain).pressEffect()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Rectangle().fill(Palette.gold.opacity(0.18)).frame(height: 1)

            VStack(spacing: 0) {
                ForEach(Array(reqRows.enumerated()), id: \.element.id) { idx, r in
                    requestRow(r)
                    if idx < reqRows.count - 1 {
                        Rectangle().fill(Palette.border.opacity(0.5)).frame(height: 1)
                            .padding(.horizontal, 14)
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Color(red: 0.10, green: 0.08, blue: 0))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(0.05), lineWidth: 1)))
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Palette.background.opacity(0.4))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.gold, lineWidth: 1)))
        .warmShadow(radius: 12, y: 6, opacity: 0.4)
    }

    private func requestRow(_ r: ReqRow) -> some View {
        HStack(spacing: 12) {
            AvatarCircle(label: r.displayName, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.handle).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.gold)
                Text(r.subtitle).font(.custom("Times New Roman", size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(Motion.crisp) { r.onAccept() }
            } label: {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black).frame(width: 30, height: 28)
                    .background(Capsule().fill(Palette.success))
            }
            .buttonStyle(.plain).pressEffect()
            .accessibilityLabel("Accept request from \(r.handle)")

            Button { withAnimation(Motion.crisp) { r.onDecline() } } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.textTertiary).frame(width: 30, height: 28)
                    .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
            }
            .buttonStyle(.plain).pressEffect()
            .accessibilityLabel("Decline request from \(r.handle)")
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - Inbox plate

    private var inboxPlate: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Palette.textSecondary.opacity(0.7)).frame(width: 5, height: 5)
                Text("UPDATES").font(.custom("Bebas Neue", size: 12)).tracking(3)
                    .foregroundStyle(Palette.textSecondary)
                Text("·  \(notifRows.count)").font(.custom("Menlo", size: 10)).tracking(1)
                    .foregroundStyle(Palette.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Rectangle().fill(Palette.border.opacity(0.5)).frame(height: 1)

            if notifRows.isEmpty {
                Text("nothing new yet.")
                    .font(.custom("Times New Roman", size: 12)).italic()
                    .foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 22)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(notifRows.enumerated()), id: \.element.id) { idx, n in
                        ScrollFadeIn(delay: Double(idx) * 0.04, distance: 10) {
                            Button {
                                UISelectionFeedbackGenerator().selectionChanged()
                                notifService.markRead(n.id)
                            } label: { notificationRow(n) }
                            .buttonStyle(.plain).pressEffect(scale: 0.985)
                            .accessibilityLabel("\(n.title). \(n.subtitle)")
                        }
                        if idx < notifRows.count - 1 {
                            Rectangle().fill(Palette.border.opacity(0.4)).frame(height: 1)
                                .padding(.horizontal, 14)
                        }
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(0.05), lineWidth: 1)))
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Palette.background.opacity(0.4))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.border.opacity(0.6), lineWidth: 1)))
    }

    private func notificationRow(_ n: NotifRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(n.accent.opacity(0.15))
                Image(systemName: n.icon).font(.system(size: 13)).foregroundStyle(n.accent)
            }
            .frame(width: 32, height: 32)
            .overlay(Circle().stroke(n.accent.opacity(0.45), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(n.title).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(n.isReveal ? Palette.gold : Palette.textPrimary)
                Text(n.subtitle).font(.custom("Times New Roman", size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer(minLength: 8)
            Text(n.time).font(.custom("Menlo", size: 9)).tracking(0.5)
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func accent(forKind kind: String) -> Color {
        switch kind {
        case "revealReady":   return Palette.gold
        case "countdown":     return Palette.red
        case "invite":        return Palette.success
        case "friendRequest": return Palette.gold
        case "reaction":      return Palette.darkRed
        default:              return Palette.textSecondary
        }
    }

    private var caughtUpFooter: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Palette.border).frame(height: 1)
            Text("ALL CAUGHT UP").font(.custom("Menlo", size: 9)).tracking(2.5)
                .foregroundStyle(Palette.textTertiary)
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }
}
