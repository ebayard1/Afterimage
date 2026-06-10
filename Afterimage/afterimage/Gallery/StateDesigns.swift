import SwiftUI

private struct CenteredState<Content: View>: View {
    let bg: Color
    let content: () -> Content
    init(bg: Color = Palette.background, @ViewBuilder content: @escaping () -> Content) {
        self.bg = bg
        self.content = content
    }
    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 12) {
                Spacer()
                content()
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}

struct EmptyFeedDesign: View {
    var body: some View {
        CenteredState {
            ZStack {
                Circle().stroke(Palette.border, style: StrokeStyle(lineWidth: 1.5, dash: [3])).frame(width: 80, height: 80)
                Image(systemName: "camera.fill").font(.system(size: 30)).foregroundStyle(Palette.textTertiary)
            }
            Text("welcome to afterimage").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.textPrimary)
            Text("create your first album — or join one with a QR code")
                .font(.system(size: 12)).italic().multilineTextAlignment(.center).foregroundStyle(Palette.textTertiary)
            PrimaryButton(label: "CREATE ALBUM").padding(.top, 8).frame(maxWidth: 200)
            OutlineButton(label: "SCAN QR TO JOIN", color: Palette.red).frame(maxWidth: 200)
            Text("no albums yet").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
        }
    }
}

struct NoFriendsDesign: View {
    var body: some View {
        CenteredState {
            ZStack {
                Circle().stroke(Palette.border, style: StrokeStyle(lineWidth: 1.5, dash: [3])).frame(width: 80, height: 80)
                Image(systemName: "person.crop.circle").font(.system(size: 28)).foregroundStyle(Palette.textTertiary)
            }
            Text("no friends yet").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.textPrimary)
            Text("find friends from contacts — or share your profile link")
                .font(.system(size: 12)).italic().multilineTextAlignment(.center).foregroundStyle(Palette.textTertiary)
            PrimaryButton(label: "FIND FRIENDS").padding(.top, 8).frame(maxWidth: 200)
            Text("your feed will fill up here").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
        }
    }
}

struct UploadFailedDesign: View {
    var body: some View {
        CenteredState {
            ZStack {
                Circle().fill(Palette.gold.opacity(0.1)).frame(width: 64, height: 64)
                Circle().stroke(Palette.gold, lineWidth: 1.5).frame(width: 64, height: 64)
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 22)).foregroundStyle(Palette.gold)
            }
            Text("upload failed").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.textPrimary)
            Text("shot saved locally — syncs when reconnected").font(.system(size: 12)).italic().foregroundStyle(Palette.textTertiary).multilineTextAlignment(.center)
            PrimaryButton(label: "RETRY").padding(.top, 8).frame(maxWidth: 200)
            Text("dismiss").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
        }
    }
}

struct OfflineDesign: View {
    var body: some View {
        CenteredState {
            ZStack {
                Circle().fill(Palette.red.opacity(0.1)).frame(width: 64, height: 64)
                Circle().stroke(Palette.red, lineWidth: 1.5).frame(width: 64, height: 64)
                Image(systemName: "wifi.slash").font(.system(size: 22)).foregroundStyle(Palette.red)
            }
            Text("no connection").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.textPrimary)
            Text("afterimage needs internet to sync").font(.system(size: 12)).italic().foregroundStyle(Palette.textTertiary)
            PrimaryButton(label: "RETRY", color: Palette.red, textColor: .white).padding(.top, 8).frame(maxWidth: 200)
            Text("dismiss").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
        }
    }
}

struct CameraDeniedDesign: View {
    var body: some View {
        CenteredState {
            ZStack {
                Circle().fill(Palette.red.opacity(0.1)).frame(width: 64, height: 64)
                Circle().stroke(Palette.red, lineWidth: 1.5).frame(width: 64, height: 64)
                Image(systemName: "camera.fill").font(.system(size: 22)).foregroundStyle(Palette.red)
            }
            Text("camera access needed").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.textPrimary)
            Text("open settings to allow camera access").font(.system(size: 12)).italic().foregroundStyle(Palette.textTertiary)
            PrimaryButton(label: "OPEN SETTINGS", color: Palette.red, textColor: .white).padding(.top, 8).frame(maxWidth: 200)
            Text("dismiss").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
        }
    }
}

struct LeftAlbumDesign: View {
    var body: some View {
        CenteredState {
            ZStack {
                Circle().stroke(Palette.textSecondary, lineWidth: 1.5).frame(width: 60, height: 60)
                Image(systemName: "arrow.uturn.left").font(.system(size: 22)).foregroundStyle(Palette.textSecondary)
            }
            Text("you left this album").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.textPrimary)
            Text("your choice — no hard feelings.\nyour shots are still in the album.")
                .font(.system(size: 12)).italic().multilineTextAlignment(.center).foregroundStyle(Palette.textTertiary)
            VStack(spacing: 8) {
                Text("your shots stay in the recap").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { _ in
                        ImgPlaceholder(label: "", dark: true, height: 40).frame(width: 50)
                    }
                }
                Text("4 SHOTS COMMITTED")
                    .font(.system(size: 10, design: .monospaced)).tracking(2)
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(12).background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
            Text("you'll still see the recap at sunrise").font(.system(size: 11)).italic().foregroundStyle(Palette.textSecondary)
            OutlineButton(label: "back to feed", color: Palette.textSecondary).frame(maxWidth: 200)
            Text("rejoin album").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
        }
    }
}

