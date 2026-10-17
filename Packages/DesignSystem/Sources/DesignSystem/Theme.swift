import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum DS {
    /// Read from the chosen theme each time, so a screen that reads a colour repaints when the theme changes.
    public enum Colors {
        public static var background: Color { color(ThemeStore.shared.palette.background) }
        public static var surface: Color { color(ThemeStore.shared.palette.surface) }
        public static var surfaceRaised: Color { color(ThemeStore.shared.palette.surfaceRaised) }
        public static var separator: Color { color(ThemeStore.shared.palette.separator) }
        public static var textPrimary: Color { color(ThemeStore.shared.palette.textPrimary) }
        public static var textSecondary: Color { color(ThemeStore.shared.palette.textSecondary) }
        public static var accent: Color { color(ThemeStore.shared.palette.accent) }
        public static var onAccent: Color { color(ThemeStore.shared.palette.onAccent) }
        public static var accentText: Color { color(ThemeStore.shared.palette.accentText) }
        public static var success: Color { color(ThemeStore.shared.palette.success) }
        public static var warning: Color { color(ThemeStore.shared.palette.warning) }
        public static var danger: Color { color(ThemeStore.shared.palette.danger) }
        public static var privacyLocal: Color { color(ThemeStore.shared.palette.privacyLocal) }
        public static var privacyCloud: Color { color(ThemeStore.shared.palette.privacyCloud) }
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
