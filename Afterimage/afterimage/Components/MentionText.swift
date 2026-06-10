import SwiftUI

/// Renders comment body text with `@username` mentions highlighted in tarnished gold.
/// Inline taps don't navigate (SwiftUI single-Text limitation) — the parent row's
/// tap covers that case for now.
struct MentionText: View {
    let raw: String
    var size: CGFloat = 13
    var color: Color = Palette.textPrimary

    var body: some View {
        Text(attributed)
            .font(.system(size: size))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributed: AttributedString {
        var attr = AttributedString(raw)
        attr.foregroundColor = color
        let pattern = "@[a-zA-Z0-9_]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return attr }
        let nsText = raw as NSString
        let matches = regex.matches(in: raw, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            if let range = Range(match.range, in: attr) {
                attr[range].foregroundColor = Palette.gold
                attr[range].font = .system(size: size, weight: .semibold)
            }
        }
        return attr
    }
}
