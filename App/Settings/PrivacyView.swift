import SwiftUI
import DesignSystem
import ModelLibrary
import ToolKit
import PolicyEngine
import Diagnostics

/// Settings, Privacy: what stays on the phone, what can leave it, and the buttons that erase things. It reads live state, so it cannot drift from what the app does.
struct PrivacyView: View {
    @Bindable private var settings = AppSettings.shared
    @Bindable private var providers = ProviderStore.shared
    @State private var confirm: Erase?

    private enum Erase: String, Identifiable {
        case browsing, memory, activity, diagnostics, siteNotes, apiHosts, skills
        var id: String { rawValue }
    }

    var body: some View {
        List {
            Section {
                Text("Chats, memory, notes and settings live on this iPhone. Nothing is sent anywhere unless one of the items below is on. You can see every one of them here.")
                    .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    .listRowBackground(Color.clear)
            }
            Section {
                if AppleModel.isAvailable { item("iphone", String(localized: "Apple model"), String(localized: "Runs on this iPhone. Nothing leaves it.")) }
                item("cpu", String(localized: "Downloaded models"), String(localized: "Run on this iPhone. Only the download itself uses the internet, from Hugging Face."))
                if providers.connected.isEmpty {
                    item("cloud", String(localized: "Online models"), String(localized: "None connected."))
                } else {
                    item("cloud", String(localized: "Online models"), String(localized: "Connected: \(connectedNames). Chats with these models, and anything a tool reads for them, are sent to that company."))
                }
            } header: { Text("Models") }
            Section {
                ForEach(InfoCategory.allCases) { category in
                    item(category.symbol, category.title, String(localized: "Asks \(SourceSettings.shared.selected(category).name). \(SourceSettings.shared.selected(category).sends)"))
                }
            } header: { Text("Built-in information sources") } footer: {
                Text("Change which source is asked first in Settings, Preferences.").font(DS.Typography.caption)
            }
            Section {
                ForEach(ConnectorCatalog.all) { c in
                    item(c.symbol, c.title, (ConnectorCatalog.isOn(c.id) ? String(localized: "On. ") : String(localized: "Off. ")) + c.network)
                }
            } header: { Text("Connected apps") } footer: {
                Text("Switch them on or off in Advanced, Integrations.").font(DS.Typography.caption)
            }
            Section {
                item("globe", String(localized: "Websites"), settings.strictWeb
                     ? String(localized: "I ask before opening a site I have not visited in the chat.")
                     : String(localized: "I open sites you name or that a search finds. Searches have emails, phone numbers and words from your calendar removed first."))
                item("hand.raised", String(localized: "Actions"), settings.actionsOff
                     ? String(localized: "Switched off. I can talk, but I use no tools.")
                     : String(localized: "On. Changes to your calendar, reminders, notes and tasks ask first, and most can be undone."))
            } header: { Text("Web and actions") }
            Section {
                eraseRow(String(localized: "Clear browsing data"), String(localized: "Signs you out of websites and removes cookies."), .browsing)
                eraseRow(String(localized: "Forget saved site routes"), String(localized: "Removes the link names kept for faster visits."), .siteNotes)
                eraseRow(String(localized: "Forget everything I know about you"), String(localized: "Deletes the saved facts."), .memory)
                eraseRow(String(localized: "Remove API hosts and tokens"), String(localized: "Forgets every host the assistant may call and its token."), .apiHosts)
                eraseRow(String(localized: "Delete taught skills"), String(localized: "Removes every skill the assistant was taught."), .skills)
                eraseRow(String(localized: "Clear the activity log"), String(localized: "Removes the list of tool calls."), .activity)
                eraseRow(String(localized: "Clear diagnostics"), String(localized: "Removes the timing and error log."), .diagnostics)
            } header: { Text("Erase") } footer: {
                Text("Keys and tokens for online models and connected apps sit in this iPhone's Keychain. Remove them in Settings, Providers or Advanced, Integrations.").font(DS.Typography.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Privacy"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(confirm.map { title(for: $0) } ?? "", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }), titleVisibility: .visible) {
            Button(String(localized: "Erase"), role: .destructive) { if let c = confirm { run(c) } }
        } message: { Text("This cannot be undone.") }
    }

    private var connectedNames: String {
        Providers.all.filter { providers.isConnected($0.id) }.map(\.name).joined(separator: ", ")
    }

    private func item(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: symbol).foregroundStyle(DS.Colors.textSecondary).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                Text(verbatim: detail).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func eraseRow(_ title: String, _ detail: String, _ kind: Erase) -> some View {
        Button(role: .destructive) { confirm = kind } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(DS.Typography.body)
                Text(verbatim: detail).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityIdentifier("privacy.\(kind.rawValue)")
    }

    private func title(for kind: Erase) -> String {
        switch kind {
        case .browsing: String(localized: "Clear browsing data?")
        case .siteNotes: String(localized: "Forget saved site routes?")
        case .memory: String(localized: "Forget everything I know about you?")
        case .apiHosts: String(localized: "Remove API hosts and tokens?")
        case .skills: String(localized: "Delete taught skills?")
        case .activity: String(localized: "Clear the activity log?")
        case .diagnostics: String(localized: "Clear diagnostics?")
        }
    }

    private func run(_ kind: Erase) {
        switch kind {
        case .browsing: Task { await WebSession.shared.clearWebsiteData() }
        case .siteNotes: SiteNoteStore.shared.clear()
        case .memory: MemoryHub.store.removeAll()
        case .apiHosts: APIHostStore.shared.removeAll()
        case .skills: TaughtSkillHub.store.removeAll()
        case .activity: ActivityStore.shared.clear()
        case .diagnostics: DiagnosticsLog.shared.clear()
        }
        confirm = nil
    }
}
