import SwiftUI
import DesignSystem

/// Offered after a task that used several tools. The skill is only saved when the user taps Save.
struct SkillOfferCard: View {
    enum Phase { case offered, saved, dismissed }
    let phase: Phase
    let title: String
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Label {
                Text(verbatim: phase == .saved ? String(localized: "Saved as a routine: \(title)") : String(localized: "Save this as a routine?"))
                    .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textPrimary)
            } icon: { Image(systemName: "checklist").foregroundStyle(DS.Colors.textSecondary) }
            if phase == .offered {
                Text(verbatim: title).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                Text("Next time something similar comes up, I will follow the same steps. I still ask before anything changes.")
                    .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                HStack(spacing: Spacing.xs) {
                    Button(String(localized: "Save"), action: onSave).accessibilityIdentifier("skill.save")
                    Button(String(localized: "Not now"), action: onDismiss).accessibilityIdentifier("skill.dismiss")
                }
                .buttonStyle(DSButtonStyle(.quiet)).font(DS.Typography.footnote)
            }
        }
        .padding(Spacing.m).frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.m))
    }
}

#Preview { VStack { SkillOfferCard(phase: .offered, title: "Find the next Betis match", onSave: {}, onDismiss: {}); SkillOfferCard(phase: .saved, title: "Find the next Betis match", onSave: {}, onDismiss: {}) }.padding() }
