import SwiftUI

// MARK: - SettingsView (high-end-visual-design rebuild)
//
// Variance Engine roll:
//   Vibe:   Editorial Luxury
//   Layout: Asymmetrical Bento — each settings cluster (ACCOUNT, PRIVACY,
//           NOTIFICATIONS, DANGER) lives in its own Double-Bezel plate with
//           its own eyebrow header, instead of a flat iOS-default form list.
//
// Replaces the centered nav title + edge-to-edge rows with a hero block,
// clustered plates, button-in-button row anatomy, and a Menlo ledger footer.

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss
    @AppStorage("contactsSync") private var contactsSync = false
    @AppStorage("notifyCountdown") private var notifyCountdown = true
    @AppStorage("notifyReveal") private var notifyReveal = true
    @AppStorage("notifyReactions") private var notifyReactions = false
    @State private var showSignOutConfirm = false

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
                        .padding(.bottom, 36)
                    accountPlate
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    privacyPlate
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    notificationsPlate
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    dangerPlate
                        .padding(.horizontal, 18)
                        .padding(.bottom, 32)
                    versionFooter
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
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sign out", role: .destructive) {
                try? auth.signOut()
                dismiss()
            }
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
                Text("SETTINGS")
                    .font(.custom("Bebas Neue", size: 12)).tracking(3)
                    .foregroundStyle(Palette.gold)
            }
            Spacer()
            Color.clear.frame(width: 32, height: 32)
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
                Text(auth.email ?? "SIGNED OUT")
                    .font(.custom("Menlo", size: 10)).tracking(2)
                    .foregroundStyle(Palette.gold)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                Capsule().fill(Palette.gold.opacity(0.10))
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1))
            )

            VStack(alignment: .leading, spacing: -2) {
                Text("YOUR")
                    .font(.custom("Bebas Neue", size: 52)).tracking(-1)
                    .foregroundStyle(Palette.textPrimary)
                Text("DARKROOM.")
                    .font(.custom("Bebas Neue", size: 52)).tracking(-1)
                    .foregroundStyle(Palette.gold)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("the quiet controls — account, privacy, what wakes you up.")
                .font(.custom("Times New Roman", size: 14)).italic()
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Account plate

    private var accountPlate: some View {
        clusterPlate(eyebrow: "ACCOUNT", tint: Palette.gold) {
            VStack(spacing: 0) {
                accountRow(icon: "person.crop.circle.fill",
                           tint: Palette.gold,
                           title: "Edit Profile",
                           sub: "name, @username, avatar")
                divider
                accountRow(icon: "envelope.fill",
                           tint: Palette.textSecondary,
                           title: "Email & Password",
                           sub: auth.email ?? "you@email.com")
                divider
                accountRow(icon: "link",
                           tint: Palette.textSecondary,
                           title: "Linked Accounts",
                           sub: "Apple · Google")
            }
        }
    }

    // MARK: - Privacy plate

    private var privacyPlate: some View {
        clusterPlate(eyebrow: "PRIVACY", tint: Palette.darkRed) {
            VStack(spacing: 0) {
                toggleRow(icon: "person.2.fill",
                          tint: Palette.darkRed,
                          title: "Contacts Sync",
                          sub: "find friends automatically",
                          on: $contactsSync)
                divider
                infoBanner(
                    text: "presence-to-reveal lives per album in the create flow now, not here.",
                    icon: "info.circle"
                )
            }
        }
    }

    // MARK: - Notifications plate

    private var notificationsPlate: some View {
        clusterPlate(eyebrow: "NOTIFICATIONS", tint: Palette.gold) {
            VStack(spacing: 0) {
                plainToggleRow(icon: "hourglass",
                               title: "Album Countdown",
                               sub: "ping me as the reveal nears",
                               on: $notifyCountdown)
                divider
                plainToggleRow(icon: "sunrise.fill",
                               title: "Reveal Ready",
                               sub: "the moment a roll develops",
                               on: $notifyReveal)
                divider
                plainToggleRow(icon: "bubble.left.fill",
                               title: "New Reactions",
                               sub: "comments + likes on your shots",
                               on: $notifyReactions)
            }
        }
    }

    // MARK: - Danger plate (sign out + delete)

    private var dangerPlate: some View {
        clusterPlate(eyebrow: "EXITS", tint: Palette.red) {
            VStack(spacing: 0) {
                dangerRow(icon: "rectangle.portrait.and.arrow.right",
                          tint: Palette.red,
                          title: "Sign Out",
                          sub: "you'll need to sign in again",
                          isDestructive: false) {
                    showSignOutConfirm = true
                }
                divider
                dangerRow(icon: "trash.fill",
                          tint: Palette.darkRed,
                          title: "Delete Account",
                          sub: "permanent — every roll, comment, shot",
                          isDestructive: true) {
                    toast.show("account deletion isn't wired yet")
                }
            }
        }
    }

    // MARK: - Cluster plate shell
    //
    // Double-Bezel container with an eyebrow row inside, holding any number of
    // child rows. Outer shell + inner core with concentric corners, both
    // strokes calibrated to the cluster's tint.

    @ViewBuilder
    private func clusterPlate<Content: View>(
        eyebrow: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow row
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 5, height: 5)
                Text(eyebrow)
                    .font(.custom("Bebas Neue", size: 12)).tracking(3)
                    .foregroundStyle(tint)
                Rectangle().fill(tint.opacity(0.2)).frame(height: 1)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Rectangle().fill(Palette.border.opacity(0.5)).frame(height: 1)

            content()
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
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var divider: some View {
        Rectangle().fill(Palette.border.opacity(0.5))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    // MARK: - Row variants

    /// Account row — tinted icon circle + title/sub + button-in-button chevron.
    private func accountRow(icon: String, tint: Color, title: String, sub: String) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            toast.show("not wired yet")
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.15))
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(tint)
                }
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(tint.opacity(0.35), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(sub)
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
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
        .buttonStyle(.plain)
        .pressEffect(scale: 0.985)
        .accessibilityLabel("\(title), \(sub)")
        .accessibilityHint("Opens \(title.lowercased())")
    }

    /// Toggle row with icon, title, sub.
    private func toggleRow(icon: String, tint: Color, title: String, sub: String, on: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.15))
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(tint)
            }
            .frame(width: 32, height: 32)
            .overlay(Circle().stroke(tint.opacity(0.35), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(sub)
                    .font(.custom("Times New Roman", size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            Toggle("", isOn: on).labelsHidden().tint(tint)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Compact toggle row used inside notifications cluster.
    private func plainToggleRow(icon: String, title: String, sub: String, on: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                Text(sub)
                    .font(.custom("Times New Roman", size: 10)).italic()
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            Toggle("", isOn: on).labelsHidden().tint(Palette.gold)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Inline info banner inside a cluster.
    private func infoBanner(text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Palette.textTertiary)
                .padding(.top, 2)
            Text(text)
                .font(.custom("Times New Roman", size: 11)).italic()
                .foregroundStyle(Palette.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    /// Row in the danger cluster — destructive styling, no chevron icon, just a quiet arrow.
    private func dangerRow(icon: String, tint: Color, title: String, sub: String,
                           isDestructive: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.15))
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(tint)
                }
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(tint.opacity(0.4), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(sub)
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.7))
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .pressEffect(scale: 0.985)
        .accessibilityLabel(title)
        .accessibilityHint(sub)
    }

    // MARK: - Footer

    private var versionFooter: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Palette.border).frame(height: 1)
            Text("AFTERIMAGE · v1.0")
                .font(.custom("Menlo", size: 9)).tracking(2.5)
                .foregroundStyle(Palette.textTertiary)
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }
}
