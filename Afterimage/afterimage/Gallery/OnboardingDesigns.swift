import SwiftUI

struct WelcomeDesign: View {
    var body: some View {
        DesignScreen {
            VStack(spacing: 16) {
                Spacer().frame(height: 20)
                // Sprockets top
                HStack(spacing: 5) {
                    ForEach(0..<5) { _ in
                        Rectangle().stroke(Palette.border, lineWidth: 1).frame(width: 16, height: 10)
                    }
                }
                // Big logo box
                VStack(spacing: 6) {
                    Spacer()
                    Text("AFTERIMAGE")
                        .font(.system(size: 26, weight: .bold)).tracking(4)
                        .foregroundStyle(Palette.gold)
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 44))
                        .foregroundStyle(Palette.gold)
                        .padding(.top, 8)
                    Text("shoot blind. develop together.")
                        .font(.system(size: 11)).italic()
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, 8)
                    Text("no previews. no retakes. no spoilers.")
                        .font(.system(size: 10)).italic()
                        .foregroundStyle(Palette.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity).frame(height: 380)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.gold, lineWidth: 1.5))
                .background(Palette.surface)
                HStack(spacing: 5) {
                    ForEach(0..<5) { _ in
                        Rectangle().stroke(Palette.border, lineWidth: 1).frame(width: 16, height: 10)
                    }
                }
                Spacer()
                PrimaryButton(label: "DEVELOP YOUR FIRST ALBUM")
            }
        }
    }
}

struct HowItWorksDesign: View {
    private let steps: [(n: String, label: String, icon: String, desc: String)] = [
        ("01", "SHOOT", "camera.fill", "No preview, no retakes. Sealed on shutter press."),
        ("02", "SET A WINDOW", "clock.fill", "Pick 1, 2, or 5 days. No one peeks until time is up."),
        ("03", "REVEAL", "film.fill", "All shots surface at once, at sunrise."),
    ]
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 16) {
                Text("How it works")
                    .font(.system(size: 22, weight: .bold)).italic()
                    .foregroundStyle(Palette.gold)
                ForEach(steps, id: \.n) { s in
                    HStack(alignment: .top, spacing: 10) {
                        Text(s.n)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.gold)
                            .frame(width: 26, height: 26)
                            .overlay(Rectangle().stroke(Palette.gold, lineWidth: 1.5))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.label)
                                .font(.system(size: 13, weight: .bold)).tracking(2)
                                .foregroundStyle(Palette.gold)
                            Text(s.desc)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Spacer()
                        Image(systemName: s.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    .padding(.bottom, 12)
                    .overlay(Rectangle().fill(Palette.border).frame(height: 1).padding(.top, 60), alignment: .bottomLeading)
                }
                // Film roll
                VStack(alignment: .leading, spacing: 6) {
                    Text("your film roll")
                        .font(.system(size: 10)).italic()
                        .foregroundStyle(Palette.textTertiary)
                    HStack(spacing: 3) {
                        ForEach(0..<12) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i < 3 ? Palette.gold : Color(white: 0.10))
                                .frame(height: 14)
                        }
                    }
                    Text("3 / 24 SHOTS")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Palette.textTertiary).tracking(2)
                }
                .padding(10)
                .overlay(Rectangle().stroke(Palette.border, style: StrokeStyle(lineWidth: 1, dash: [3])))
                Spacer()
                PrimaryButton(label: "NEXT →")
            }
        }
    }
}

struct EmailSignupDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "CREATE ACCOUNT")
                Text("afterimage")
                    .font(.system(size: 28, weight: .bold)).italic()
                    .foregroundStyle(Palette.gold)
                Text("email")
                    .font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                    .padding(.top, 8)
                FauxField(placeholder: "you@email.com")
                Text("password")
                    .font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                FauxField(placeholder: "••••••••", accent: true)
                HStack {
                    Spacer()
                    Text("forgot password?")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.red)
                }
                PrimaryButton(label: "SIGN UP →")
                    .padding(.top, 8)
                HStack(spacing: 8) {
                    Rectangle().fill(Palette.border).frame(height: 1)
                    Text("or").font(.system(size: 10)).foregroundStyle(Palette.textTertiary)
                    Rectangle().fill(Palette.border).frame(height: 1)
                }
                ssoButton("􀣺  continue with Apple")
                ssoButton("G  continue with Google")
                HStack(spacing: 4) {
                    Text("no account?").font(.system(size: 11)).foregroundStyle(Palette.textTertiary)
                    Text("sign up").font(.system(size: 11)).foregroundStyle(Palette.gold)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
    }
    private func ssoButton(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
    }
}

