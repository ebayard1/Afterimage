import SwiftUI

/// Small Menlo section header used above lists.
struct SectionLabel: View {
    let text: String
    var color: Color = Palette.textTertiary

    var body: some View {
        Text(text)
            .font(.custom("Menlo", size: 10)).tracking(2)
            .foregroundStyle(color)
    }
}

/// Monogram avatar circle — first letter of a name/label on a tinted disc.
struct AvatarCircle: View {
    let label: String
    var size: CGFloat = 32
    var bg: Color = Palette.surface
    var fg: Color = Palette.textSecondary

    private var initial: String {
        let trimmed = label.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
        return String(trimmed.prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(bg)
            Text(initial)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(fg)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Palette.border, lineWidth: 1))
    }
}
