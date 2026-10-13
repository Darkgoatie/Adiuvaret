import SwiftUI
import DesignSystem
import Persistence
import ModelLibrary
import BriefingKit

struct RootView: View {
    @State private var drawerOpen = false
    @State private var path: [Route] = []
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var launch = LaunchRouter.shared
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
                DrawerView(chats: store.summaries, activeID: store.currentID, isOpen: drawerOpen,
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
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.persistAll() }
            else { Task { await BriefingHub.shared.reschedule(reason: "foreground") } }
        }
        .onChange(of: launch.pendingBriefing) { _, id in if let id { launch.pendingBriefing = nil; runBriefing(id) } }
        .onChange(of: launch.pendingQuestion) { _, text in if let text { launch.pendingQuestion = nil; ask(text) } }
        .onChange(of: drawerOpen) { _, open in if open { store.persistCurrent() } }
        .onOpenURL { url in
            if url.isFileURL { LaunchRouter.shared.receive(file: url); openChatForIncomingFile(); return }
            if let q = Self.question(from: url) { LaunchRouter.shared.ask(q) }
            else if let id = Self.briefingID(from: url) { LaunchRouter.shared.open(briefing: id) }
            else if let r = Self.route(from: url) { handle(r) }
        }
        .onAppear {
            if let id = launch.pendingBriefing { launch.pendingBriefing = nil; runBriefing(id) }
            if let text = launch.pendingQuestion { launch.pendingQuestion = nil; ask(text) }
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

    /// Opens a new chat that reads what the briefing lists and writes it up. The chat gets reading tools only.
    private func runBriefing(_ id: UUID) {
        guard let b = BriefingHub.shared.store.find(id) else { return }
        drawerOpen = false; path = []
        let service = ModelSettings.shared.makeService(title: b.title)
        if let tools = service as? any FixedToolsChat { tools.fixedTools = BriefingTools.tools(for: b) }
        store.open(service)
        let prompt = BriefingPrompt.text(for: b)
        Task { await service.send(prompt); store.persistCurrent() }
    }

    /// A file shared to Adiuvaret lands in the composer of a fresh chat, so the user adds a question and sends.
    private func openChatForIncomingFile() {
        drawerOpen = false; path = []
        store.newChat()
    }

    /// A question from Siri, Shortcuts or the share sheet starts in a fresh chat.
    private func ask(_ text: String) {
        drawerOpen = false; path = []
        store.newChat()
        let service = store.current
        Task { await service.send(text); store.persistCurrent() }
    }

    private func handle(_ route: Route) {
        drawerOpen = false
        switch route {
        case .newChat: store.newChat(); path = []
        case .chat(let id): store.select(id); path = []
        case .briefing(let id): runBriefing(id)
        default: path = [route]
        }
    }

    @ViewBuilder private func destination(_ r: Route) -> some View {
        switch r {
        case .memory: MemoryView()
        case .notes, .note: NotesView()
        case .briefings: BriefingsView(open: { runBriefing($0) })
        case .briefing: EmptyView()
        case .activity: ActivityView()
        case .integrations: IntegrationsView()
        case .apiAccess: APIHostsView()
        case .models: ModelsView(use: { id in ModelSettings.shared.select(id); if store.current.items.isEmpty { store.switchModel(to: id) } })
        case .privacy: PrivacyView()
        case .advanced:
            SubMenu(title: String(localized: "Advanced"), items: SubItem.advanced)
        case .settings:
            SettingsView()
        case .newChat, .chat: EmptyView()
        }
    }

    /// adiuvaret://ask?text=What is on today
    static func question(from url: URL) -> String? {
        guard url.scheme == "adiuvaret", url.host() == "ask" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "text" }?.value
    }

    /// adiuvaret://briefing?id=<uuid>
    static func briefingID(from url: URL) -> UUID? {
        guard url.scheme == "adiuvaret", url.host() == "briefing" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "id" }?.value.flatMap(UUID.init)
    }

    /// adiuvaret://new, adiuvaret://briefings, adiuvaret://notes ...
    static func route(from url: URL) -> Route? {
        guard url.scheme == "adiuvaret" else { return nil }
        switch url.host() {
        case "new": return .newChat
        case "briefings": return .briefings
        case "notes": return .notes
        case "memory": return .memory
        default: return nil
        }
    }
}
