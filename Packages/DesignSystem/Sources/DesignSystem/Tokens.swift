import Foundation

public struct RGB: Sendable, Equatable {
    public let r: Double, g: Double, b: Double
    public init(hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    /// WCAG relative luminance.
    public var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    public func contrast(with o: RGB) -> Double {
        let a = max(luminance, o.luminance), b = min(luminance, o.luminance)
        return (a + 0.05) / (b + 0.05)
    }
}

public struct TokenPair: Sendable {
    public let light: RGB
    public let dark: RGB
    public init(light: UInt32, dark: UInt32) { self.light = RGB(hex: light); self.dark = RGB(hex: dark) }
}

/// Raw values for every semantic colour. Green #2AB985 is the one accent and marks things the user can act on.
public enum Palette {
    public static let background = TokenPair(light: 0xFAF7F2, dark: 0x171512)
    public static let surface = TokenPair(light: 0xFFFFFF, dark: 0x221F1B)
    public static let surfaceRaised = TokenPair(light: 0xF1ECE4, dark: 0x2C2823)
    public static let separator = TokenPair(light: 0xE2DBD0, dark: 0x3A352E)
    public static let textPrimary = TokenPair(light: 0x1F1B16, dark: 0xF4EFE8)
    public static let textSecondary = TokenPair(light: 0x655E55, dark: 0xA9A196)
    /// Fill colour for actionable controls.
    public static let accent = TokenPair(light: 0x2AB985, dark: 0x2AB985)
    /// Label on top of accent fills. White on #2AB985 is only 2.4:1, so labels are dark.
    public static let onAccent = TokenPair(light: 0x10201A, dark: 0x10201A)
    /// Accent used as text or an icon on the page background.
    public static let accentText = TokenPair(light: 0x0B7551, dark: 0x3FD1A0)
    public static let success = TokenPair(light: 0x0B7551, dark: 0x3FD1A0)
    public static let warning = TokenPair(light: 0x8F5200, dark: 0xF0B14A)
    public static let danger = TokenPair(light: 0xB3261E, dark: 0xFF8A80)
    public static let privacyLocal = TokenPair(light: 0x0B7551, dark: 0x3FD1A0)
    public static let privacyCloud = TokenPair(light: 0x2F54B8, dark: 0x9DB4FF)
}

public enum Spacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
}

public enum Radius {
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 20
}
