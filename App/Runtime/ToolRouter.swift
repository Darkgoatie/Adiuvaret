import Foundation
import FoundationModels
import ToolKit
import Diagnostics
import SkillKit

@Generable
struct ToolRoute {
    @Guide(description: "True when the message needs the user's calendar or reminders, or fresh information from the web such as news, scores, weather, prices, opening hours or release dates. False for greetings, advice and writing help.")
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
        You decide which capability a message needs. The calendar holds only the user's own events; when a public or world event happens (a final, a launch, a holiday, a conference) is a web search question. Capabilities: \(capabilities). \
        Set needsTool to false for greetings, thanks, advice, writing help and general questions. \
        For anything about the user's own calendar, events, free time or reminders, or that needs current information from the internet (news, scores, weather, prices, schedules, opening hours, release dates, who won), a website or a page, set needsTool to true and \
        write searchWords as three to six words naming what is needed, using verbs like read, find, create, move, delete, list \
        and nouns like calendar, event, free time, reminder, web search, website, page. For anything that needs the internet write the words search web first. A short follow-up such as "and the day after?" continues the previous request.
        """
    }

    /// Returns the tools to give the reply, best match first, with their requirements. Empty means answer without tools.
    static func choose(prompt: String, previous: String?, catalog: ToolCatalog = .standard) async -> [CatalogEntry] {
        await chooseWithNote(prompt: prompt, previous: previous, catalog: catalog).0
    }

    /// Same as `choose`, plus a short note for diagnostics: what the router decided and whether it failed.
    static func chooseWithNote(prompt: String, previous: String?, catalog full: ToolCatalog = .standard) async -> ([CatalogEntry], String) {
        // Tools of a connector the user switched off do not exist for this message.
        let catalog = ConnectorCatalog.visible(full)
        var needsTool = true
        var words = ""
        var note = "router ok"
        do {
            let session = LanguageModelSession(instructions: instructions(catalog))
            var text = ""
            if let previous, !previous.isEmpty { text += "Previous request: \(String(previous.prefix(200)))\n" }
            text += "New message: \(String(prompt.prefix(400)))"
            let route = try await session.respond(to: text, generating: ToolRoute.self).content
            needsTool = route.needsTool
            words = route.searchWords
        } catch {
            note = "router failed (\(type(of: error))): \(String(String(describing: error).prefix(120)))"
        }
        var chosen: [CatalogEntry] = []
        if needsTool {
            let hits = catalog.search(primary: words, secondary: prompt)
            chosen = catalog.withRequirements(hits.map(\.entry))
            note += " needsTool=true words=\(words.split(separator: " ").count) hits=\(hits.count)"
        } else {
            note += " needsTool=false"
        }
        // The date of a public event is a web question. The calendar only holds the user's own plans.
        if WebIntent.looksLikePublicDateQuestion(prompt), let search = catalog.entry("searchWeb") {
            chosen = catalog.withRequirements([search])
            note += " public-date->web"
        }
        // A question that names a connected app goes to that app's tool, whatever the router said.
        if let match = ConnectorIntent.detect(prompt), ConnectorCatalog.isOn(match.connector), let entry = catalog.entry(match.tool) {
            chosen = catalog.withRequirements([entry])
            note += " connector=\(match.connector)"
        }
        // A small model sometimes answers "look it up yourself" instead of using a tool. A plain web question always gets the search tool.
        if chosen.isEmpty, WebIntent.looksLikeWebRequest(prompt), let search = catalog.entry("searchWeb") {
            chosen = catalog.withRequirements([search])
            note += " web-intent"
        }
        // Asking for a skill by name or listing skills always offers skill_use, whatever the router said.
        if SkillIntent.looksLikeSkillRequest(prompt), let entry = catalog.entry("skill_use") {
            chosen = catalog.withRequirements(chosen + [entry])
            note += " skill-intent"
        }
        return (chosen, note)
    }
}
