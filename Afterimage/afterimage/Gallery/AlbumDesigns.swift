import SwiftUI

struct InviteFriendsDesign: View {
    private let suggested: [(String, String)] = [("@sam", "often shoots with you"), ("@jake", "3 mutual albums")]
    private let friends = ["@alex", "@bella", "@cam", "@dana", "@eli"]
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "chevron.left").foregroundStyle(Palette.textTertiary)
                    Text("invite friends").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                }
                Text("\"Sam's Bday\" · 24 shots · 12h").font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.textTertiary)
                    Text("search friends").font(.system(size: 12)).foregroundStyle(Palette.textTertiary)
                    Spacer()
                }
                .padding(10).background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
                HStack(spacing: 6) {
                    ForEach(["@leo ✓", "@maya ✓"], id: \.self) { chip in
                        HStack(spacing: 4) {
                            Text(chip).font(.system(size: 10)).foregroundStyle(Palette.success)
                            Image(systemName: "xmark").font(.system(size: 8)).foregroundStyle(Palette.success.opacity(0.5))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Palette.success.opacity(0.1))
                        .overlay(Capsule().stroke(Palette.success.opacity(0.5), lineWidth: 1))
                        .clipShape(Capsule())
                    }
                }
                SectionLabel(text: "suggested")
                ForEach(suggested, id: \.0) { s in
                    HStack(spacing: 8) {
                        AvatarCircle(label: s.0)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.0).font(.system(size: 12)).foregroundStyle(Palette.textPrimary)
                            Text(s.1).font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                        }
                        Spacer()
                        Text("+ add").font(.system(size: 10)).foregroundStyle(Palette.textSecondary)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
                    }
                }
                SectionLabel(text: "all friends")
                ForEach(friends, id: \.self) { f in
                    HStack(spacing: 8) {
                        Text(String(f.dropFirst().prefix(1)).uppercased())
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.textTertiary)
                            .frame(width: 12)
                        AvatarCircle(label: f, size: 22)
                        Text(f).font(.system(size: 12)).foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Rectangle().stroke(Palette.border, lineWidth: 1).frame(width: 18, height: 18)
                    }
                }
                Spacer()
                PrimaryButton(label: "NEXT: SHARE QR →", color: Palette.red, textColor: .white)
            }
        }
    }
}

struct CreatorQRDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chevron.left").foregroundStyle(Palette.textTertiary)
                    Text("share album").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                }
                Text("send this QR to invite people to shoot")
                    .font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                VStack(spacing: 8) {
                    ZStack {
                        Rectangle().fill(.white).frame(width: 200, height: 200)
                        if let img = QRCodeGenerator.image(from: "demo-album-id", size: 180) {
                            Image(uiImage: img).interpolation(.none).resizable().scaledToFit().frame(width: 180)
                        }
                    }
                    .overlay(Rectangle().stroke(Palette.gold, lineWidth: 3))
                    Text("Sam's Birthday · expires when window closes")
                        .font(.system(size: 11)).italic().foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
                HStack(spacing: 8) {
                    ForEach(["iMessage", "AirDrop", "Copy"], id: \.self) { s in
                        Text(s)
                            .font(.system(size: 11)).foregroundStyle(Palette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Palette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
                    }
                }
                Text("joined so far (2 of 4 invited)")
                    .font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                    .padding(.top, 4)
                ForEach(["@leo ✓", "@maya ✓"], id: \.self) { u in
                    HStack(spacing: 8) {
                        AvatarCircle(label: u, size: 22, bg: Palette.success.opacity(0.15), fg: Palette.success)
                        Text(u).font(.system(size: 12)).foregroundStyle(Palette.success)
                    }
                }
                Spacer()
                PrimaryButton(label: "DONE — LOAD FILM →")
            }
        }
    }
}

struct ReadyToShootDesign: View {
    var body: some View {
        DesignScreen {
            VStack(spacing: 14) {
                Spacer()
                ZStack {
                    Circle().stroke(Palette.gold, lineWidth: 4).frame(width: 110, height: 110)
                    ForEach(0..<12, id: \.self) { i in
                        Rectangle().fill(Color(white: 0.15)).frame(width: 2, height: 6)
                            .offset(y: -52)
                            .rotationEffect(.degrees(Double(i) * 30))
                    }
                    VStack(spacing: 2) {
                        Text("24").font(.system(size: 30, weight: .bold, design: .monospaced)).foregroundStyle(Palette.gold)
                        Text("shots").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                    }
                }
                Text("ready to shoot").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                Text("Sam's Bday · 4 people").font(.system(size: 12)).italic().foregroundStyle(Palette.textTertiary)
                VStack(spacing: 6) {
                    ForEach([("duration", "2 days"),
                             ("shots each", "24"),
                             ("reveals at", "🌅 sunrise, Apr 26"),
                             ("members", "4 joined")], id: \.0) { d in
                        HStack {
                            Text(d.0).font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                            Spacer()
                            Text(d.1).font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.gold)
                        }
                        .padding(.vertical, 4)
                        Divider().background(Palette.border)
                    }
                }
                .padding(12)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
                Spacer()
                PrimaryButton(label: "📷  LOAD FILM", color: .white)
            }
        }
    }
}

