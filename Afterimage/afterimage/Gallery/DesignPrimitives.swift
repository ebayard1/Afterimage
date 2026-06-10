import SwiftUI

// MARK: - Reusable bits used by every design

struct DesignScreen<Content: View>: View {
    let background: Color
    let content: () -> Content

    init(background: Color = Palette.background, @ViewBuilder content: @escaping () -> Content) {
        self.background = background
        self.content = content
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            content()
                .padding(.horizontal, 20)
                .padding(.top, 60)
        }
    }
}

struct PrimaryButton: View {
    let label: String
    var color: Color = Palette.gold
    var textColor: Color = .black
    var body: some View {
        Text(label)
            .font(.custom("Bebas Neue", size: 16)).tracking(3)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(color)
            .clipShape(Capsule())
            .warmShadow(radius: 6, y: 3, opacity: 0.35)
            .pressEffect()
    }
}

struct OutlineButton: View {
    let label: String
    var color: Color = Palette.gold
    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .medium)).tracking(0.5)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(color, lineWidth: 1.5))
    }
}

struct FauxField: View {
    let placeholder: String
    var accent: Bool = false
    var body: some View {
        HStack {
            Text(placeholder)
                .font(.system(size: 12)).italic()
                .foregroundStyle(Palette.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Palette.surface)
        .overlay(RoundedRectangle(cornerRadius: 6)
            .stroke(accent ? Palette.gold : Palette.border, lineWidth: accent ? 1.5 : 1))
        .cornerRadius(6)
    }
}

struct AvatarCircle: View {
    let label: String
    var size: CGFloat = 24
    var bg: Color = Palette.surface
    var fg: Color = Palette.textTertiary
    var body: some View {
        ZStack {
            Circle().fill(bg)
            Circle().stroke(Palette.border, lineWidth: 1)
            Text(label.prefix(1).uppercased())
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(fg)
        }
        .frame(width: size, height: size)
    }
}

struct SectionLabel: View {
    let text: String
    var color: Color = Palette.textTertiary
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium)).tracking(2)
            .foregroundStyle(color)
    }
}

struct LCD: View {
    let text: String
    var color: Color = Color(red: 0.91, green: 0.44, blue: 0.13) // #e87020
    var body: some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced).bold()).tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color(red: 0.02, green: 0.04, blue: 0.01))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color(red: 0.10, green: 0.16, blue: 0.03), lineWidth: 1))
    }
}

struct SprocketStrip: View {
    var count: Int = 14
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(white: 0.16))
                    .frame(width: 9, height: 6)
                    .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color(white: 0.20), lineWidth: 1))
            }
        }
        .padding(.vertical, 1).padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.07))
    }
}

struct ImgPlaceholder: View {
    var label: String = "photo"
    var dark: Bool = false
    var red: Bool = false
    var height: CGFloat = 80
    var body: some View {
        let baseColor: Color = red ? Color(red: 0.10, green: 0.02, blue: 0.02)
                              : dark ? Color(white: 0.07)
                              : Color(white: 0.85)
        let stripe: Color = red ? Color(red: 0.06, green: 0.01, blue: 0.01)
                            : dark ? Color(white: 0.04)
                            : Color(white: 0.92)
        ZStack {
            ZStack {
                Rectangle().fill(baseColor)
                GeometryReader { geo in
                    Canvas { ctx, size in
                        let step: CGFloat = 6
                        for i in stride(from: -size.height, to: size.width, by: step) {
                            let path = Path { p in
                                p.move(to: CGPoint(x: i, y: 0))
                                p.addLine(to: CGPoint(x: i + size.height, y: size.height))
                            }
                            ctx.stroke(path, with: .color(stripe), lineWidth: 1)
                        }
                    }
                }
            }
            Text(label)
                .font(.system(size: 9)).italic()
                .foregroundStyle(red ? Palette.darkRed : dark ? Palette.textTertiary : Color(white: 0.55))
        }
        .frame(height: height)
        .overlay(Rectangle().stroke(dark || red ? Palette.border : Color(white: 0.7), style: StrokeStyle(lineWidth: 1, dash: [3])))
    }
}
