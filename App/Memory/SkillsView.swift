import SwiftUI
import UniformTypeIdentifiers
import DesignSystem
import SkillKit

/// Every skill the assistant can use: the ones that ship with the app, ones learned from finished tasks and ones imported from a file.
struct SkillsView: View {
    @State private var skills: [AgentSkill] = SkillRegistryHub.shared.all()
    @State private var importing = false
    @State private var message: String?

    private static let types: [UTType] = [.json, .plainText, UTType(filenameExtension: "md") ?? .plainText]

    var body: some View {
        List {
            ForEach(SkillSource.allCases, id: \.self) { source in
                let rows = skills.filter { $0.source == source }
                if !rows.isEmpty {
                    Section {
                        ForEach(rows) { skill in row(skill) }
                            .onDelete { offsets in
                                for i in offsets where rows[i].source != .builtin { SkillRegistryHub.shared.remove(rows[i].id) }
                                reload()
                            }
                    } header: {
                        Text(title(source))
                    } footer: {
                        if source == .imported { Text("Imported skills are treated as untrusted text. They guide the steps and never allow anything extra.").font(DS.Typography.caption) }
                    }
                }
            }
            Section {
                Button { importing = true } label: {
                    Label("Import a skill", systemImage: "square.and.arrow.down").frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("skills.import")
            } footer: {
                Text("A skill file is JSON or Markdown with a name, a description and the steps. Swipe a skill to delete it. Built-in skills can only be switched off.")
                    .font(DS.Typography.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Skills"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .fileImporter(isPresented: $importing, allowedContentTypes: Self.types, onCompletion: importFile)
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func reload() { skills = SkillRegistryHub.shared.all() }

    private func title(_ s: SkillSource) -> String {
        switch s {
        case .builtin: String(localized: "Built in")
        case .user: String(localized: "Added by you")
        case .learned: String(localized: "Learned routines")
        case .imported: String(localized: "Imported")
        }
    }

    private func row(_ skill: AgentSkill) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: Binding(get: { skill.enabled }, set: { SkillRegistryHub.shared.setEnabled(skill.id, $0); reload() })) {
                Text(verbatim: skill.name).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
            }
            Text(verbatim: skill.description).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            if !skill.allowedTools.isEmpty {
                Text(verbatim: skill.allowedTools.joined(separator: ", ")).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("skills.row")
        .deleteDisabled(skill.source == .builtin)
    }

    private func importFile(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { message = String(localized: "That file couldn't be read."); return }
        do {
            let skill = try SkillImport.parse(data)
            try SkillRegistryHub.shared.register(skill)
            message = String(localized: "Added \(skill.name).")
        } catch let e as SkillImportError {
            switch e {
            case .tooLarge: message = String(localized: "That file is too large for a skill.")
            case .unreadable: message = String(localized: "That file isn't a skill. Use JSON or Markdown.")
            case .missing(let what): message = String(localized: "The skill needs a \(what).")
            }
        } catch let e as SkillError {
            switch e {
            case .duplicate: message = String(localized: "A skill with that name already exists.")
            case .unknownTool(let t): message = String(localized: "The skill names a tool that doesn't exist: \(t).")
            case .full: message = String(localized: "There is no room for more skills.")
            default: message = String(localized: "That skill couldn't be added.")
            }
        } catch {
            message = String(localized: "That skill couldn't be added.")
        }
        reload()
    }
}

#Preview { NavigationStack { SkillsView() } }
