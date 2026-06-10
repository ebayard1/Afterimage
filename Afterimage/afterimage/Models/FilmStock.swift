import SwiftUI

/// Optional film "stock" applied to an album. Affects the color grade hint on
/// the album card and inside the detail view. Stored as the raw string on the
/// Album document so Firestore round-trips cleanly.
enum FilmStock: String, CaseIterable, Identifiable {
    case kodakPortra400 = "kodak-portra-400"
    case ilfordHP5      = "ilford-hp5"
    case cinestill800T  = "cinestill-800t"
    case lomoRedscale   = "lomo-redscale"
    case polaroid600    = "polaroid-600"
    case fujiSuperia    = "fuji-superia-400"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kodakPortra400: return "Kodak Portra 400"
        case .ilfordHP5:      return "Ilford HP5"
        case .cinestill800T:  return "Cinestill 800T"
        case .lomoRedscale:   return "Lomo Redscale"
        case .polaroid600:    return "Polaroid 600"
        case .fujiSuperia:    return "Fuji Superia 400"
        }
    }

    /// Short code stamped next to album titles ("PORTRA 400" / "HP5" / etc).
    var shortCode: String {
        switch self {
        case .kodakPortra400: return "PORTRA 400"
        case .ilfordHP5:      return "HP5"
        case .cinestill800T:  return "CINESTILL 800T"
        case .lomoRedscale:   return "REDSCALE"
        case .polaroid600:    return "POLAROID 600"
        case .fujiSuperia:    return "SUPERIA 400"
        }
    }

    /// Tagline shown in the picker — one line of evocative copy each.
    var tagline: String {
        switch self {
        case .kodakPortra400: return "warm skin · cinematic golden hour"
        case .ilfordHP5:      return "high-contrast black & white"
        case .cinestill800T:  return "tungsten halation · neon nights"
        case .lomoRedscale:   return "deep crimson · light-leaked sunset"
        case .polaroid600:    return "soft instant · square-frame nostalgia"
        case .fujiSuperia:    return "cool greens · everyday daylight"
        }
    }

    /// Accent color that drives the badge tint per stock.
    var accent: Color {
        switch self {
        case .kodakPortra400: return Color(red: 0.90, green: 0.71, blue: 0.40)
        case .ilfordHP5:      return Color(white: 0.85)
        case .cinestill800T:  return Color(red: 0.95, green: 0.45, blue: 0.55)
        case .lomoRedscale:   return Color(red: 0.95, green: 0.40, blue: 0.25)
        case .polaroid600:    return Color(red: 0.96, green: 0.94, blue: 0.86)
        case .fujiSuperia:    return Color(red: 0.55, green: 0.85, blue: 0.65)
        }
    }

    /// Whether the stock is black-and-white (drives `.grayscale` on previews).
    var isMonochrome: Bool { self == .ilfordHP5 }

    /// Hue rotation hint (degrees) applied to revealed photos to suggest the grade.
    var hueRotation: Double {
        switch self {
        case .kodakPortra400: return 6
        case .ilfordHP5:      return 0
        case .cinestill800T:  return -8
        case .lomoRedscale:   return -28
        case .polaroid600:    return 4
        case .fujiSuperia:    return 14
        }
    }

    /// Saturation multiplier for the grade hint.
    var saturation: Double {
        switch self {
        case .kodakPortra400: return 1.05
        case .ilfordHP5:      return 0
        case .cinestill800T:  return 1.15
        case .lomoRedscale:   return 1.30
        case .polaroid600:    return 0.90
        case .fujiSuperia:    return 1.10
        }
    }
}

extension View {
    /// Applies a film-stock grade hint (hue + saturation + optional grayscale).
    /// Used on photo previews in cards and the detail view.
    @ViewBuilder
    func filmStockGrade(_ stock: FilmStock?) -> some View {
        if let stock {
            self
                .saturation(stock.saturation)
                .hueRotation(.degrees(stock.hueRotation))
                .grayscale(stock.isMonochrome ? 1.0 : 0.0)
        } else {
            self
        }
    }
}
