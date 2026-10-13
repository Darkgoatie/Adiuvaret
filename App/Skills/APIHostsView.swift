import SwiftUI
import DesignSystem
import ToolKit

/// Advanced, API access: the hosts the assistant may call, how each wants its token, and the tokens (kept in the Keychain).
struct APIHostsView: View {
    private enum Style: String, CaseIterable, Identifiable {
        case none, bearer, header, query
        var id: String { rawValue }
        var title: String {
            switch self {
            case .none: String(localized: "No token")
            case .bearer: String(localized: "Bearer token")
            case .header: String(localized: "Header")
            case .query: String(localized: "Query value")
            }
        }
    }

    @State private var hosts: [APIHostEntry] = APIHostStore.shared.all()
    @State private var host = ""
    @State private var style: Style = .bearer
    @State private var fieldName = ""
    @State private var token = ""
    @State private var problem: String?
    @State private var parallelOn = SearchWebExecutor.parallelOn

    var body: some View {
        List {
            Section {
                if hosts.isEmpty {
                    Text("No hosts yet. When you ask me to use a web API, I ask before calling a new host. You can also add one here with its token.")
                        .font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                }
                ForEach(hosts) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: entry.host).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                        Text(verbatim: detail(entry)).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                    }
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("api.host.row")
                }
                .onDelete { offsets in
                    for i in offsets { APIHostStore.shared.remove(hosts[i].host) }
                    reload()
                }
            } header: { Text("Allowed hosts") } footer: {
                Text("Reading from a host runs without asking. Sending, changing or deleting always shows a card first. Swipe a host to remove it and its token.")
                    .font(DS.Typography.caption)
            }
            Section {
                TextField("api.example.com", text: $host)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    .accessibilityIdentifier("api.host.field")
                Picker("Token style", selection: $style) {
                    ForEach(Style.allCases) { Text(verbatim: $0.title).tag($0) }
                }
                if style == .header || style == .query {
                    TextField(style == .header ? "Header name, for example X-API-Key" : "Query name, for example api_key", text: $fieldName)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                if style != .none {
                    SecureField("Token", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Button(String(localized: "Add host")) { add() }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("api.host.add")
                if let problem { Text(verbatim: problem).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) }
            } header: { Text("Add a host") } footer: {
                Text("The token is stored in this iPhone's Keychain and only sent to this host. It never goes to the AI model.")
                    .font(DS.Typography.caption)
            }
            Section {
                Toggle("Use the free web search service", isOn: $parallelOn)
                    .onChange(of: parallelOn) { _, on in UserDefaults.standard.set(on, forKey: SearchWebExecutor.parallelKey) }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("websearch.parallel")
            } header: { Text("Web search") } footer: {
                Text("On: your search words go to Parallel's free search service, which returns page passages and answers questions better. Off: the built-in search reads pages on this iPhone. No account or key is needed.")
                    .font(DS.Typography.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "API access"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
    }

    private func reload() { hosts = APIHostStore.shared.all() }

    private func detail(_ entry: APIHostEntry) -> String {
        let auth = entry.style
        if !auth.needsToken { return String(localized: "No token") }
        let has = APIHostStore.shared.hasToken(entry.host)
        return has ? String(localized: "Token stored · \(auth.label)") : String(localized: "Token missing · \(auth.label)")
    }

    private func add() {
        problem = nil
        let auth: APIAuth
        switch style {
        case .none: auth = .none
        case .bearer: auth = .bearer
        case .header: auth = APIAuth.parse("header:" + fieldName) ?? .none
        case .query: auth = APIAuth.parse("query:" + fieldName) ?? .none
        }
        if (style == .header || style == .query), !auth.needsToken { problem = String(localized: "That name is not valid."); return }
        let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = clean.lowercased().hasPrefix("bearer ") ? String(clean.dropFirst(7)) : clean
        guard APIHost.normalize(host) != nil else { problem = String(localized: "Use a plain domain such as api.example.com."); return }
        if auth.needsToken, !APIToken.isPlausible(value) { problem = String(localized: "That does not look like a token."); return }
        guard APIHostStore.shared.add(host: host, auth: auth, token: value) else { problem = String(localized: "Could not save that host."); return }
        host = ""; token = ""; fieldName = ""
        reload()
    }
}

#Preview { NavigationStack { APIHostsView() } }
