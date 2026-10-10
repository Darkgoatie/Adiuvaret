import SwiftUI
import DesignSystem
import MemoryKit

/// "What I know about you": every saved fact, editable and deletable.
struct MemoryView: View {
    @State private var facts: [MemoryFact] = MemoryHub.store.all()
    @State private var skills: [Skill] = SkillHub.store.all()
    @State private var editing: MemoryFact?
    @State private var draft = ""
    @State private var confirmClear = false

    var body: some View {
        List {
            skillsSection
            if facts.isEmpty {
                Text("Nothing yet. When you tell me something about yourself, such as where you live or what you like, I keep it here and you can change or delete it.")
                    .font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
            } else {
                Section {
                    ForEach(facts) { fact in
                        Button { editing = fact; draft = fact.text } label: {
                            Text(verbatim: fact.text).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary).frame(minHeight: 44, alignment: .leading)
                        }
                        .accessibilityIdentifier("memory.fact")
                    }
                    .onDelete { offsets in
                        for i in offsets { MemoryHub.store.remove(facts[i].id) }
                        reload()
                    }
                } footer: {
                    Text("\(facts.count) of \(MemoryLimits.maxFacts) facts. Everything stays on this iPhone. Tap a fact to edit it, swipe to delete.")
                        .font(DS.Typography.caption)
                }
                Section {
                    Button("Forget everything", role: .destructive) { confirmClear = true }.frame(minHeight: 44)
                        .accessibilityIdentifier("memory.clear")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "What I know about you"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .alert("Edit fact", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField("Fact", text: $draft)
            Button("Save") { if let e = editing { MemoryHub.store.update(e.id, text: draft); reload() } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Forget everything?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Forget everything", role: .destructive) { MemoryHub.store.removeAll(); reload() }
        } message: { Text("All saved facts will be deleted.") }
    }

    private func reload() { facts = MemoryHub.store.all(); skills = SkillHub.store.all() }

    @ViewBuilder private var skillsSection: some View {
        if !skills.isEmpty {
            Section {
                ForEach(skills) { skill in
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle(isOn: Binding(get: { skill.enabled }, set: { SkillHub.store.setEnabled(skill.id, $0); reload() })) {
                            Text(verbatim: skill.title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                        }
                        Text(verbatim: skill.playbook).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                    }
                    .frame(minHeight: 44).accessibilityIdentifier("memory.skill")
                }
                .onDelete { offsets in
                    for i in offsets { SkillHub.store.remove(skills[i].id) }
                    reload()
                }
            } header: {
                Text("Routines")
            } footer: {
                Text("\(skills.count) of \(SkillLimits.maxSkills) routines. They only guide the steps. I still ask before anything changes. Swipe to delete.")
            }
        }
    }
}

#Preview { NavigationStack { MemoryView() } }
