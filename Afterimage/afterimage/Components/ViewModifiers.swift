import SwiftUI

// MARK: - Magnetic press effect
//
// Scales slightly + lifts the element on press, then springs back. Gives every
// primary CTA a haptic, weighty feel instead of an instant state flip.

struct PressEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false
    var scale: CGFloat = 0.97
    var lift: CGFloat = 1

    func body(content: Content) -> some View {
        content
            // Reduced motion → drop the transform, keep the signal via opacity.
            // Per Emil + Apple HIG: "Reduced motion means fewer and gentler
            // animations, not zero." Users still need feedback that the press
            // registered.
            .scaleEffect(reduceMotion ? 1.0 : (pressed ? scale : 1.0))
            .offset(y: reduceMotion ? 0 : (pressed ? lift : 0))
            .opacity(reduceMotion ? (pressed ? 0.75 : 1.0) : 1.0)
            .animation(reduceMotion ? Motion.crisp : Motion.tap, value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressed { pressed = true } }
                    .onEnded { _ in pressed = false }
            )
    }
}

extension View {
    /// Adds a magnetic press effect (small scale + slight downward lift on press).
    func pressEffect(scale: CGFloat = 0.97, lift: CGFloat = 1) -> some View {
        modifier(PressEffect(scale: scale, lift: lift))
    }
}

// MARK: - Warm-tinted shadow
//
// Pure black drop shadows are an AI tell on a warm dark theme. We tint shadows
// with the warmest brown-black in the palette so they sink into the background
// instead of looking pasted on top.

extension View {
    /// Replaces a default `.shadow(color: .black, ...)` with a warm-tinted one
    /// that matches Afterimage's brown-charcoal background.
    func warmShadow(radius: CGFloat = 8, x: CGFloat = 0, y: CGFloat = 4, opacity: Double = 0.55) -> some View {
        shadow(
            color: Color(red: 0.04, green: 0.025, blue: 0.020).opacity(opacity),
            radius: radius, x: x, y: y
        )
    }
}

// MARK: - Double-bezel (Doppelrand / nested architecture)
//
// Premium cards never sit flat on a background. Wrap them in an outer shell
// (subtle bg + hairline border + larger radius) with an inner core
// (distinct bg + inset highlight + mathematically smaller radius).

struct DoubleBezel: ViewModifier {
    var outerRadius: CGFloat = 18
    var padding: CGFloat = 4
    var outerFill: Color = Color.white.opacity(0.03)
    var outerStroke: Color = Color.white.opacity(0.06)

    private var innerRadius: CGFloat { max(2, outerRadius - padding - 1) }

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                    .fill(outerFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                            .stroke(outerStroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    /// Wraps the view in a concentric outer-shell + inner-core "machined hardware" frame.
    func doubleBezel(
        outerRadius: CGFloat = 18,
        padding: CGFloat = 4,
        outerFill: Color = Color.white.opacity(0.03),
        outerStroke: Color = Color.white.opacity(0.06)
    ) -> some View {
        modifier(DoubleBezel(
            outerRadius: outerRadius, padding: padding,
            outerFill: outerFill, outerStroke: outerStroke
        ))
    }
}
