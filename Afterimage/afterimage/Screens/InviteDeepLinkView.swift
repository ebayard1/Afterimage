import SwiftUI

struct InviteDeepLinkView: View {
    let fromUsername: String
    let albumName: String
    let durationLabel: String
    let shots: Int
    let members: [String]
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer().frame(height: 30)
                ZStack {
                    Circle().stroke(Palette.gold, lineWidth: 2).frame(width: 72, height: 72)
                    Circle().fill(Palette.surface).frame(width: 64, height: 64)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Palette.textTertiary)
                }
                Text("\(fromUsername) invited you")
                    .font(.system(size: 13)).italic()
                    .foregroundStyle(Palette.gold)
                Text(albumName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 0) {
                    row("shots per person", "\(shots)")
                    Divider().background(Palette.border)
                    row("window", durationLabel)
                    Divider().background(Palette.border)
                    row("members so far", "\(members.count)")
                    Divider().background(Palette.border)
                    row("visibility", "private")
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.border, lineWidth: 1))
                HStack(spacing: -6) {
                    ForEach(members.prefix(4), id: \.self) { m in
                        AvatarCircle(label: m, size: 28, bg: Color(white: 0.18), fg: .white)
                            .overlay(Circle().stroke(Palette.background, lineWidth: 1))
                    }
                    if members.count > 4 {
                        Text("& \(members.count - 4) others")
                            .font(.system(size: 11)).italic()
                            .foregroundStyle(Palette.textTertiary)
                            .padding(.leading, 8)
                    }
                }
                Spacer()
                Button {
                    toast.success("joined \(albumName)")
                    dismiss()
                } label: {
                    Text("JOIN ALBUM →")
                        .font(.system(size: 14, weight: .bold)).tracking(1)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Palette.gold)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                Button { dismiss() } label: {
                    Text("decline")
                        .font(.system(size: 12)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(Palette.textTertiary)
            Spacer()
            Text(value).font(.system(size: 12)).foregroundStyle(Palette.textSecondary)
        }
        .padding(.vertical, 6)
    }
}