struct EmailVerifyDesign: View {
    private let digits = ["3", "7", "", "", "", ""]
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "VERIFY EMAIL")
                Text("check your inbox")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text("code sent to ")
                    .font(.system(size: 12)).italic()
                    .foregroundStyle(Palette.textTertiary)
                + Text("you@email.com").foregroundStyle(Palette.gold)
                HStack(spacing: 8) {
                    ForEach(0..<6) { i in
                        Text(digits[i])
                            .font(.system(size: 22, design: .monospaced).bold())
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 50)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(i < 2 ? Palette.gold : Palette.border, lineWidth: i < 2 ? 1.5 : 1))
                            .background(i < 2 ? Color.white.opacity(0.04) : Color.clear)
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                HStack(spacing: 4) {
                    Text("didn't get it?").font(.system(size: 11)).foregroundStyle(Palette.textTertiary)
                    Text("resend").font(.system(size: 11)).foregroundStyle(Palette.gold)
                }
                .frame(maxWidth: .infinity)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
                    ForEach(["1","2","3","4","5","6","7","8","9","*","0","⌫"], id: \.self) { k in
                        Text(k)
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundStyle(Palette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
                Spacer()
                PrimaryButton(label: "VERIFY →", color: Palette.gold.opacity(0.4))
            }
        }
    }
}

struct ProfileSetupDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "PROFILE")
                Text("set up your profile")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                VStack(spacing: 8) {
                    ZStack {
                        Circle().stroke(Palette.gold, lineWidth: 2).frame(width: 88, height: 88)
                        Circle().fill(Palette.surface).frame(width: 76, height: 76)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(Palette.textTertiary)
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Palette.gold)
                            .offset(x: 28, y: 28)
                    }
                    Text("choose photo")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.gold)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.gold, lineWidth: 1))
                }
                .frame(maxWidth: .infinity)
                Text("display name").font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                FauxField(placeholder: "Ethan B.")
                Text("@username").font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                HStack {
                    Text("@").font(.system(size: 12)).foregroundStyle(Palette.textTertiary)
                    Text("ethan").font(.system(size: 12)).foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("✓ available").font(.system(size: 10)).foregroundStyle(Palette.success)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.gold, lineWidth: 1.5))
                Spacer()
                PrimaryButton(label: "NEXT →")
            }
        }
    }
}

struct FindFriendsDesign: View {
    private let friends: [(n: String, u: String, on: Bool)] = [
        ("Alex Chen","@alexc",true),
        ("Bella R.","@bellar",true),
        ("Cameron D.","@cam",false),
        ("Dana M.","@danam",false),
        ("Eli Park","@elipark",true),
    ]
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "FRIENDS")
                Text("find friends").font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.textPrimary)
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill").foregroundStyle(Palette.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("contacts access").font(.system(size: 12)).foregroundStyle(Palette.textPrimary)
                        Text("find friends already on afterimage").font(.system(size: 9)).italic().foregroundStyle(Palette.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: .constant(true)).labelsHidden().tint(Palette.gold)
                }
                .padding(10).background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
                Text("5 friends found on afterimage").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                ForEach(friends, id: \.u) { f in
                    HStack(spacing: 8) {
                        AvatarCircle(label: f.n)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.n).font(.system(size: 13)).foregroundStyle(Palette.textPrimary)
                            Text(f.u).font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                        }
                        Spacer()
                        Toggle("", isOn: .constant(f.on)).labelsHidden().tint(Palette.gold)
                    }
                }
                Spacer()
                PrimaryButton(label: "ADD SELECTED + CONTINUE →")
            }
        }
    }
}

struct PermissionsDesign: View {
    private let perms: [(icon: String, label: String, sub: String)] = [
        ("camera.fill", "Camera", "To shoot real-moment photos"),
        ("bell.fill", "Notifications", "For countdown & sunrise reveal"),
        ("faceid", "Face ID", "To tag friends automatically"),
    ]
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 16) {
                Text("before we start").font(.system(size: 14)).italic().foregroundStyle(Palette.textSecondary)
                Text("afterimage needs access")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.gold)
                ForEach(perms, id: \.label) { p in
                    HStack(spacing: 12) {
                        Image(systemName: p.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(Palette.gold)
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.label).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.textPrimary)
                            Text(p.sub).font(.system(size: 11)).foregroundStyle(Palette.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(10).background(Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
                }
                Spacer()
                PrimaryButton(label: "SIGN IN WITH APPLE")
                OutlineButton(label: "USE PHONE NUMBER", color: Palette.textTertiary)
            }
        }
    }
}
