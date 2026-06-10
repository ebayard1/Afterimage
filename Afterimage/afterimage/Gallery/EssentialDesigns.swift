import SwiftUI

struct LockPushDesign: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.10, green: 0.04, blue: 0.10),
                Color(red: 0.16, green: 0.08, blue: 0.03),
                Color(red: 0.29, green: 0.15, blue: 0.06)
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer().frame(height: 80)
                VStack(spacing: 4) {
                    Text("WEDNESDAY · MAY 16")
                        .font(.system(size: 11)).tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                    Text("6:42")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(.white)
                }
                // Main notification
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7).fill(LinearGradient(
                            colors: [Palette.red, Palette.darkRed],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                        Image(systemName: "camera.fill").foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("AFTERIMAGE").font(.system(size: 10)).tracking(1).foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            Text("now").font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                        }
                        Text("🌅 Sam's Bday is ready").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        Text("14 shots developed at sunrise. tap to reveal with the group.")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.75)).lineLimit(2)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 14)
                // Stack peek
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.30))
                        .frame(width: 24, height: 24)
                    Text("3 more notifications")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 18)
                Spacer()
                VStack(spacing: 6) {
                    Text("swipe up to open")
                        .font(.system(size: 11)).italic()
                        .foregroundStyle(.white.opacity(0.4))
                    Capsule().fill(.white.opacity(0.6))
                        .frame(width: 100, height: 4)
                }
                .padding(.bottom, 20)
            }
        }
    }
}

struct TermsDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "BEFORE WE BEGIN")
                Text("terms & privacy")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Palette.gold)
                VStack(alignment: .leading, spacing: 10) {
                    Text("by using afterimage you agree that…")
                        .font(.system(size: 11)).italic().foregroundStyle(Palette.textSecondary)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. your photos are private to album members until reveal").font(.system(size: 10))
                        Text("2. you own your content. we don't sell it").font(.system(size: 10))
                        Text("3. recaps can be shared by any album member after reveal").font(.system(size: 10))
                        Text("4. we don't use AI to analyze your photos").font(.system(size: 10))
                        Text("5. you can delete your account anytime, and all photos go with it").font(.system(size: 10))
                    }
                    .foregroundStyle(Palette.textTertiary)
                }
                .padding(14)
                .frame(height: 200, alignment: .topLeading)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
                check(label: "I agree to the Terms of Service", link: "read terms", checked: true)
                check(label: "I agree to the Privacy Policy", link: "read policy", checked: true)
                check(label: "I am 13 or older", link: nil, checked: false)
                Spacer()
                PrimaryButton(label: "ACCEPT & CONTINUE →", color: Palette.gold.opacity(0.5))
            }
        }
    }
    private func check(label: String, link: String?, checked: Bool) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(checked ? Palette.gold : .clear)
                RoundedRectangle(cornerRadius: 3).stroke(checked ? Palette.gold : Palette.textTertiary, lineWidth: 1.5)
                if checked { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.black) }
            }
            .frame(width: 16, height: 16)
            Text(label).font(.system(size: 11)).foregroundStyle(checked ? Palette.textPrimary : Palette.textTertiary)
            Spacer()
            if let link { Text(link).font(.system(size: 10)).foregroundStyle(Palette.gold) }
        }
    }
}

struct AgeGateDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "QUICK CHECK")
                Text("how old are you?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text("we ask this once. you must be 13+ to use afterimage. minors under 18 have additional privacy protections.")
                    .font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                HStack(spacing: 8) {
                    field("MONTH", "05", flex: 1)
                    field("DAY",   "16", flex: 1)
                    field("YEAR",  "2003", flex: 2)
                }
                .padding(.vertical, 12)
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("you're 22 years old").font(.system(size: 12)).foregroundStyle(Palette.success)
                        Text("full access to afterimage").font(.system(size: 10)).italic().foregroundStyle(Palette.success.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(10)
                .background(Palette.success.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.success.opacity(0.4), lineWidth: 1))
                Spacer()
                PrimaryButton(label: "CONTINUE →")
                Text("under 13? afterimage isn't for you yet.")
                    .font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    private func field(_ label: String, _ value: String, flex: Int) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 9, design: .monospaced)).tracking(1).foregroundStyle(Palette.textSecondary)
            Text(value).font(.system(size: 22, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(Palette.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Palette.gold.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.gold, lineWidth: 1.5))
    }
}

