import SwiftUI
import DesignSystem
import ToolKit

/// What one icon stands for. Apps from the same company share one icon and one window.
private struct AppGroup: Identifiable {
    enum Member: Hashable { case appleCalendar, googleCalendar, gmail, connector(String) }
    let id: String
    let title: String
    let icon: IntegrationIcon.Kind
    let members: [Member]

    static let all: [AppGroup] = [
        AppGroup(id: "apple", title: String(localized: "Apple Apps"), icon: .symbol("apple.logo", .black),
                 members: [.appleCalendar, .connector("contacts"), .connector("shortcuts"), .connector("mail")]),
        AppGroup(id: "google", title: String(localized: "Google Apps"), icon: .brand("brand-google", Color(red: 0.26, green: 0.52, blue: 0.96)),
                 members: [.googleCalendar, .gmail]),
        AppGroup(id: "obsidian", title: String(localized: "Obsidian"), icon: .brand("brand-obsidian", Color(red: 0.49, green: 0.23, blue: 0.93)),
                 members: [.connector("notes")]),
        AppGroup(id: "todoist", title: String(localized: "Todoist"), icon: .brand("brand-todoist", Color(red: 0.89, green: 0.27, blue: 0.20)),
                 members: [.connector("todoist")]),
        AppGroup(id: "github", title: String(localized: "GitHub"), icon: .brand("brand-github", Color(red: 0.09, green: 0.09, blue: 0.09)),
                 members: [.connector("github")]),
        AppGroup(id: "notion", title: String(localized: "Notion"), icon: .brand("brand-notion", .black),
                 members: [.connector("notion")]),
    ]

    /// True when any app in the group is switched on.
    var isOn: Bool {
        members.contains { m in
            switch m {
            case .appleCalendar, .googleCalendar: CalendarAccess.granted
            case .gmail: false
            case .connector(let id): ConnectorCatalog.isOn(id)
            }
        }
    }
}

/// Advanced, Integrations: one icon per company, four to a row. Tapping an icon opens a window with every app of that company: what it reads and changes, where data goes, and its settings.
struct IntegrationsView: View {
    @State private var picked: AppGroup?
    @State private var refreshID = UUID()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.m, alignment: .top), count: 4)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.l) {
                ForEach(AppGroup.all) { g in tile(g) }
            }
            .id(refreshID)
            .padding(.horizontal, Spacing.l).padding(.top, Spacing.l)
            Text("Tap an icon to see what an app reads and changes, where data goes, and to set it up. A green dot means something in the group is on.")
                .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                .padding(.horizontal, Spacing.l).padding(.top, Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Integrations"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $picked, onDismiss: { refreshID = UUID() }) { g in
            NavigationStack { GroupDetail(group: g) }.presentationDetents([.large])
        }
    }

    private func tile(_ g: AppGroup) -> some View {
        let on = g.isOn
        return Button { picked = g } label: {
            VStack(spacing: Spacing.xs) {
                ZStack(alignment: .topTrailing) {
                    IntegrationIcon(kind: g.icon, size: 60)
                    if on {
                        Circle().fill(DS.Colors.success).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(DS.Colors.background, lineWidth: 2))
                            .offset(x: 4, y: -4)
                    }
                }
                Text(verbatim: g.title).font(DS.Typography.caption).foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(2).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(g.title), \(on ? String(localized: "on") : String(localized: "off"))"))
        .accessibilityIdentifier("integration.tile.\(g.id)")
    }
}

/// An app icon: Apple's own SF Symbol on black for Apple apps, otherwise the company's logo mark in its brand colour on a light tile.
struct IntegrationIcon: View {
    enum Kind { case symbol(String, Color), brand(String, Color) }
    let kind: Kind
    var size: CGFloat = 60

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        switch kind {
        case .symbol(let name, let color):
            shape.fill(color).frame(width: size, height: size)
                .overlay(Image(systemName: name).font(.system(size: size * 0.5, weight: .medium)).foregroundStyle(.white))
                .accessibilityHidden(true)
        case .brand(let asset, let color):
            shape.fill(Color.white).frame(width: size, height: size)
                .overlay(shape.stroke(DS.Colors.separator, lineWidth: 1))
                .overlay(Image(asset).renderingMode(.template).resizable().scaledToFit().frame(width: size * 0.5, height: size * 0.5).foregroundStyle(color))
                .accessibilityHidden(true)
        }
    }
}

private func info(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: label).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
        Text(verbatim: value).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textPrimary)
    }
    .padding(.vertical, 2)
}

