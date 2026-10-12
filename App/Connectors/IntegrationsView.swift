import SwiftUI
import DesignSystem
import ToolKit

/// One app inside a company, with its own icon and settings window.
private struct AppItem: Identifiable, Hashable {
    enum Kind: Hashable { case appleCalendar, googleCalendar, gmail, connector(String) }
    let id: String
    let title: String
    let icon: IntegrationIcon.Kind
    let kind: Kind

    var isOn: Bool {
        switch kind {
        case .appleCalendar, .googleCalendar: CalendarAccess.granted
        case .gmail: false
        case .connector(let id): ConnectorCatalog.isOn(id)
        }
    }
}

/// A company. Apps from the same company share one icon on the first screen and open an apps menu of their own. Apple apps are the exception: each one has its own icon.
private struct AppGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: IntegrationIcon.Kind
    let apps: [AppItem]

    var isOn: Bool { apps.contains(where: \.isOn) }

    private static let red = Color(red: 0.95, green: 0.26, blue: 0.21)
    private static let blue = Color(red: 0.12, green: 0.55, blue: 0.96)

    /// A company with one app: its icon opens the app directly.
    private static func single(_ id: String, _ title: String, _ icon: IntegrationIcon.Kind, _ kind: AppItem.Kind) -> AppGroup {
        AppGroup(id: id, title: title, icon: icon, apps: [AppItem(id: id, title: title, icon: icon, kind: kind)])
    }

    static let all: [AppGroup] = [
        single("appleCalendar", String(localized: "Calendar"), .symbol("calendar", red), .appleCalendar),
        single("contacts", String(localized: "Contacts"), .symbol("person.crop.circle", Color(red: 0.56, green: 0.56, blue: 0.58)), .connector("contacts")),
        single("shortcuts", String(localized: "Shortcuts"), .symbol("square.stack.3d.up.fill", Color(red: 0.93, green: 0.25, blue: 0.45)), .connector("shortcuts")),
        single("mail", String(localized: "Mail"), .symbol("envelope.fill", blue), .connector("mail")),
        AppGroup(id: "google", title: String(localized: "Google Apps"), icon: .brand("brand-google", Color(red: 0.26, green: 0.52, blue: 0.96)), apps: [
            AppItem(id: "googleCalendar", title: String(localized: "Google Calendar"), icon: .brand("brand-googlecalendar", Color(red: 0.26, green: 0.52, blue: 0.96)), kind: .googleCalendar),
            AppItem(id: "gmail", title: String(localized: "Gmail"), icon: .brand("brand-gmail", Color(red: 0.92, green: 0.26, blue: 0.21)), kind: .gmail),
        ]),
        AppGroup(id: "obsidian", title: String(localized: "Obsidian"), icon: .brand("brand-obsidian", Color(red: 0.49, green: 0.23, blue: 0.93)), apps: [
            AppItem(id: "notes", title: String(localized: "Obsidian"), icon: .brand("brand-obsidian", Color(red: 0.49, green: 0.23, blue: 0.93)), kind: .connector("notes"))]),
        AppGroup(id: "todoist", title: String(localized: "Todoist"), icon: .brand("brand-todoist", Color(red: 0.89, green: 0.27, blue: 0.20)), apps: [
            AppItem(id: "todoist", title: String(localized: "Todoist"), icon: .brand("brand-todoist", Color(red: 0.89, green: 0.27, blue: 0.20)), kind: .connector("todoist"))]),
        AppGroup(id: "github", title: String(localized: "GitHub"), icon: .brand("brand-github", Color(red: 0.09, green: 0.09, blue: 0.09)), apps: [
            AppItem(id: "github", title: String(localized: "GitHub"), icon: .brand("brand-github", Color(red: 0.09, green: 0.09, blue: 0.09)), kind: .connector("github"))]),
        AppGroup(id: "notion", title: String(localized: "Notion"), icon: .brand("brand-notion", .black), apps: [
            AppItem(id: "notion", title: String(localized: "Notion"), icon: .brand("brand-notion", .black), kind: .connector("notion"))]),
    ]

}

/// A tile in a four-column grid: icon, optional green dot, name underneath.
private struct IconTile: View {
    let title: String
    let icon: IntegrationIcon.Kind
    let on: Bool
    let identifier: String

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                IntegrationIcon(kind: icon, size: 60)
                if on {
                    Circle().fill(DS.Colors.success).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(DS.Colors.background, lineWidth: 2))
                        .offset(x: 4, y: -4)
                }
            }
            Text(verbatim: title).font(DS.Typography.caption).foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(2).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(title), \(on ? String(localized: "on") : String(localized: "off"))"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(identifier)
    }
}

private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: Spacing.m, alignment: .top), count: 4)

/// Advanced, Integrations: one icon per company, four to a row. A company with several apps opens its own apps menu in the same layout; a single app opens its window directly.
struct IntegrationsView: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: Spacing.l) {
                ForEach(AppGroup.all) { g in
                    NavigationLink {
                        if g.apps.count == 1 { AppDetail(app: g.apps[0]) } else { GroupMenu(group: g) }
                    } label: {
                        IconTile(title: g.title, icon: g.icon, on: g.isOn, identifier: "integration.tile.\(g.id)")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.l).padding(.top, Spacing.l)
            Text("Tap an icon to open it. A green dot means something in it is on.")
                .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                .padding(.horizontal, Spacing.l).padding(.top, Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Integrations"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The apps menu of one company: only its apps, four to a row.
private struct GroupMenu: View {
    let group: AppGroup

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: Spacing.l) {
                ForEach(group.apps) { a in
                    NavigationLink {
                        AppDetail(app: a)
                    } label: {
                        IconTile(title: a.title, icon: a.icon, on: a.isOn, identifier: "integration.app.\(a.id)")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.l).padding(.top, Spacing.l)
        }
        .background(DS.Colors.background)
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// An app icon: Apple's own SF Symbol on black for Apple apps, otherwise the company's logo mark in its brand colour on a light tile.
struct IntegrationIcon: View {
    enum Kind: Hashable { case symbol(String, Color), brand(String, Color) }
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

/// The window for one app: icon and name, then what it reads and changes, and its settings.
private struct AppDetail: View {
    let app: AppItem

    var body: some View {
        List {
            Section {
                HStack(spacing: Spacing.m) {
                    IntegrationIcon(kind: app.icon, size: 56)
                    Text(verbatim: app.title).font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                }
                .listRowBackground(Color.clear)
            }
            switch app.kind {
            case .appleCalendar: AppleCalendarBlock()
            case .googleCalendar: GoogleCalendarBlock()
            case .gmail: GmailBlock()
            case .connector(let id): if let c = ConnectorCatalog.connector(id) { ConnectorBlock(connector: c) }
            }
        }
        .scrollContentBackground(.hidden).background(DS.Colors.background)
        .navigationTitle(app.title).navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppleCalendarBlock: View {
    var body: some View {
        Section {
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