struct PresenceCheckDesign: View {
    private let members: [(String, Bool)] = [("@sam", true), ("@you", true), ("@leo", false), ("@maya", false)]
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 12) {
                Text("gather to reveal").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                Text("½ of the group must scan in before midnight").font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                HStack {
                    Image(systemName: "alarm.fill").foregroundStyle(Palette.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("quorum deadline: midnight").font(.system(size: 12)).foregroundStyle(Palette.red)
                        Text("miss it → reveals next sunrise instead").font(.system(size: 9)).italic().foregroundStyle(Palette.darkRed)
                    }
                    Spacer()
                    Text("3:44").font(.system(size: 14, design: .monospaced)).foregroundStyle(Palette.red)
                }
                .padding(10).background(Color(red: 0.10, green: 0.02, blue: 0.02))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.red, lineWidth: 1))
                VStack(spacing: 4) {
                    if let img = QRCodeGenerator.image(from: "presence-demo", size: 140) {
                        Image(uiImage: img).interpolation(.none).resizable().scaledToFit().frame(width: 140)
                            .padding(8).background(.white)
                            .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
                    }
                    Text("scan to check in").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("2 of 4 present").font(.system(size: 13)).foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text("need 2 more").font(.system(size: 13)).foregroundStyle(Palette.red)
                    }
                    ForEach(members, id: \.0) { m in
                        HStack(spacing: 8) {
                            ZStack {
                                Circle().fill(m.1 ? Palette.success.opacity(0.2) : Palette.surface)
                                Circle().stroke(m.1 ? Palette.success : Palette.border, lineWidth: 1.5)
                                if m.1 { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.success) }
                            }
                            .frame(width: 18, height: 18)
                            Text(m.0).font(.system(size: 12)).foregroundStyle(m.1 ? Palette.success : Palette.textTertiary)
                            Spacer()
                            Text(m.1 ? "checked in" : "waiting…").font(.system(size: 10)).italic().foregroundStyle(m.1 ? Palette.success : Palette.textTertiary)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.border).frame(height: 4)
                            Capsule().fill(Palette.success).frame(width: geo.size.width * 0.5, height: 4)
                        }
                    }.frame(height: 4)
                }
                .padding(12).background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
                Text("if quorum missed → reveals next sunrise, Apr 27")
                    .font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(10)
                    .overlay(Rectangle().stroke(Palette.border, style: StrokeStyle(lineWidth: 1, dash: [3])))
                Spacer()
            }
        }
    }
}

struct InviteDeepLinkDesign: View {
    var body: some View {
        DesignScreen {
            VStack(spacing: 14) {
                Spacer()
                ZStack {
                    Circle().stroke(Palette.gold, lineWidth: 2).frame(width: 72, height: 72)
                    Circle().fill(Palette.surface).frame(width: 64, height: 64)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Palette.textTertiary)
                }
                Text("@leo invited you").font(.system(size: 13)).italic().foregroundStyle(Palette.gold)
                Text("Camping Weekend 🏕")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 6) {
                    ForEach([("shots per person", "12"),
                             ("window", "24 hours"),
                             ("members so far", "3"),
                             ("visibility", "🔒 private")], id: \.0) { d in
                        HStack {
                            Text(d.0).font(.system(size: 11)).foregroundStyle(Palette.textTertiary)
                            Spacer()
                            Text(d.1).font(.system(size: 11)).foregroundStyle(Palette.textSecondary)
                        }
                        Divider().background(Palette.border)
                    }
                }
                .padding(12).background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
                HStack(spacing: 4) {
                    ForEach(["L", "M", "K"], id: \.self) { l in AvatarCircle(label: l, size: 28) }
                    Text("& 2 others").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                }
                PrimaryButton(label: "JOIN ALBUM →")
                Text("decline").font(.system(size: 11)).foregroundStyle(Palette.textTertiary)
                Spacer()
            }
        }
    }
}
