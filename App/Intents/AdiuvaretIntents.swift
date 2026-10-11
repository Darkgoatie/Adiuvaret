import AppIntents
import Foundation

/// Ask Adiuvaret something from Siri, Spotlight, the Action Button or Shortcuts. The app opens on a new chat and answers.
struct AskAdiuvaretIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Adiuvaret"
    static let description = IntentDescription("Opens Adiuvaret on a new chat and sends your question.")
    static let openAppWhenRun = true

    @Parameter(title: "Question", requestValueDialog: "What do you want to ask?")
    var question: String

    static var parameterSummary: some ParameterSummary { Summary("Ask Adiuvaret \(\.$question)") }

    @MainActor func perform() async throws -> some IntentResult {
        LaunchRouter.shared.ask(question)
        return .result()
    }
}

/// Opens one of the user's briefings and runs it.
struct RunBriefingIntent: AppIntent {
    static let title: LocalizedStringResource = "Run a briefing"
    static let description = IntentDescription("Reads your calendar and reminders and gives you a briefing.")
    static let openAppWhenRun = true

    @Parameter(title: "Briefing")
    var briefing: BriefingEntity

    static var parameterSummary: some ParameterSummary { Summary("Run \(\.$briefing)") }

    @MainActor func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: briefing.id) else { return .result() }
        LaunchRouter.shared.open(briefing: id)
        return .result()
    }
}

struct BriefingEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Briefing"
    static let defaultQuery = BriefingQuery()
    let id: String
    let title: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

struct BriefingQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BriefingEntity] { try await suggestedEntities().filter { identifiers.contains($0.id) } }
    func suggestedEntities() async throws -> [BriefingEntity] {
        await MainActor.run { BriefingHub.shared.briefings.map { BriefingEntity(id: $0.id.uuidString, title: $0.title) } }
    }
}

/// Adds a line to the notes folder the user picked, without opening a chat. It appends to a note named "Inbox", or creates it.
struct AddNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a note"
    static let description = IntentDescription("Adds a line to the Inbox note in your Adiuvaret notes folder.")

    @Parameter(title: "Text", requestValueDialog: "What should I write down?")
    var text: String

    static var parameterSummary: some ParameterSummary { Summary("Add \(\.$text) to my notes") }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return .result(dialog: "There was nothing to write.") }
        guard ConnectorCatalog.isOn("notes"), NoteVault.shared.isConnected else {
            return .result(dialog: "Pick a notes folder in Adiuvaret under Advanced, Integrations first.")
        }
        let existing = NoteVault.shared.allNotes()?.first { $0.path.lowercased() == "inbox.md" }?.path
        switch NoteVault.shared.write(title: "Inbox", text: clean, appendTo: existing) {
        case .created, .appended: return .result(dialog: "Added to Inbox.")
        default: return .result(dialog: "I couldn't write to the notes folder.")
        }
    }
}

struct AdiuvaretShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AskAdiuvaretIntent(), phrases: ["Ask \(.applicationName)", "Ask \(.applicationName) a question"],
                    shortTitle: "Ask", systemImageName: "bubble.left")
        AppShortcut(intent: AddNoteIntent(), phrases: ["Add a note in \(.applicationName)", "Note this in \(.applicationName)"],
                    shortTitle: "Add note", systemImageName: "note.text.badge.plus")
        AppShortcut(intent: RunBriefingIntent(), phrases: ["Run my \(.applicationName) briefing", "Brief me with \(.applicationName)"],
                    shortTitle: "Briefing", systemImageName: "sun.max")
    }
}
