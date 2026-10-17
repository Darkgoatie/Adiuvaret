import SwiftUI
import Observation

/// Every semantic colour of one theme, as a light and a dark value.
public struct ThemePalette: Sendable {
    public let background, surface, surfaceRaised, separator: TokenPair
    public let textPrimary, textSecondary: TokenPair
    public let accent, onAccent, accentText: TokenPair
    public let success, warning, danger, privacyLocal, privacyCloud: TokenPair

    /// Neutrals and accent change per theme. Success, warning, danger and the privacy colours keep their meaning in every theme.
    init(background: TokenPair, surface: TokenPair, surfaceRaised: TokenPair, separator: TokenPair,
         textPrimary: TokenPair, textSecondary: TokenPair, accent: TokenPair, onAccent: TokenPair, accentText: TokenPair) {
        self.background = background; self.surface = surface; self.surfaceRaised = surfaceRaised; self.separator = separator
        self.textPrimary = textPrimary; self.textSecondary = textSecondary
        self.accent = accent; self.onAccent = onAccent; self.accentText = accentText
        success = Palette.success; warning = Palette.warning; danger = Palette.danger
        privacyLocal = Palette.privacyLocal; privacyCloud = Palette.privacyCloud
    }

    /// The colours the app shipped with. The theme named `adiuvaret` is exactly this.
    static let standard = ThemePalette(
        background: Palette.background, surface: Palette.surface, surfaceRaised: Palette.surfaceRaised, separator: Palette.separator,
        textPrimary: Palette.textPrimary, textSecondary: Palette.textSecondary,
        accent: Palette.accent, onAccent: Palette.onAccent, accentText: Palette.accentText)
}

/// The themes the user can pick in Settings. The first one is the default and the original palette.
public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case adiuvaret, ocean, sunset, violet, rose, graphite

    public var id: String { rawValue }
    public static let `default`: AppTheme = .adiuvaret

    public var title: String {
        switch self {
        case .adiuvaret: "Green"
        case .ocean: "Ocean"
        case .sunset: "Sunset"
        case .violet: "Violet"
        case .rose: "Rose"
        case .graphite: "Graphite"
        }
    }

    /// An unknown or missing stored value gives the default.
    public static func resolve(_ raw: String?) -> AppTheme { raw.flatMap(AppTheme.init(rawValue:)) ?? .default }

    public var palette: ThemePalette {
        switch self {
        case .adiuvaret:
            return .standard
        case .ocean:
            return ThemePalette(
                background: TokenPair(light: 0xF4F8FC, dark: 0x0E1620), surface: TokenPair(light: 0xFFFFFF, dark: 0x16212E),
                surfaceRaised: TokenPair(light: 0xE6EEF6, dark: 0x1F2D3E), separator: TokenPair(light: 0xD3DEEA, dark: 0x2C3B4E),
                textPrimary: TokenPair(light: 0x13202E, dark: 0xE9F1F9), textSecondary: TokenPair(light: 0x4F6074, dark: 0x9FB1C5),
                accent: TokenPair(light: 0x3B82F6, dark: 0x4C8FFF), onAccent: TokenPair(light: 0x06172E, dark: 0x06172E),
                accentText: TokenPair(light: 0x1D4FB8, dark: 0x8DB8FF))
        case .sunset:
            return ThemePalette(
                background: TokenPair(light: 0xFBF6F1, dark: 0x1A1310), surface: TokenPair(light: 0xFFFFFF, dark: 0x251B16),
                surfaceRaised: TokenPair(light: 0xF4E8DD, dark: 0x30241D), separator: TokenPair(light: 0xE6D5C4, dark: 0x45342A),
                textPrimary: TokenPair(light: 0x2A1B12, dark: 0xF8EEE6), textSecondary: TokenPair(light: 0x6E5646, dark: 0xB8A495),
                accent: TokenPair(light: 0xF07B3F, dark: 0xFF8B50), onAccent: TokenPair(light: 0x2B1204, dark: 0x2B1204),
                accentText: TokenPair(light: 0xA8480F, dark: 0xFFA070))
        case .violet:
            return ThemePalette(
                background: TokenPair(light: 0xF8F5FC, dark: 0x14111C), surface: TokenPair(light: 0xFFFFFF, dark: 0x1D1927),
                surfaceRaised: TokenPair(light: 0xECE6F5, dark: 0x282235), separator: TokenPair(light: 0xDCD3EA, dark: 0x39314A),
                textPrimary: TokenPair(light: 0x1E1830, dark: 0xF0ECF8), textSecondary: TokenPair(light: 0x5E5575, dark: 0xADA5C2),
                accent: TokenPair(light: 0x8E6CF5, dark: 0xA68BFF), onAccent: TokenPair(light: 0x140A30, dark: 0x140A30),
                accentText: TokenPair(light: 0x5B3BC4, dark: 0xBBA5FF))
        case .rose:
            return ThemePalette(
                background: TokenPair(light: 0xFCF5F6, dark: 0x1A1113), surface: TokenPair(light: 0xFFFFFF, dark: 0x251A1D),
                surfaceRaised: TokenPair(light: 0xF6E6E9, dark: 0x312327), separator: TokenPair(light: 0xEAD3D8, dark: 0x47343A),
                textPrimary: TokenPair(light: 0x2D151B, dark: 0xF9ECEE), textSecondary: TokenPair(light: 0x70535A, dark: 0xBBA4A9),
                accent: TokenPair(light: 0xE5507A, dark: 0xFF6B93), onAccent: TokenPair(light: 0x2B0612, dark: 0x2B0612),
                accentText: TokenPair(light: 0xB02050, dark: 0xFF9DB5))
        case .graphite:
            return ThemePalette(
                background: TokenPair(light: 0xF6F6F6, dark: 0x111111), surface: TokenPair(light: 0xFFFFFF, dark: 0x1B1B1B),
                surfaceRaised: TokenPair(light: 0xEAEAEA, dark: 0x262626), separator: TokenPair(light: 0xD9D9D9, dark: 0x363636),
                textPrimary: TokenPair(light: 0x161616, dark: 0xF2F2F2), textSecondary: TokenPair(light: 0x5A5A5A, dark: 0xA3A3A3),
                accent: TokenPair(light: 0x2B2B2B, dark: 0xE8E8E8), onAccent: TokenPair(light: 0xFFFFFF, dark: 0x141414),
                accentText: TokenPair(light: 0x2B2B2B, dark: 0xE8E8E8))
        }
    }
}