struct RemovedDesign: View {
    var body: some View {
        CenteredState(bg: Palette.background) {
            ZStack {
                Circle().stroke(Palette.red, lineWidth: 1.5).frame(width: 60, height: 60)
                Image(systemName: "xmark").font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.red)
            }
            Text("you were removed").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.textPrimary)
            (Text("@sam removed you from\n").foregroundStyle(Palette.textTertiary) +
             Text("\"Camping Weekend\"").foregroundStyle(Palette.textPrimary))
                .font(.system(size: 12)).italic().multilineTextAlignment(.center)
            VStack(spacing: 8) {
                Text("your shots will not appear in recap").font(.system(size: 11)).foregroundStyle(Palette.red)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        ImgPlaceholder(label: "", red: true, height: 40).frame(width: 50).opacity(0.6)
                    }
                }
                Text("3 SHOTS EXCLUDED")
                    .font(.system(size: 10, design: .monospaced)).tracking(2)
                    .foregroundStyle(Palette.darkRed)
            }
            .padding(12).background(Color(red: 0.10, green: 0.02, blue: 0.02))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.red, lineWidth: 1))
            Text("you won't see this recap").font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
            OutlineButton(label: "back to feed", color: Palette.textSecondary).frame(maxWidth: 200)
            Text("report this").font(.system(size: 10)).italic().foregroundStyle(Palette.red)
        }
    }
}

struct AlbumFullDesign: View {
    var body: some View {
        CenteredState {
            VStack(spacing: 4) {
                Text("film roll complete").font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                HStack(spacing: 4) {
                    ForEach(0..<12, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Palette.gold)
                            .frame(width: 14, height: 18)
                            .opacity(i == 11 ? 1.0 : 0.6)
                    }
                }
                Text("24 / 24").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.gold)
            }
            Text("roll is full").font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.textPrimary)
            Text("all 24 shots have been taken\nthe album is now locked")
                .font(.system(size: 12)).italic().multilineTextAlignment(.center).foregroundStyle(Palette.textTertiary)
            VStack(spacing: 4) {
                Text("developing window").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                Text("8h 44m remaining").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.darkRed)
                Text("album will reveal when timer ends").font(.system(size: 10)).foregroundStyle(Palette.textTertiary)
            }
            .padding(12).background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
            .padding(.horizontal, 16)
            PrimaryButton(label: "BACK TO FEED →").frame(maxWidth: 240)
        }
    }
}

struct EmptyInProgressDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chevron.left").foregroundStyle(Palette.textTertiary)
                    Text("Sam's Birthday").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("● 22h LEFT").font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.red)
                }
                Divider().background(Palette.border)
                VStack(spacing: 14) {
                    Spacer()
                    VStack(spacing: 4) {
                        HStack(spacing: 3) {
                            ForEach(0..<12, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2).stroke(Palette.border, lineWidth: 1)
                                    .frame(width: 14, height: 20)
                            }
                        }
                        Text("0 / 24 SHOTS").font(.system(size: 11, design: .monospaced)).tracking(2).foregroundStyle(Palette.textTertiary)
                    }
                    Text("blank roll").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                    Text("no one has shot anything yet.\nbe the first.")
                        .font(.system(size: 12)).italic().multilineTextAlignment(.center).foregroundStyle(Palette.textTertiary)
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill").foregroundStyle(.black)
                        Text("OPEN CAMERA").font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Palette.gold)
                    .cornerRadius(6)
                    VStack(spacing: 6) {
                        Text("4 people in this album").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                        HStack(spacing: 6) {
                            ForEach(["S", "L", "M", "Y"], id: \.self) { l in AvatarCircle(label: l, size: 24) }
                        }
                    }
                    .padding(10).background(Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
                    Spacer()
                }
            }
        }
    }
}

struct FilmCanisterDesign: View {
    var body: some View {
        CenteredState {
            ZStack {
                // Cap
                VStack(spacing: 0) {
                    Rectangle().fill(Color(white: 0.32))
                        .frame(width: 60, height: 16)
                        .overlay(Rectangle().stroke(Color(white: 0.40), lineWidth: 2))
                    Rectangle().fill(Color(white: 0.10))
                        .frame(width: 56, height: 60)
                        .overlay(Rectangle().stroke(Color(white: 0.20), lineWidth: 2))
                        .overlay(
                            VStack(spacing: 1) {
                                Text("AFTER").font(.system(size: 8, design: .monospaced)).foregroundStyle(.black)
                                Text("IMAGE").font(.system(size: 8, design: .monospaced)).foregroundStyle(.black)
                                Text("400").font(.system(size: 7, design: .monospaced)).foregroundStyle(.black)
                            }
                            .padding(.horizontal, 4)
                            .background(Palette.red)
                        )
                    Rectangle().fill(Color(white: 0.07))
                        .frame(width: 56, height: 5)
                        .overlay(Rectangle().stroke(Color(white: 0.20), lineWidth: 1))
                }
                // Film leader tongue
                VStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(.black).frame(width: 4, height: 4)
                    }
                }
                .padding(6)
                .background(Palette.red)
                .overlay(Rectangle().stroke(Palette.gold, lineWidth: 1))
                .offset(y: -42)
            }
            Text("fresh roll loaded")
                .font(.system(size: 20, weight: .semibold)).italic()
                .foregroundStyle(Palette.textPrimary)
            Text("no shots yet. create an album\nor join one to start developing.")
                .font(.system(size: 11)).italic().multilineTextAlignment(.center).foregroundStyle(Palette.textTertiary)
            PrimaryButton(label: "CREATE ALBUM").frame(maxWidth: 200).padding(.top, 6)
            OutlineButton(label: "SCAN QR TO JOIN", color: Palette.red).frame(maxWidth: 200)
        }
    }
}
