import SwiftUI
import DesignSystem
import Persistence
import ModelLibrary

struct RootView: View {
    @State private var drawerOpen = false
    @State private var path: [Route] = []
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = ChatStore(persistence: Self.demoLaunch ? nil : try? PersistenceStore()) { RootView.makeService(.empty) }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
            if CommandLine.arguments.contains("-nodrawer") {
                ChatView(service: store.current, openDrawer: {}, turnFinished: {}).id(store.currentID)
                    .toolbar(.hidden, for: .navigationBar)
            } else {
            DrawerContainer(isOpen: $drawerOpen) {
                ChatView(service: store.current, openDrawer: { drawerOpen = true }, turnFinished: { store.persistCurrent() },
                         switchModel: { id in ModelSettings.shared.select(id); store.switchModel(to: id) }, openModels: { handle(.models) })
                    .id(store.currentID)
            } drawer: {
                DrawerView(chats: store.summaries, activeID: store.currentID, isOpen: drawerOpen, pendingApprovals: 1,
                           select: { route in handle(route) },
                           pin: { store.togglePin($0) },
                           delete: { store.delete($0) },
                           rename: { store.rename($0, to: $1) })
            }
            }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in destination(route) }
        }
        .overlay { WebPanel() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { store.persistAll() } }
        .onChange(of: drawerOpen) { _, open in if open { store.persistCurrent() } }
        .onOpenURL { url in if let r = Self.route(from: url) { handle(r) } }
        .onAppear {
            if CommandLine.arguments.contains("-demo") { store.replaceCurrent(with: Self.makeService(.conversation)) }
            if CommandLine.arguments.contains("-demoKill") { store.replaceCurrent(with: Self.makeService(.killSwitch)) }
            if CommandLine.arguments.contains("-demoUnavailable") { store.replaceCurrent(with: Self.makeService(.unavailable)) }
            if CommandLine.arguments.contains("-demoDrawer") { drawerOpen = true }
        }
    }

    static var demoLaunch: Bool { CommandLine.arguments.contains { $0.hasPrefix("-demo") } }

    /// Real model by default; demo data only when a -demo launch flag is present.
    static func makeService(_ scenario: DemoChatService.Scenario) -> any ChatService {
        let demo = CommandLine.arguments.contains { $0.hasPrefix("-demo") }
        if demo || scenario != .empty { return DemoChatService(scenario: scenario) }
        return ModelSettings.shared.makeService()
    }

    private func handle(_ route: Route) {
        drawerOpen = false
        switch route {
        case .newChat: store.newChat(); path = []
        case .chat(let id): store.select(id); path = []
        default: path = [route]
        }
    }

    @ViewBuilder private func destination(_ r: Route) -> some View {
        switch r {
        case .memory: MemoryView()
        case .notes, .note: PlaceholderScreen(title: String(localized: "Notes and Tasks"), icon: "note.text")
        case .briefings, .briefing: PlaceholderScreen(title: String(localized: "Briefings and Automations"), icon: "sun.max")
        case .approvalsInbox: PlaceholderScreen(title: String(localized: "Approvals"), icon: "checkmark.seal")
        case .activity: PlaceholderScreen(title: String(localized: "Activity log"), icon: "list.bullet.rectangle")
        case .integrations: IntegrationsView()
        case .models: ModelsView(use: { id in ModelSettings.shared.select(id); if store.current.items.isEmpty { store.switchModel(to: id) } })
        case .privacy: PlaceholderScreen(title: String(localized: "Privacy"), icon: "lock.shield")
        case .advanced:
            SubMenu(title: String(localized: "Advanced"), items: SubItem.advanced)
        case .settings:
            SettingsView()
        case .newChat, .chat: EmptyView()
        }
    }

    /// adiuvaret://new, adiuvaret://approvals, adiuvaret://notes ...
    static func route(from url: URL) -> Route? {
        guard url.scheme == "adiuvaret" else { return nil }
        switch url.host() {
        case "new": return .newChat
        case "approvals": return .approvalsInbox
        case "briefings": return .briefings
        case "notes": return .notes
        case "memory": return .memory
        default: return nil
        }
    }
}