struct PullRefreshDesign: View {
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle().stroke(Palette.border, lineWidth: 2).frame(width: 28, height: 28)
                        Circle().trim(from: 0, to: 0.7).stroke(Palette.gold, lineWidth: 2).frame(width: 28, height: 28)
                            .rotationEffect(.degrees(-90))
                        Circle().fill(Palette.gold).frame(width: 6, height: 6)
                    }
                    Text("WINDING FILM…").font(.system(size: 11, design: .monospaced)).tracking(2).foregroundStyle(Palette.gold)
                    Text("checking for new shots").font(.system(size: 9)).italic().foregroundStyle(Palette.textTertiary)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Palette.background)
                .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)
                VStack(alignment: .leading, spacing: 12) {
                    Text("feed").font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                    VStack(alignment: .leading, spacing: 6) {
                        Rectangle().fill(Palette.border).frame(width: 80, height: 4)
                        HStack(spacing: 6) {
                            ForEach(0..<2, id: \.self) { _ in
                                Rectangle()
                                    .fill(LinearGradient(colors: [Palette.surface, Color(white: 0.10), Palette.surface], startPoint: .leading, endPoint: .trailing))
                                    .frame(height: 70)
                                    .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
                            }
                        }
                    }
                    ForEach(0..<2, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 3) {
                            Rectangle()
                                .fill(LinearGradient(colors: [Palette.surface, Color(white: 0.10), Palette.surface], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 80)
                            Rectangle().fill(Palette.border).frame(width: 180, height: 4)
                            Rectangle().fill(Palette.border).frame(width: 120, height: 4)
                        }
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
    }
}

struct LocationPermissionDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "ONE LAST THING")
                Text("your sunrise")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                VStack(spacing: 6) {
                    ZStack {
                        Rectangle().fill(Color(white: 0.20)).frame(height: 1).offset(y: 36)
                        Circle().fill(RadialGradient(colors: [Palette.gold, Palette.red],
                                                     center: .center, startRadius: 4, endRadius: 30))
                            .frame(width: 48, height: 48)
                            .shadow(color: Palette.gold.opacity(0.5), radius: 18)
                            .offset(y: 18)
                        ForEach([20, 60, 80, 100, 140], id: \.self) { deg in
                            Rectangle().fill(Palette.gold.opacity(0.4)).frame(width: 1, height: 20)
                                .offset(y: -2)
                                .rotationEffect(.degrees(Double(deg) - 90))
                                .offset(y: 30)
                        }
                    }
                    .frame(height: 90)
                    .frame(maxWidth: .infinity)
                    Text("6:42 AM").font(.system(size: 18, design: .monospaced)).tracking(2).foregroundStyle(Palette.gold)
                    Text("tomorrow's sunrise · Brooklyn, NY")
                        .font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                }
                Text("afterimage reveals albums at ")
                    .font(.system(size: 12)).foregroundStyle(Palette.textSecondary)
                + Text("your local sunrise").foregroundStyle(Palette.gold)
                + Text(". share your location once so we know when.").foregroundStyle(Palette.textSecondary)
                HStack(spacing: 10) {
                    Image(systemName: "location.fill").font(.system(size: 18)).foregroundStyle(Palette.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("location access").font(.system(size: 12)).foregroundStyle(Palette.textPrimary)
                        Text("\"while using app\" is enough").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
                Spacer()
                PrimaryButton(label: "ALLOW LOCATION")
                Text("skip — use 6:00 AM default")
                    .font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

struct StoragePermissionDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "STORAGE")
                Text("save your shots")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity)
                Text("after reveal, afterimage can save the full album to your camera roll. you keep your shots forever — even if you delete the app.")
                    .font(.system(size: 12)).foregroundStyle(Palette.textSecondary)
                row(icon: "camera.fill", title: "save to camera roll", sub: "automatically after each reveal", on: true)
                row(icon: "film.fill", title: "save recap videos", sub: "9:16 video to camera roll", on: false)
                Spacer()
                PrimaryButton(label: "CONTINUE →")
            }
        }
    }
    private func row(icon: String, title: String, sub: String, on: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Palette.textSecondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12)).foregroundStyle(Palette.textPrimary)
                Text(sub).font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            Toggle("", isOn: .constant(on)).labelsHidden().tint(Palette.gold)
        }
        .padding(10).background(Palette.surface)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.border, lineWidth: 1))
    }
}