/// One theme's colours as ready-made SwiftUI colours. Built once per theme, so reading a colour while a screen redraws costs a lookup.
struct ResolvedColors {
    let background: Color
    let surface: Color
    let surfaceRaised: Color
    let separator: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    let onAccent: Color
    let accentText: Color
    let success: Color
    let warning: Color
    let danger: Color
    let privacyLocal: Color
    let privacyCloud: Color
    init(_ p: ThemePalette) {
        background = dynamicColor(p.background)
        surface = dynamicColor(p.surface)
        surfaceRaised = dynamicColor(p.surfaceRaised)
        separator = dynamicColor(p.separator)
        textPrimary = dynamicColor(p.textPrimary)
        textSecondary = dynamicColor(p.textSecondary)
        accent = dynamicColor(p.accent)
        onAccent = dynamicColor(p.onAccent)
        accentText = dynamicColor(p.accentText)
        success = dynamicColor(p.success)
        warning = dynamicColor(p.warning)
        danger = dynamicColor(p.danger)
        privacyLocal = dynamicColor(p.privacyLocal)
        privacyCloud = dynamicColor(p.privacyCloud)
    }
}

/// The chosen theme. `DS.Colors` reads it, and because it is observable every screen that reads a colour repaints when it changes.
/// It is only ever set from the main thread (the Theme screen).
@Observable
public final class ThemeStore: @unchecked Sendable {
    public static let shared = ThemeStore()
    public static let key = "settings.theme"

    public var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.key) }
    }

    public var palette: ThemePalette { theme.palette }

    /// Every theme resolved at launch, so switching themes and drawing screens never builds a colour.
    private let resolved: [AppTheme: ResolvedColors]
    var colors: ResolvedColors { resolved[theme] ?? resolved[.default]! }

    private init() {
        theme = AppTheme.resolve(UserDefaults.standard.string(forKey: Self.key))
        resolved = Dictionary(uniqueKeysWithValues: AppTheme.allCases.map { ($0, ResolvedColors($0.palette)) })
    }
}
