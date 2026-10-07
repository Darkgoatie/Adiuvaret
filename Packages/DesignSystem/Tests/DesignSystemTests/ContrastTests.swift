import Testing
@testable import DesignSystem

@Suite struct Contrast {
    static let textPairs: [(String, TokenPair)] = [
        ("textPrimary", Palette.textPrimary), ("textSecondary", Palette.textSecondary),
        ("accentText", Palette.accentText), ("success", Palette.success), ("warning", Palette.warning),
        ("danger", Palette.danger), ("privacyLocal", Palette.privacyLocal), ("privacyCloud", Palette.privacyCloud),
    ]

    @Test(arguments: textPairs) func textMeetsAA(_ name: String, _ pair: TokenPair) {
        for (bg, label) in [(Palette.background, "background"), (Palette.surface, "surface")] {
            #expect(pair.light.contrast(with: bg.light) >= 4.5, "\(name) light on \(label)")
            #expect(pair.dark.contrast(with: bg.dark) >= 4.5, "\(name) dark on \(label)")
        }
    }

    @Test func labelOnAccentFillMeetsAA() {
        #expect(Palette.onAccent.light.contrast(with: Palette.accent.light) >= 4.5)
        #expect(Palette.onAccent.dark.contrast(with: Palette.accent.dark) >= 4.5)
    }

    @Test func accentIsTheBrandGreen() {
        #expect(Palette.accent.light == RGB(hex: 0x2AB985))
    }
}
