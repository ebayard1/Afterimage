import SwiftUI

/// Afterimage palette. Nothing here is pure black or pure white.
/// Backgrounds are warm charcoal, text is muted cream, accents are tarnished brass / film red.
enum Palette {
    // Warm charcoal — never true black. Read as "darkroom under safe-light"
    static let background        = Color(red: 0.055, green: 0.043, blue: 0.039)  // #0E0B0A
    static let surface           = Color(red: 0.078, green: 0.066, blue: 0.062)  // #141110
    static let surfaceElevated   = Color(red: 0.102, green: 0.090, blue: 0.082)  // #1A1715
    static let border            = Color(red: 0.16,  green: 0.14,  blue: 0.12)

    // Muted cream typography — never pure white
    static let textPrimary       = Color(red: 0.941, green: 0.906, blue: 0.855)  // #F0E7DA
    static let textSecondary     = Color(red: 0.776, green: 0.722, blue: 0.643)  // worn cream
    static let textTertiary      = Color(red: 0.45,  green: 0.41,  blue: 0.36)

    // Tarnished gold — aged brass, worn Leica hardware, old Kodak hot stamp
    static let gold              = Color(red: 0.784, green: 0.663, blue: 0.420)  // #C8A96B
    static let goldDeep          = Color(red: 0.722, green: 0.573, blue: 0.310)  // #B8924F

    // Film red — darkroom safe-light. Use sparingly.
    static let red               = Color(red: 0.651, green: 0.118, blue: 0.118)  // #A61E1E
    static let darkRed           = Color(red: 0.557, green: 0.106, blue: 0.106)  // #8E1B1B

    // Aged sage for confirmations (never iOS green)
    static let success           = Color(red: 0.471, green: 0.541, blue: 0.451)
}
