import SwiftUI
import DesignSystem

struct DesignGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Plan my week").font(DS.Typography.chatTitle).foregroundStyle(DS.Colors.textPrimary)
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Large title").font(DS.Typography.largeTitle)
                    Text("Heading in Google Sans Flex").font(DS.Typography.heading)
                    Text("Body text in Google Sans. Tuesday 3:00 PM is free, so I can put the dentist there.").font(DS.Typography.body)
                    Text("Secondary line, 13 pt footnote").font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    Text("On your iPhone").font(DS.Typography.caption).foregroundStyle(DS.Colors.privacyLocal)
                }
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text("I'd like to add Call mom to Reminders for 6 PM.").font(DS.Typography.body)
                    HStack(spacing: Spacing.s) {
                        Button("Deny") {}.buttonStyle(GalleryButton(fill: false))
                        Button("Approve") {}.buttonStyle(GalleryButton(fill: true))
                    }
                }
                .padding(Spacing.l)
                .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: Radius.l))
                HStack(spacing: Spacing.s) {
                    ForEach(["background", "surface", "accent", "accentText"], id: \.self) { n in
                        RoundedRectangle(cornerRadius: Radius.s).fill(swatch(n)).frame(height: 44)
                            .overlay(RoundedRectangle(cornerRadius: Radius.s).stroke(DS.Colors.separator))
                    }
                }
            }
            .foregroundStyle(DS.Colors.textPrimary)
            .padding(Spacing.l)
        }
        .background(DS.Colors.background)
        .navigationTitle("Design")
    }

    private func swatch(_ n: String) -> Color {
        switch n {
        case "background": DS.Colors.background
        case "surface": DS.Colors.surface
        case "accent": DS.Colors.accent
        case "accentText": DS.Colors.accentText
        default: DS.Colors.accentText
        }
    }
}

private struct GalleryButton: ButtonStyle {
    let fill: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.button)
            .foregroundStyle(fill ? DS.Colors.onAccent : DS.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(fill ? DS.Colors.accent : DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.m))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
