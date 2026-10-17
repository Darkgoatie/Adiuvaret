import SwiftUI
import DesignSystem

/// Settings > Theme: one row per palette with a small preview. The first one is the original palette and the default.
struct ThemeView: View {
    @Bindable private var store = ThemeStore.shared

    var body: some View {
        List {
            Section {
                ForEach(AppTheme.allCases) { theme in
                    Button { store.theme = theme } label: { row(theme) }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(store.theme == theme ? .isSelected : [])
                        .accessibilityIdentifier("theme.\(theme.rawValue)")
                }
            } footer: {
                Text("Light and dark mode still follow your phone. The green theme is the original look.")
                    .font(DS.Typography.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Theme"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ theme: AppTheme) -> some View {
        let p = theme.palette
        return HStack(spacing: Spacing.m) {
            preview(p)
            Text(verbatim: theme.title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
            if theme == AppTheme.default {
                Text("Default").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            }
            Spacer()
            if store.theme == theme {
                Image(systemName: "checkmark").foregroundStyle(DS.Colors.accentText).accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    /// A page, a card and an accent swatch in the theme's own colours (light values; the real screens follow dark mode).
    private func preview(_ p: ThemePalette) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color(rgb: p.background.light))
            Rectangle().fill(Color(rgb: p.surfaceRaised.light))
            Rectangle().fill(Color(rgb: p.accent.light))
        }
        .frame(width: 54, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: Radius.s))
        .overlay(RoundedRectangle(cornerRadius: Radius.s).stroke(DS.Colors.separator, lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

private extension Color {
    init(rgb: RGB) { self.init(red: rgb.r, green: rgb.g, blue: rgb.b) }
}
