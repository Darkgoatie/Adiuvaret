import SwiftUI
import DesignSystem
import SkillKit

/// Advanced, Skills: what the assistant was taught. Each skill shows its hosts and tools; nothing here holds a token.
struct TaughtSkillsView: View {
    @State private var skills: [TaughtSkill] = TaughtSkillHub.store.all()
    @State private var confirmClear = false

    var body: some View {
        List {
            Section {
                if skills.isEmpty {
                    Text("Nothing taught yet. Ask me to do something on a web service, send me its documentation or let me find it, and after it works I offer to save it as a skill.")
                        .font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                }
                ForEach(skills) { skill in row(skill) }
                    .onDelete { offsets in
                        for i in offsets { TaughtSkillHub.store.remove(skills[i].id) }
                        reload()
                    }
            } footer: {
                Text("A skill is saved instructions, never a password or token. It guides the steps; sending or changing anything still asks you. Swipe a skill to delete it.")
                    .font(DS.Typography.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Skills"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
    }

    private func reload() { skills = TaughtSkillHub.store.all() }

    private func row(_ skill: TaughtSkill) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(get: { skill.enabled }, set: { TaughtSkillHub.store.setEnabled(skill.id, $0); reload() })) {
                Text(verbatim: skill.name).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
            }
            Text(verbatim: skill.description).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            if !skill.hosts.isEmpty {
                Text(verbatim: skill.hosts.joined(separator: ", ")).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            }
            Text(verbatim: skill.instructions).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary).lineLimit(4)
        }
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityIdentifier("taught.row")
    }
}

#Preview { NavigationStack { TaughtSkillsView() } }
