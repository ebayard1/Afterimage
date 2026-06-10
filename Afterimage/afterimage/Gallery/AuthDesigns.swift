import SwiftUI

struct ForgotPasswordEnterDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "chevron.left").foregroundStyle(Palette.textTertiary)
                    Text("forgot password").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                }
                Text("enter the email tied to your account and we'll send a reset link.")
                    .font(.system(size: 12)).italic()
                    .foregroundStyle(Palette.textSecondary)
                Text("email").font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                FauxField(placeholder: "you@email.com", accent: true)
                Spacer()
                PrimaryButton(label: "SEND RESET LINK →")
            }
        }
    }
}

struct ForgotPasswordSentDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "chevron.left").foregroundStyle(Palette.textTertiary)
                    Text("check your email").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                }
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "envelope")
                        .font(.system(size: 44))
                        .foregroundStyle(Palette.gold)
                    Text("reset link sent!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    VStack(spacing: 3) {
                        Text("check you@email.com")
                            .font(.system(size: 12)).italic()
                            .foregroundStyle(Palette.textSecondary)
                        Text("link expires in 15 minutes")
                            .font(.system(size: 10)).italic()
                            .foregroundStyle(Palette.textTertiary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                HStack(spacing: 4) {
                    Text("didn't get it?").font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                    Text("resend").font(.system(size: 10)).italic().foregroundStyle(Palette.gold)
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
                Spacer()
            }
        }
    }
}

struct ForgotPasswordNewDesign: View {
    var body: some View {
        DesignScreen {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "chevron.left").foregroundStyle(Palette.textTertiary)
                    Text("new password").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                }
                Text("choose a new password").font(.system(size: 12)).italic().foregroundStyle(Palette.textSecondary)
                Text("new password").font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                FauxField(placeholder: "••••••••", accent: true)
                Text("confirm password").font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                FauxField(placeholder: "••••••••")
                HStack(spacing: 4) {
                    ForEach(0..<4) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < 2 ? Palette.success : i == 2 ? Palette.gold : Palette.border)
                            .frame(height: 4)
                    }
                }
                Text("strength: strong").font(.system(size: 10)).foregroundStyle(Palette.success)
                Spacer()
                PrimaryButton(label: "SET PASSWORD →")
            }
        }
    }
}
