import SwiftUI
import DesignSystem
import ToolKit

/// Advanced, Integrations: each connector with what it reads, what it changes and where data goes, and a switch.
struct IntegrationsView: View {
    @State private var states: [String: Bool] = Dictionary(uniqueKeysWithValues: ConnectorCatalog.all.map { ($0.id, ConnectorCatalog.isOn($0.id)) })
    @State private var picking = false
    @State private var folder = NoteVault.shared.folderName
    @State private var failed = false

    var body: some View {
        List {
            ForEach(ConnectorCatalog.all) { connector in
                Section {
                    Toggle(isOn: Binding(get: { states[connector.id] ?? false }, set: { states[connector.id] = $0; ConnectorCatalog.setOn($0, connector.id) })) {
                        Label { Text(verbatim: connector.title).font(DS.Typography.body) } icon: { Image(systemName: connector.symbol) }
                    }
                    .frame(minHeight: 44).accessibilityIdentifier("integration.\(connector.id)")
                    row(String(localized: "Reads"), connector.reads)
                    row(String(localized: "Changes"), connector.changes)
                    row(String(localized: "Network"), connector.network)
                    if connector.id == "notes" { folderRow }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Integrations"))
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            do { try NoteVault.shared.connect(url); folder = NoteVault.shared.folderName; failed = false } catch { failed = true }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: label).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            Text(verbatim: value).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textPrimary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var folderRow: some View {
        Button { picking = true } label: {
            Text(folder.map { String(localized: "Folder: \($0). Choose another") } ?? String(localized: "Choose your notes folder"))
                .font(DS.Typography.body).foregroundStyle(DS.Colors.accentText).frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityIdentifier("integration.notes.pick")
        if folder != nil {
            Button(String(localized: "Disconnect folder"), role: .destructive) { NoteVault.shared.disconnect(); folder = nil }.frame(minHeight: 44)
        }
        if failed { Text("That folder could not be opened.").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) }
    }
}

#Preview { NavigationStack { IntegrationsView() } }
