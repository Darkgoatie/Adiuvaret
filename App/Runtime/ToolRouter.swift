import Foundation
import FoundationModels
import ToolKit

@Generable
struct ToolRoute {
    @Guide(description: "True when the message needs the user's calendar, reminders or another app capability. False for greetings, advice, writing help and general knowledge.")
    var needsTool: Bool
    @Guide(description: "Three to six plain words naming the capability needed, such as 'read calendar events next week' or 'create reminder'. Empty when no tool is needed.")
    var searchWords: String
}

/// Step one of every reply: read the message, say what capability it needs, then look that up in the tool catalog.
enum ToolRouter {
    static func instructions(_ catalog: ToolCatalog) -> String {
        let capabilities = catalog.categories.map { c in
            "\(c): " + catalog.entries.filter { $0.category == c }.map(\.title).joined(separator: ", ")
        }.joined(separator: ". ")
        return """
        You decide which capability a message needs. Capabilities: \(capabilities). \
        Set needsTool to false for greetings, thanks, advice, writing help and general questions. \
        For anything about the user's own calendar, events, free time or reminders, set needsTool to true and \
        write searchWords as three to six words naming what is needed, using verbs like read, find, create, move, delete, list \
        and nouns like calendar, event, free time, reminder. A short follow-up such as "and the day after?" continues the previous request.
        """
    }

    /// Returns the tools to give the reply, best match first, with their requirements. Empty means answer without tools.
    static func choose(prompt: String, previous: String?, catalog: ToolCatalog = .standard) async -> [CatalogEntry] {
        var needsTool = true
        var words = ""
        do {
            let session = LanguageModelSession(instructions: instructions(catalog))
            var text = ""
            if let previous, !previous.isEmpty { text += "Previous request: \(String(previous.prefix(200)))\n" }
            text += "New message: \(String(prompt.prefix(400)))"
            let route = try await session.respond(to: text, generating: ToolRoute.self).content
            needsTool = route.needsTool
            words = route.searchWords
        } catch {
            // Router failed: fall back to searching the message alone.
        }
        guard needsTool else { return [] }
        let hits = catalog.search(primary: words, secondary: prompt)
        return catalog.withRequirements(hits.map(\.entry))
    }
}
