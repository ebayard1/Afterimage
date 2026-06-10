import SwiftUI

struct NotificationsDesign: View {
    private let items: [(icon: String, title: String, sub: String, time: String, gold: Bool)] = [
        ("film.fill", "Sam's Bday is ready!", "14 shots · 4 people · reveals first (most present)", "now", true),
        ("clock.fill", "Road Trip develops in 2h", "Last chance to add shots.", "2h", false),
        ("rectangle.stack.fill", "Leo invited you to 'Camping'", "24 shots · 2 day window", "2d", false),
        ("film.fill", "NYE 2025 is ready!", "24 shots developed.", "3d", true),
    ]
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("notifications").font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Image(systemName: "bell.fill").foregroundStyle(Palette.textSecondary)
                    Image(systemName: "gearshape.fill").foregroundStyle(Palette.textSecondary)
                }
                Divider().background(Palette.border)
                // Friend requests collapsed card
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        HStack(spacing: -6) {
                            AvatarCircle(label: "A", size: 22, bg: Palette.gold.opacity(0.15), fg: Palette.gold)
                            AvatarCircle(label: "B", size: 22, bg: Palette.gold.opacity(0.15), fg: Palette.gold)
                        }
                        Text("2 friend requests").font(.system(size: 12)).foregroundStyle(Palette.gold)
                        Spacer()
                        Text("see all ›").font(.system(size: 11)).italic().foregroundStyle(Palette.textSecondary)
                    }
                    .padding(10)
                    .overlay(Rectangle().fill(Palette.gold.opacity(0.2)).frame(height: 1), alignment: .bottom)
                    HStack(spacing: 8) {
                        AvatarCircle(label: "A")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@alex_chen").font(.system(size: 12)).foregroundStyle(Palette.gold)
                            Text("3 mutual friends").font(.system(size: 9)).italic().foregroundStyle(Palette.textTertiary)
                        }
                        Spacer()
                        Text("✓").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.success)
                            .frame(width: 26, height: 22)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.success, lineWidth: 1))
                        Text("✕").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.textTertiary)
                            .frame(width: 24, height: 22)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
                    }
                    .padding(10)
                }
                .background(Color(red: 0.10, green: 0.08, blue: 0))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.gold, lineWidth: 1))
                Divider().background(Palette.border)
                ForEach(items, id: \.title) { n in
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle().fill(Palette.surface).frame(width: 30, height: 30)
                            Circle().stroke(n.gold ? Palette.gold : Palette.red, lineWidth: 1.5).frame(width: 30, height: 30)
                            Image(systemName: n.icon).font(.system(size: 13)).foregroundStyle(n.gold ? Palette.gold : Palette.red)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.title).font(.system(size: 12, weight: .medium)).foregroundStyle(n.gold ? Palette.gold : Palette.textPrimary)
                            Text(n.sub).font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                        }
                        Spacer()
                        Text(n.time).font(.system(size: 10)).foregroundStyle(Palette.textTertiary)
                    }
                    .padding(.vertical, 6)
                    Divider().background(Palette.border)
                }
                Spacer()
            }
        }
    }
}

struct FriendsListDesign: View {
    private let requests: [(String, String)] = [("@alex_chen", "3 mutual friends"), ("@bella_r", "1 mutual album")]
    private let friends = ["@sam", "@leo", "@maya", "@jake", "@kim", "@riley"]
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "chevron.left").foregroundStyle(Palette.textTertiary)
                    Text("friends").font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                    Text("8 total").font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.textTertiary)
                    Spacer()
                    Image(systemName: "bell.fill").foregroundStyle(Palette.textSecondary)
                    Image(systemName: "gearshape.fill").foregroundStyle(Palette.textSecondary)
                }
                SectionLabel(text: "REQUESTS (2)", color: Palette.gold)
                ForEach(requests, id: \.0) { r in
                    HStack(spacing: 8) {
                        AvatarCircle(label: r.0)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.0).font(.system(size: 12)).foregroundStyle(Palette.gold)
                            Text(r.1).font(.system(size: 9)).italic().foregroundStyle(Palette.textTertiary)
                        }
                        Spacer()
                        Text("✓").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.success)
                            .frame(width: 26, height: 22)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.success, lineWidth: 1))
                        Text("✕").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.textTertiary)
                            .frame(width: 24, height: 22)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
                    }
                    .padding(8)
                    .background(Color(red: 0.10, green: 0.08, blue: 0))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.gold, lineWidth: 1))
                }
                Divider().background(Palette.border)
                SectionLabel(text: "YOUR FRIENDS")
                ForEach(friends, id: \.self) { u in
                    HStack(spacing: 8) {
                        AvatarCircle(label: u)
                        Text(u).font(.system(size: 12)).foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Text("view").font(.system(size: 10)).foregroundStyle(Palette.textTertiary)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
                    }
                }
                Spacer()
            }
        }
    }
}

