import SwiftUI
import DesignSystem
import ToolKit

/// Advanced, Integrations: one icon per connector, four to a row. Tapping an icon opens that connector's own window with what it reads, what it changes, where data goes, and its settings.
struct IntegrationsView: View {
    private enum Pick: Identifiable, Hashable {
        case calendar
        case connector(String)
        var id: String { switch self { case .calendar: "calendar"; case .connector(let id): id } }
    }

    @State private var picked: Pick?
    @State private var states: [String: Bool] = IntegrationsView.readStates()
    @State private var connected: Set<String> = IntegrationsView.readConnected()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.m, alignment: .top), count: 4)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.l) {
                tile(.calendar, title: String(localized: "Calendar"), symbol: "calendar", color: IntegrationIcon.color("calendar"),
                     on: EKAuthorized.calendar)
                ForEach(ConnectorCatalog.all) { c in
                    tile(.connector(c.id), title: Self.shortTitle(c), symbol: c.symbol, color: IntegrationIcon.color(c.id), on: states[c.id] ?? false)
                }
            }
            .padding(.horizontal, Spacing.l).padding(.top, Spacing.l)
            Text("Tap an app to see what it reads and changes, where data goes, and to set it up. A green dot means it is on.")
                .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                .padding(.horizontal, Spacing.l).padding(.top, Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Integrations"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $picked, onDismiss: refresh) { pick in
            NavigationStack {
                switch pick {
                case .calendar: CalendarDetail()
                case .connector(let id): if let c = ConnectorCatalog.connector(id) { ConnectorDetail(connector: c) }
                }
            }
            .presentationDetents([.large])
        }
    }

    private func tile(_ pick: Pick, title: String, symbol: String, color: Color, on: Bool) -> some View {
        Button { picked = pick } label: {
            VStack(spacing: Spacing.xs) {
                ZStack(alignment: .topTrailing) {
                    IntegrationIcon(symbol: symbol, color: color, size: 60)
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(title), \(on ? String(localized: "on") : String(localized: "off"))"))
        .accessibilityIdentifier("integration.tile.\(pick.id)")
    }

    private func refresh() {
        states = Self.readStates()
        connected = Self.readConnected()
    }

    private static func readStates() -> [String: Bool] { Dictionary(uniqueKeysWithValues: ConnectorCatalog.all.map { ($0.id, ConnectorCatalog.isOn($0.id)) }) }
    private static func readConnected() -> Set<String> { Set(ServiceHost.hosts.keys.filter { SecretStore.has($0) }) }

    /// Short names fit under a 60 pt icon.
    private static func shortTitle(_ c: Connector) -> String {
        switch c.id {
        case "notes": String(localized: "Notes")
        case "mail": String(localized: "Mail")
        default: c.title
        }
    }
}

/// A rounded square in the app's colour with a white glyph, drawn from SF Symbols so no third-party logo is bundled.
struct IntegrationIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 60

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.225, style: .continuous).fill(color)
            .frame(width: size, height: size)
            .overlay(Image(systemName: symbol).font(.system(size: size * 0.46, weight: .medium)).foregroundStyle(.white))
            .accessibilityHidden(true)
    }

    static func color(_ id: String) -> Color {
        switch id {
        case "calendar": Color(red: 0.95, green: 0.26, blue: 0.21)
        case "notes": Color(red: 0.49, green: 0.23, blue: 0.93)
        case "contacts": Color(red: 0.56, green: 0.56, blue: 0.58)
        case "shortcuts": Color(red: 0.93, green: 0.25, blue: 0.45)
        case "mail": Color(red: 0.12, green: 0.55, blue: 0.96)
        case "todoist": Color(red: 0.89, green: 0.27, blue: 0.20)
        case "github": Color(red: 0.22, green: 0.24, blue: 0.27)
        case "notion": Color(red: 0.30, green: 0.30, blue: 0.32)
        default: Color(red: 0.16, green: 0.72, blue: 0.52)
        }
    }
}

private enum EKAuthorized {
    static var calendar: Bool { CalendarAccess.granted }
}

private struct CalendarDetail: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section {
                HStack(spacing: Spacing.m) {
                    IntegrationIcon(symbol: "calendar", color: IntegrationIcon.color("calendar"), size: 56)
                    Text("Calendar").font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                }
                .listRowBackground(Color.clear)
                info(String(localized: "Reads"), String(localized: "Events from every calendar on this iPhone, including Google and iCloud accounts you added in iOS Settings."))
                info(String(localized: "Changes"), String(localized: "Creates, moves and deletes events, after you approve."))
                info(String(localized: "Network"), String(localized: "None from Adiuvaret."))
            }
            CalendarChoiceSection()
        }
        .scrollContentBackground(.hidden).background(DS.Colors.background)
        .navigationTitle(String(localized: "Calendar")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

private func info(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: label).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
        Text(verbatim: value).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textPrimary)
    }
    .padding(.vertical, 2)
}

/// The window for one connector: header, switch, the three facts, and its own settings.
private struct ConnectorDetail: View {
    let connector: Connector
    @Environment(\.dismiss) private var dismiss
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
        List {
            Section {
                HStack(spacing: Spacing.m) {
                    IntegrationIcon(symbol: connector.symbol, color: IntegrationIcon.color(connector.id), size: 56)
                    Text(verbatim: connector.title).font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                }
                .listRowBackground(Color.clear)
                Toggle(isOn: Binding(get: { on }, set: { on = $0; ConnectorCatalog.setOn($0, connector.id) })) {
                    Text("Use \(connector.title)").font(DS.Typography.body)
                }
                .tint(DS.Colors.accent).frame(minHeight: 44)
                .accessibilityIdentifier("integration.\(connector.id)")
            }
            Section {
                info(String(localized: "Reads"), connector.reads)
                info(String(localized: "Changes"), connector.changes)
                info(String(localized: "Network"), connector.network)
            }
            if connector.id == "notes" { Section("Folder") { folderRows } }
            if ServiceHost.hosts[connector.id] != nil { Section("Token") { tokenRows } }
        }
        .scrollContentBackground(.hidden).background(DS.Colors.background)
        .navigationTitle(connector.title).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
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
