import SwiftUI
import DesignSystem

struct RootView: View {
    @State private var drawerOpen = false
    @State private var path: [Route] = []
    @State private var chatID = UUID()
    @State private var service: any ChatService = Self.makeService(.empty)

    private let chats: [ChatSummary] = [
        .init(id: UUID(), title: "Dentist planning", group: .pinned),
        .init(id: UUID(), title: "Weekend with Ana", group: .today),
        .init(id: UUID(), title: "Gym schedule", group: .yesterday),
        .init(id: UUID(), title: "Mom's birthday", group: .week),
    ]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
            if CommandLine.arguments.contains("-nodrawer") {
                ChatView(service: service, openDrawer: {}).id(chatID)
                    .toolbar(.hidden, for: .navigationBar)
            } else {
            DrawerContainer(isOpen: $drawerOpen) {
                ChatView(service: service, openDrawer: { drawerOpen = true })
                    .id(chatID)
            } drawer: {
                DrawerView(chats: chats, pendingApprovals: 1) { route in handle(route) }
            }
            }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in destination(route) }
        }
        .onOpenURL { url in if let r = Self.route(from: url) { handle(r) } }
        .onAppear {
            if CommandLine.arguments.contains("-demo") { service = Self.makeService(.conversation); chatID = UUID() }
            if CommandLine.arguments.contains("-demoKill") { service = Self.makeService(.killSwitch); chatID = UUID() }
            if CommandLine.arguments.contains("-demoUnavailable") { service = Self.makeService(.unavailable); chatID = UUID() }
            if CommandLine.arguments.contains("-demoDrawer") { drawerOpen = true }
        }
    }

    /// Real model by default; demo data only when a -demo launch flag is present.
    static func makeService(_ scenario: DemoChatService.Scenario) -> any ChatService {
        let demo = CommandLine.arguments.contains { $0.hasPrefix("-demo") }
        if demo || scenario != .empty { return DemoChatService(scenario: scenario) }
        return LiveChatService()
    }

    private func handle(_ route: Route) {
        drawerOpen = false
        switch route {
        case .newChat: service = Self.makeService(.empty); chatID = UUID(); path = []
        case .chat: service = Self.makeService(.conversation); chatID = UUID(); path = []
        default: path = [route]
        }
    }

    @ViewBuilder private func destination(_ r: Route) -> some View {
        switch r {
        case .memory: PlaceholderScreen(title: String(localized: "What I know about you"), icon: "brain.head.profile")
        case .notes, .note: PlaceholderScreen(title: String(localized: "Notes and Tasks"), icon: "note.text")
        case .briefings, .briefing: PlaceholderScreen(title: String(localized: "Briefings and Automations"), icon: "sun.max")
        case .approvalsInbox: PlaceholderScreen(title: String(localized: "Approvals"), icon: "checkmark.seal")
        case .activity: PlaceholderScreen(title: String(localized: "Activity log"), icon: "list.bullet.rectangle")
        case .integrations: PlaceholderScreen(title: String(localized: "Integrations"), icon: "puzzlepiece.extension")
        case .models: PlaceholderScreen(title: String(localized: "Models"), icon: "cpu")
        case .privacy: PlaceholderScreen(title: String(localized: "Privacy"), icon: "lock.shield")
        case .advanced:
            SubMenu(title: String(localized: "Advanced"), items: SubItem.advanced)
        case .settings:
            SubMenu(title: String(localized: "Settings"), items: SubItem.settings) {
                NavigationLink("Spike") { SpikeView() }
                NavigationLink("Design") { DesignGallery() }
            }
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
