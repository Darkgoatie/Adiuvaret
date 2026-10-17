import Testing
@testable import DesignSystem

@Suite struct ThemeTests {
    private func pairs(_ p: ThemePalette) -> [(String, TokenPair)] {
        [("background", p.background), ("surface", p.surface), ("raised", p.surfaceRaised), ("separator", p.separator),
         ("textPrimary", p.textPrimary), ("textSecondary", p.textSecondary), ("accent", p.accent), ("onAccent", p.onAccent),
         ("accentText", p.accentText), ("success", p.success), ("warning", p.warning), ("danger", p.danger),
         ("privacyLocal", p.privacyLocal), ("privacyCloud", p.privacyCloud)]
    }

    @Test func theDefaultIsTheOriginalPalette() {
        #expect(AppTheme.default == .adiuvaret && AppTheme.allCases.first == .adiuvaret)
        let p = AppTheme.adiuvaret.palette
        let o = ThemePalette.standard
        for ((n, a), (_, b)) in zip(pairs(p), pairs(o)) {
            #expect(a.light == b.light && a.dark == b.dark, Comment(rawValue: n))
        }
        #expect(p.accent.light == RGB(hex: 0x2AB985) && p.background.light == RGB(hex: 0xFAF7F2) && p.background.dark == RGB(hex: 0x171512))
    }

    @Test func storedValueFallsBackToTheDefault() {
        #expect(AppTheme.resolve(nil) == .adiuvaret && AppTheme.resolve("nonsense") == .adiuvaret)
        for t in AppTheme.allCases { #expect(AppTheme.resolve(t.rawValue) == t) }
    }

    @Test func everyThemeHasADistinctTitleAndAccent() {
        #expect(Set(AppTheme.allCases.map(\.title)).count == AppTheme.allCases.count)
        #expect(Set(AppTheme.allCases.map { $0.palette.accent.light.r * 1000 + $0.palette.accent.light.g * 100 + $0.palette.accent.light.b }).count == AppTheme.allCases.count)
    }

    @Test(arguments: AppTheme.allCases) func textMeetsAAInEveryTheme(_ theme: AppTheme) {
        let p = theme.palette
        let text: [(String, TokenPair)] = [("textPrimary", p.textPrimary), ("textSecondary", p.textSecondary), ("accentText", p.accentText),
                                           ("success", p.success), ("warning", p.warning), ("danger", p.danger),
                                           ("privacyLocal", p.privacyLocal), ("privacyCloud", p.privacyCloud)]
        for (name, pair) in text {
            for (bg, label) in [(p.background, "background"), (p.surface, "surface")] {
                #expect(pair.light.contrast(with: bg.light) >= 4.5, Comment(rawValue: "\(theme) \(name) light on \(label)"))
                #expect(pair.dark.contrast(with: bg.dark) >= 4.5, Comment(rawValue: "\(theme) \(name) dark on \(label)"))
            }
        }
        for t in [p.textPrimary, p.textSecondary] {
            #expect(t.light.contrast(with: p.surfaceRaised.light) >= 4.5 && t.dark.contrast(with: p.surfaceRaised.dark) >= 4.5, Comment(rawValue: "\(theme) on raised"))
        }
    }

    @Test(arguments: AppTheme.allCases) func labelOnAccentFillMeetsAA(_ theme: AppTheme) {
        let p = theme.palette
        #expect(p.onAccent.light.contrast(with: p.accent.light) >= 4.5, Comment(rawValue: "\(theme) light"))
        #expect(p.onAccent.dark.contrast(with: p.accent.dark) >= 4.5, Comment(rawValue: "\(theme) dark"))
    }

    @Test(arguments: AppTheme.allCases) func accentStandsOutFromThePage(_ theme: AppTheme) {
        let p = theme.palette
        #expect(p.accent.light.contrast(with: p.background.light) >= 1.8, Comment(rawValue: "\(theme) light"))
        #expect(p.accent.dark.contrast(with: p.background.dark) >= 1.8, Comment(rawValue: "\(theme) dark"))
    }
}
