//
//  Theme.swift
//  Home Workout
//
//  "Mova" visual identity: warm paper canvas, ink type, a persimmon
//  energy accent and a soft set of category hues. Headlines use the
//  New York serif for an editorial feel; numbers use SF Rounded.
//

import SwiftUI

enum Brand {
    static let name = "mova"
    static let tagline = "Move more, right where you are."
    // TODO: replace with the real pages before release.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://example.com/mova/privacy")!
    static let supportURL = URL(string: "mailto:support@example.com")!
}

extension Color {
    init(hex: String, opacity: Double = 1) {
        var v: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255,
                  opacity: opacity)
    }

    /// Light/dark adaptive colour from two hex values.
    static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }
}

enum Palette {
    // Surfaces
    static let canvas = Color.adaptive("F5F1EA", "121014")
    static let surface = Color.adaptive("FFFFFF", "1E1B21")
    static let raised = Color.adaptive("EDE7DD", "2A262D")
    static let hairline = Color.adaptive("E4DDD1", "332F37")

    // Type
    static let ink = Color.adaptive("17141B", "F7F3EC")
    static let inkSoft = Color.adaptive("6E6873", "A7A1AB")
    static let inkFaint = Color.adaptive("A49D97", "6C6670")

    // Brand
    static let persimmon = Color(hex: "FF5B2E")
    static let persimmonSoft = Color.adaptive("FFE4D9", "3A2219")
    static let plum = Color(hex: "2B1D3A")

    // Category hues
    static let sun = Color(hex: "FFC53D")
    static let lilac = Color(hex: "B7A4FF")
    static let mint = Color(hex: "6FD6B0")
    static let sky = Color(hex: "79B8FF")
    static let blush = Color(hex: "FF9EC0")
}

// MARK: - Typography

extension Font {
    /// Editorial serif headline.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// Rounded numerals for timers, counters and stats.
    static func numeral(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

/// Small uppercase label used above sections and on chips.
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.inkSoft
    init(_ text: String, color: Color = Palette.inkSoft) {
        self.text = text
        self.color = color
    }
    var body: some View {
        Text(text.uppercased())
            .font(.ui(11, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

// MARK: - Metrics

enum Metric {
    static let gutter: CGFloat = 20
    static let cardRadius: CGFloat = 28
    static let tileRadius: CGFloat = 22
    static let chipRadius: CGFloat = 14
}

/// "1 minute" / "3 minutes".
func plural(_ count: Int, _ singular: String, _ pluralForm: String? = nil) -> String {
    count == 1 ? singular : (pluralForm ?? singular + "s")
}
