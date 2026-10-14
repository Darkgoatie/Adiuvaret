import Foundation

/// How an online model finds tools: a small set is always loaded, the rest sit behind `findTools`.
/// The model asks for what it needs in its own words and gets the matching tools back, instead of code guessing from the message.
/// Pure logic; the chat loop adds the schemas of what was found.
public enum ToolDiscovery {
    public static let toolName = "findTools"
    public static let maxFound = 5
    /// The tool set never grows beyond this, so a long chat cannot load the whole catalog.
    public static let maxLoaded = 14

    /// Always loaded for an online model: web search, the API tool, scripts, skills and the finder itself.
    public static let core: [String] = ["searchWeb", "callAPI", "runScript", "skill_use", toolName]

    /// One line per category with the plain words of what it can do, so the model knows what exists before it asks.
    public static func listing(_ catalog: ToolCatalog) -> String {
        var lines: [String] = []
        for category in catalog.categories {
            let titles = catalog.entries.filter { $0.category == category }.map(\.title)
            guard !titles.isEmpty else { continue }
            lines.append("\(category): " + titles.prefix(4).joined(separator: ", ") + (titles.count > 4 ? ", and \(titles.count - 4) more" : ""))
        }
        return lines.joined(separator: "; ")
    }

    /// The entries that fit a request, best first, with the tools they depend on, minus what is already loaded.
    public static func find(_ query: String, in catalog: ToolCatalog, loaded: Set<String>) -> [CatalogEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let hits = catalog.search(primary: q, secondary: q, limit: maxFound, minimumScore: 3).map(\.entry)
        return catalog.withRequirements(hits, cap: maxFound).filter { !loaded.contains($0.id) }
    }

    /// What `findTools` returns. The found tools are added to the model's tool list for the next step.
    public static func render(found: [CatalogEntry], alreadyLoaded: [CatalogEntry], query: String) -> String {
        if found.isEmpty && alreadyLoaded.isEmpty {
            return "No tool matches \"\(query.replacingOccurrences(of: "\"", with: "'"))\". Try different words, or answer without a tool."
        }
        var lines: [String] = []
        if !found.isEmpty {
            lines.append("Loaded for your next step (you can call them now):")
            lines += found.map { "- \($0.id): \($0.title). \(String($0.description.prefix(140)))" }
        }
        if !alreadyLoaded.isEmpty {
            lines.append("Already available: " + alreadyLoaded.map(\.id).joined(separator: ", ") + ".")
        }
        return lines.joined(separator: "\n")
    }

    /// The ids to load now: pre-selected hints first, then the core, capped. Hints that are not visible are dropped by the caller.
    public static func initial(hints: [String], core: [String] = core, cap: Int = maxLoaded) -> [String] {
        var out: [String] = []
        for id in core + hints where !out.contains(id) { out.append(id) }
        return Array(out.prefix(cap))
    }

    /// Adds newly found ids to the loaded list without passing the cap. Returns the ids that were actually added.
    public static func grow(_ loaded: inout [String], with ids: [String], cap: Int = maxLoaded) -> [String] {
        var added: [String] = []
        for id in ids where !loaded.contains(id) && loaded.count < cap {
            loaded.append(id); added.append(id)
        }
        return added
    }
}
