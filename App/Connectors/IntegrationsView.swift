import SwiftUI
import DesignSystem
import ToolKit

/// Advanced, Integrations: each connector with what it reads, what it changes and where data goes, and a switch.
struct IntegrationsView: View {
    @State private var states: [String: Bool] = Dictionary(uniqueKeysWithValues: ConnectorCatalog.all.map { ($0.id, ConnectorCatalog.isOn($0.id)) })
    @State private var picking = false
    @State private var folder = NoteVault.shared.folderName
    @State private var failed = false
    @State private var tokenFor: Connector?
    @State private var tokenText = ""
    @State private var tokenRejected = false
    @State private var connected: Set<String> = Set(ServiceHost.hosts.keys.filter { SecretStore.has($0) })

    var body: some View {
        List {
            CalendarChoiceSection()
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
                    if ServiceHost.hosts[connector.id] != nil { tokenRow(connector) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Integrations"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "Paste your token"), isPresented: Binding(get: { tokenFor != nil }, set: { if !$0 { tokenFor = nil; tokenText = "" } })) {
            SecureField("Token", text: $tokenText)
            Button("Save") { saveToken() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It is stored in this iPhone's Keychain and only sent to \(tokenFor.flatMap { ServiceHost.hosts[$0.id] } ?? "the service").")
        }
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

    @ViewBuilder private func tokenRow(_ connector: Connector) -> some View {
        Button { tokenFor = connector; tokenRejected = false } label: {
            Text(connected.contains(connector.id) ? String(localized: "Replace token") : String(localized: "Paste token"))
                .font(DS.Typography.body).foregroundStyle(DS.Colors.accentText).frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityIdentifier("integration.\(connector.id).token")
        if connected.contains(connector.id) {
            Button(String(localized: "Remove token"), role: .destructive) { SecretStore.delete(connector.id); connected.remove(connector.id) }.frame(minHeight: 44)
        }
        if tokenRejected, tokenFor == nil { Text("That does not look like a token.").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) }
    }

    private func saveToken() {
        guard let connector = tokenFor else { return }
        let token = ServiceToken.clean(tokenText)
        tokenText = ""
        tokenFor = nil
        guard ServiceToken.isPlausible(token), SecretStore.save(token, for: connector.id) else { tokenRejected = true; return }
        connected.insert(connector.id)
        states[connector.id] = true
        ConnectorCatalog.setOn(true, connector.id)
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