struct OtherProfileDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "chevron.left").foregroundStyle(Palette.textTertiary)
                    Text("@sam_k").font(.system(size: 13)).foregroundStyle(Palette.darkRed)
                    Spacer()
                    Image(systemName: "ellipsis").foregroundStyle(Palette.textTertiary)
                }
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(Palette.darkRed, lineWidth: 2).frame(width: 60, height: 60)
                        Circle().fill(Palette.surface).frame(width: 52, height: 52)
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 36)).foregroundStyle(Palette.textTertiary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sam Kim").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                        Text("3 mutual albums").font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("+ follow")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Palette.darkRed)
                            .cornerRadius(4)
                        Text("msg")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
                    }
                }
                HStack(spacing: 0) {
                    ForEach([("8", "albums"), ("234", "shots"), ("24", "friends")], id: \.0) { s in
                        VStack(spacing: 2) {
                            Text(s.0).font(.system(size: 18, weight: .bold)).foregroundStyle(Palette.textPrimary)
                            Text(s.1).font(.system(size: 9)).foregroundStyle(Palette.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .top)
                SectionLabel(text: "public dispos")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                    ForEach(0..<6) { i in
                        VStack(alignment: .leading, spacing: 2) {
                            ImgPlaceholder(label: "", dark: true, height: 80).clipped()
                            Rectangle().fill(Palette.border).frame(height: 2)
                                .padding(.horizontal, 4)
                            Text("\([14,22,18,24,9,6][i]) shots").font(.system(size: 8)).foregroundStyle(Palette.textTertiary)
                                .padding(.horizontal, 4).padding(.bottom, 3)
                        }
                        .background(Palette.surface)
                        .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
                    }
                }
                Spacer()
            }
        }
    }
}

struct BlockReportDesign: View {
    private let reasons: [(String, String)] = [
        ("exclamationmark.triangle.fill", "spam or fake account"),
        ("hand.raised.fill", "harassment or bullying"),
        ("xmark.octagon.fill", "hate speech or symbols"),
        ("eye.slash.fill", "nudity or sexual content"),
        ("person.crop.circle.badge.exclamationmark.fill", "underage user"),
        ("ellipsis.bubble.fill", "something else"),
    ]
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "chevron.left").foregroundStyle(Palette.textTertiary)
                    Text("report @user").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                }
                Text("why are you reporting this account?")
                    .font(.system(size: 12)).italic().foregroundStyle(Palette.textTertiary)
                ForEach(reasons, id: \.0) { r in
                    HStack(spacing: 10) {
                        Image(systemName: r.0).foregroundStyle(Palette.red).font(.system(size: 14))
                        Text(r.1).font(.system(size: 12)).foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Palette.textTertiary)
                    }
                    .padding(10)
                    .background(Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
                }
                Spacer()
                Divider().background(Palette.border).overlay(
                    Rectangle().stroke(Palette.border, style: StrokeStyle(lineWidth: 1, dash: [3]))
                )
                PrimaryButton(label: "BLOCK @USER", color: Palette.red, textColor: .white)
                Text("they won't be able to message you, join your albums, or see your profile")
                    .font(.system(size: 10)).italic()
                    .foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

struct SettingsFullDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 10) {
                Text("settings").font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                Divider().background(Palette.border)
                SectionLabel(text: "ACCOUNT")
                row(icon: "person.crop.circle", title: "Edit Profile", sub: "name, @username, avatar")
                row(icon: "envelope.fill", title: "Email & Password", sub: "you@email.com")
                row(icon: "link", title: "Linked Accounts", sub: "Apple · Google")
                SectionLabel(text: "PRIVACY").padding(.top, 6)
                toggleRow(title: "Contacts Sync", sub: "find friends automatically", on: false)
                toggleRow(title: "Presence Required", sub: "default for new albums", on: true)
                SectionLabel(text: "NOTIFICATIONS").padding(.top, 6)
                simpleToggle(title: "Album Countdown", on: true)
                simpleToggle(title: "Reveal Ready", on: true)
                simpleToggle(title: "New Reactions", on: false)
                Spacer()
                Rectangle().stroke(Palette.border, style: StrokeStyle(lineWidth: 1, dash: [3])).frame(height: 1)
                VStack(alignment: .leading, spacing: 8) {
                    Text("sign out").font(.system(size: 12)).foregroundStyle(Palette.red)
                    Text("delete account").font(.system(size: 11)).foregroundStyle(Palette.darkRed)
                }
            }
        }
    }
    private func row(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Palette.textSecondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12)).foregroundStyle(Palette.textPrimary)
                Text(sub).font(.system(size: 9)).foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Palette.textTertiary)
        }
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
    }
    private func toggleRow(title: String, sub: String, on: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12)).foregroundStyle(Palette.textPrimary)
                Text(sub).font(.system(size: 9)).foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            Toggle("", isOn: .constant(on)).labelsHidden().tint(Palette.darkRed)
        }
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
    }
    private func simpleToggle(title: String, on: Bool) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundStyle(Palette.textSecondary)
            Spacer()
            Toggle("", isOn: .constant(on)).labelsHidden().tint(Palette.darkRed)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
    }
}