/// The window for one company: its icon and name, then a block for every app in it.
private struct GroupDetail: View {
    let group: AppGroup
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                HStack(spacing: Spacing.m) {
                    IntegrationIcon(kind: group.icon, size: 56)
                    Text(verbatim: group.title).font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                }
                .listRowBackground(Color.clear)
            }
            ForEach(group.members, id: \.self) { m in
                switch m {
                case .appleCalendar: AppleCalendarBlock()
                case .googleCalendar: GoogleCalendarBlock()
                case .gmail: GmailBlock()
                case .connector(let id): if let c = ConnectorCatalog.connector(id) { ConnectorBlock(connector: c) }
                }
            }
        }
        .scrollContentBackground(.hidden).background(DS.Colors.background)
        .navigationTitle(group.title).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

private struct AppleCalendarBlock: View {
    var body: some View {
        Section {
            Label { Text("Calendar and Reminders").font(DS.Typography.headline) } icon: { Image(systemName: "calendar") }
            info(String(localized: "Reads"), String(localized: "Events from every calendar on this iPhone, and your open reminders."))
            info(String(localized: "Changes"), String(localized: "Creates, moves and deletes events and creates reminders, after you approve."))
            info(String(localized: "Network"), String(localized: "None from Adiuvaret."))
        }
        CalendarChoiceSection()
    }
}

private struct GoogleCalendarBlock: View {
    var body: some View {
        Section {
            Label { Text("Google Calendar").font(DS.Typography.headline) } icon: { Image(systemName: "calendar") }
            info(String(localized: "Reads"), String(localized: "Events from your Google account, through the calendar on this iPhone."))
            info(String(localized: "Changes"), String(localized: "Same as Apple Calendar: new events are saved where you chose above, after you approve."))
            info(String(localized: "Network"), String(localized: "None from Adiuvaret. iOS syncs the account."))
            info(String(localized: "Set up"), String(localized: "Add your Google account in the iOS Settings app under Calendar, Accounts, Add Account, and switch Calendars on."))
        }
    }
}

private struct GmailBlock: View {
    var body: some View {
        Section {
            Label { Text("Gmail").font(DS.Typography.headline) } icon: { Image(systemName: "envelope") }
            info(String(localized: "Status"), String(localized: "Not available yet. Reading mail needs a Google sign-in that is not set up."))
        }
    }
}

/// One connector inside a company window: switch, the three facts, and its own settings.
private struct ConnectorBlock: View {
    let connector: Connector
    @State private var on: Bool
    @State private var picking = false
    @State private var folder = NoteVault.shared.folderName
    @State private var failed = false
    @State private var askToken = false
    @State private var tokenText = ""
    @State private var tokenRejected = false
    @State private var hasToken: Bool

    init(connector: Connector) {
        self.connector = connector
        _on = State(initialValue: ConnectorCatalog.isOn(connector.id))
        _hasToken = State(initialValue: SecretStore.has(connector.id))
    }

    var body: some View {
        Group {
            Section {
                Label { Text(verbatim: connector.title).font(DS.Typography.headline) } icon: { Image(systemName: connector.symbol) }
                Toggle(isOn: Binding(get: { on }, set: { on = $0; ConnectorCatalog.setOn($0, connector.id) })) {
                    Text("Use \(connector.title)").font(DS.Typography.body)
                }
                .tint(DS.Colors.accent).frame(minHeight: 44)
                .accessibilityIdentifier("integration.\(connector.id)")
                info(String(localized: "Reads"), connector.reads)
                info(String(localized: "Changes"), connector.changes)
                info(String(localized: "Network"), connector.network)
                if connector.id == "notes" { folderRows }
                if ServiceHost.hosts[connector.id] != nil { tokenRows }
            }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            do { try NoteVault.shared.connect(url); folder = NoteVault.shared.folderName; failed = false } catch { failed = true }
        }
        .alert(String(localized: "Paste your token"), isPresented: $askToken) {
            SecureField("Token", text: $tokenText)
            Button("Save") { saveToken() }
            Button("Cancel", role: .cancel) { tokenText = "" }
        } message: {
            Text("It is stored in this iPhone's Keychain and only sent to \(ServiceHost.hosts[connector.id] ?? "the service").")
        }
    }

    @ViewBuilder private var tokenRows: some View {
        Button { tokenRejected = false; askToken = true } label: {
            Text(hasToken ? String(localized: "Replace token") : String(localized: "Paste token"))
                .font(DS.Typography.body).foregroundStyle(DS.Colors.accentText).frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityIdentifier("integration.\(connector.id).token")
        if hasToken {
            Button(String(localized: "Remove token"), role: .destructive) { SecretStore.delete(connector.id); hasToken = false }.frame(minHeight: 44)
        }
        if tokenRejected { Text("That does not look like a token.").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) }
    }

    private func saveToken() {
        let token = ServiceToken.clean(tokenText)
        tokenText = ""
        guard ServiceToken.isPlausible(token), SecretStore.save(token, for: connector.id) else { tokenRejected = true; return }
        hasToken = true; on = true
        ConnectorCatalog.setOn(true, connector.id)
    }

    @ViewBuilder private var folderRows: some View {
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
