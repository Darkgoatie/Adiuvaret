import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum DS {
    public enum Colors {
        public static let background = color(Palette.background)
        public static let surface = color(Palette.surface)
        public static let surfaceRaised = color(Palette.surfaceRaised)
        public static let separator = color(Palette.separator)
        public static let textPrimary = color(Palette.textPrimary)
        public static let textSecondary = color(Palette.textSecondary)
        public static let accent = color(Palette.accent)
        public static let onAccent = color(Palette.onAccent)
        public static let accentText = color(Palette.accentText)
        public static let success = color(Palette.success)
        public static let warning = color(Palette.warning)
        public static let danger = color(Palette.danger)
        public static let privacyLocal = color(Palette.privacyLocal)
        public static let privacyCloud = color(Palette.privacyCloud)
    }

    /// Google Sans carries chat text, Google Sans Flex headings and controls, Archivo Black the chat title only.
    /// Every size is relative to a text style so Dynamic Type scales it.
    public enum Typography {
        public static let chatTitle = Font.custom("Archivo Black", size: 20, relativeTo: .title3)
        public static let largeTitle = flex(34, .largeTitle, .bold)
        public static let title = flex(28, .title, .bold)
        public static let heading = flex(20, .title3, .semibold)
        public static let headline = flex(17, .headline, .semibold)
        public static let button = flex(17, .body, .semibold)
        public static let body = sans(17, .body)
        public static let callout = sans(16, .callout)
        public static let subheadline = sans(15, .subheadline)
        public static let footnote = sans(13, .footnote)
        public static let caption = flex(12, .caption, .medium)

        static func sans(_ size: CGFloat, _ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
            Font.custom("Google Sans", size: size, relativeTo: style).weight(weight)
        }

        static func flex(_ size: CGFloat, _ style: Font.TextStyle, _ weight: Font.Weight) -> Font {
            Font.custom("Google Sans Flex", size: size, relativeTo: style).weight(weight)
        }
    }
}

private func color(_ p: TokenPair) -> Color {
    #if canImport(UIKit)
    Color(uiColor: UIColor { trait in
        let c = trait.userInterfaceStyle == .dark ? p.dark : p.light
        return UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
    })
    #else
    Color(red: p.light.r, green: p.light.g, blue: p.light.b)
    #endif
}
