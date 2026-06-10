import SwiftUI

struct RevealStageDesign: View {
    let stage: Int
    var body: some View {
        let isReady = stage == 3
        let bgColor = isReady ? Palette.background : Color(red: 0.09, green: 0.02, blue: 0.02)
        let accent = isReady ? Palette.gold : Palette.darkRed
        let titles = ["developing…", "almost ready", "ready to reveal"]
        let subs   = ["do not close the app", "images surfacing", "tap to open your album"]
        let pcts   = [30, 75, 100]
        return ZStack {
            bgColor.ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [accent.opacity(isReady ? 0 : 0.25), .clear],
                                             center: .center, startRadius: 4, endRadius: 100))
                        .frame(width: 200, height: 200)
                    if !isReady {
                        ForEach([90.0, 120.0, 150.0, 180.0], id: \.self) { r in
                            Circle().stroke(accent.opacity(0.18), lineWidth: 1).frame(width: r, height: r)
                        }
                    }
                    Image(systemName: isReady ? "film" : "camera.aperture")
                        .font(.system(size: isReady ? 42 : 36))
                        .foregroundStyle(accent)
                }
                Text(titles[stage - 1])
                    .font(.system(size: isReady ? 24 : 20, weight: .bold)).italic()
                    .foregroundStyle(accent)
                Text(subs[stage - 1])
                    .font(.system(size: 12)).italic()
                    .foregroundStyle(isReady ? Palette.textSecondary : Palette.darkRed)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.6)).frame(height: 4)
                        Capsule().fill(accent).frame(width: geo.size.width * CGFloat(pcts[stage - 1]) / 100, height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 30)
                Text("\(pcts[stage - 1])% DEVELOPED")
                    .font(.system(size: 10, design: .monospaced)).tracking(2)
                    .foregroundStyle(Palette.darkRed)
                Spacer()
                if isReady {
                    PrimaryButton(label: "OPEN ALBUM →")
                        .padding(.horizontal, 24)
                }
                Spacer().frame(height: 30)
            }
        }
    }
}

struct RecapDesign: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack {
                    ImgPlaceholder(label: "recap video (9:16)", dark: true, height: 380)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sam's Birthday").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                Text("14 shots · 4 people").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "ellipsis").foregroundStyle(.white)
                        }
                        .padding(12)
                        Spacer()
                    }
                    VStack {
                        Spacer()
                        Image(systemName: "play.fill").font(.system(size: 36)).foregroundStyle(.white.opacity(0.8))
                        Spacer()
                    }
                }
                HStack {
                    ForEach([("❤️", 12), ("😂", 5), ("🔥", 8), ("😢", 2)], id: \.0) { e in
                        VStack(spacing: 2) {
                            Text(e.0).font(.system(size: 14))
                            Text("\(e.1)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 6).background(Color.black)
                .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)
                HStack(spacing: 6) {
                    ForEach(["@sam", "@leo", "@maya", "@you"], id: \.self) { u in
                        HStack(spacing: 4) {
                            AvatarCircle(label: u, size: 16)
                            Text(u).font(.system(size: 10)).foregroundStyle(Palette.textSecondary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 12)
                Spacer()
            }
        }
    }
}

struct RecapTimelineDesign: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack {
                    ImgPlaceholder(label: "▶  recap", dark: true, height: 240)
                    VStack {
                        HStack {
                            Text("Sam's Birthday").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            Text("0:08 / 0:42").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(12)
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(.white.opacity(0.15)).frame(height: 2)
                                Rectangle().fill(Palette.gold).frame(width: geo.size.width * 0.2, height: 2)
                                Rectangle().fill(Palette.gold).frame(width: 2, height: 12)
                                    .offset(x: geo.size.width * 0.2 - 1, y: -5)
                            }
                        }
                        .frame(height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("tap the timeline to react")
                        .font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(white: 0.07)).frame(height: 20)
                            Rectangle().fill(Palette.border).frame(height: 2).offset(y: 9)
                            Rectangle().fill(Palette.gold).frame(width: 1).offset(x: geo.size.width * 0.2)
                            ForEach([(0.10, "❤️"), (0.28, "🔥"), (0.45, "😂"), (0.65, "❤️"), (0.82, "🔥")], id: \.0) { r in
                                Text(r.1).font(.system(size: 12))
                                    .offset(x: geo.size.width * r.0 - 6, y: -2)
                            }
                        }
                    }
                    .frame(height: 24)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)

                VStack(alignment: .leading, spacing: 10) {
                    Text("reactions at 0:08").font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.textPrimary)
                    HStack(spacing: 8) {
                        ForEach(["❤️", "🔥", "😂", "😢", "😮", "👏"], id: \.self) { e in
                            Text(e).font(.system(size: 18))
                                .padding(.horizontal, 4).padding(.vertical, 4)
                                .background(e == "❤️" ? Color.white.opacity(0.08) : Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(e == "❤️" ? Palette.border : .clear, lineWidth: 1))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8).background(Color(white: 0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    SectionLabel(text: "who reacted")
                    ForEach([("@sam", "❤️", "0:08"), ("@leo", "❤️", "0:08"), ("@maya", "🔥", "0:09")], id: \.0) { r in
                        HStack(spacing: 8) {
                            AvatarCircle(label: r.0)
                            Text(r.0).font(.system(size: 12)).foregroundStyle(Palette.textSecondary)
                            Spacer()
                            Text(r.1).font(.system(size: 14))
                            Text(r.2).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.textTertiary)
                        }
                    }
                }
                .padding(12)
                Spacer()
            }
        }
    }
}

struct ShareRecapDesign: View {
    private let targets: [(icon: String, label: String, color: Color)] = [
        ("camera.fill", "Instagram", Color(red: 0.51, green: 0.23, blue: 0.71)),
        ("message.fill", "iMessage", Color(red: 0.20, green: 0.78, blue: 0.35)),
        ("bird.fill", "Twitter/X", Color(red: 0.11, green: 0.63, blue: 0.95)),
        ("camera.macro", "Snapchat", Color(red: 1.0, green: 0.99, blue: 0.0)),
        ("music.note", "TikTok", Color(red: 1.0, green: 0.0, blue: 0.31)),
        ("arrow.down.circle.fill", "Save", Palette.textSecondary),
    ]
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ImgPlaceholder(label: "▶  Sam's Birthday", dark: true, height: 140)
                    .overlay(
                        VStack {
                            HStack {
                                Text("Sam's Birthday").font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                                Spacer()
                            }.padding(10)
                            Spacer()
                        }
                    )
                VStack(alignment: .leading, spacing: 12) {
                    Text("share recap").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                    Text("send to friends or post to your socials").font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(targets, id: \.label) { t in
                            VStack(spacing: 4) {
                                Image(systemName: t.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(t.color)
                                    .frame(width: 50, height: 50)
                                    .background(t.color.opacity(0.15))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.color.opacity(0.4), lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Text(t.label).font(.system(size: 10)).foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }
                    HStack {
                        Text("afterimage.app/r/sams-bday-2025")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Palette.textTertiary)
                        Spacer()
                        Text("copy").font(.system(size: 11)).foregroundStyle(Palette.gold)
                    }
                    .padding(10).background(Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
                    HStack(spacing: 8) {
                        OutlineButton(label: "export video", color: Palette.textSecondary)
                        OutlineButton(label: "export photos", color: Palette.textSecondary)
                    }
                }
                .padding(16)
                Spacer()
            }
        }
    }
}
