import Foundation

/// One tool the assistant can use, described for search. The id is the tool's name in the app.
public struct CatalogEntry: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let category: String
    /// What the tool does and when to use it. Searched with a low weight.
    public let description: String
    /// Words a user or the router would use for this tool. Searched with the highest weight.
    public let keywords: [String]
    /// Sample requests. They also serve as tests: each must find its own entry first.
    public let examples: [String]
    /// Tools that must be available whenever this one is, for example a read before a move.
    public let requires: [String]

    public init(id: String, title: String, category: String, description: String, keywords: [String], examples: [String], requires: [String] = []) {
        self.id = id; self.title = title; self.category = category
        self.description = description; self.keywords = keywords; self.examples = examples; self.requires = requires
    }
}

public struct CatalogMatch: Sendable, Equatable {
    public let entry: CatalogEntry
    public let score: Double
}

/// The list of every tool, searchable by what the tool does. Adding a tool means adding one entry here.
public struct ToolCatalog: Sendable {
    public let entries: [CatalogEntry]
    private let weights: [[String: Double]]

    public init(entries: [CatalogEntry]) {
        self.entries = entries
        self.weights = entries.map { e in
            var w: [String: Double] = [:]
            func put(_ text: String, _ weight: Double) {
                for t in ToolCatalog.tokens(text) { w[t] = max(w[t] ?? 0, weight) }
            }
            put(e.id, 2); put(e.title, 2)
            e.keywords.forEach { put($0, 3) }
            e.examples.forEach { put($0, 1.5) }
            put(e.description, 1); put(e.category, 1)
            return w
        }
    }

    public var categories: [String] {
        var seen: [String] = []
        for e in entries where !seen.contains(e.category) { seen.append(e.category) }
        return seen
    }

    public func entry(_ id: String) -> CatalogEntry? { entries.first { $0.id == id } }

    /// Finds the tools whose descriptions fit best. `primary` (the router's search words) counts double,
    /// `secondary` (the user's own message) is the backup. Needs real evidence, so unrelated chat returns nothing.
    public func search(primary: String, secondary: String = "", limit: Int = 3, minimumScore: Double = 3) -> [CatalogMatch] {
        let p = Set(Self.tokens(primary)), s = Set(Self.tokens(secondary))
        var scored: [CatalogMatch] = []
        for (i, w) in weights.enumerated() {
            let score = 2 * p.reduce(0.0) { $0 + (w[$1] ?? 0) } + s.reduce(0.0) { $0 + (w[$1] ?? 0) }
            if score >= minimumScore { scored.append(CatalogMatch(entry: entries[i], score: score)) }
        }
        let ranked = scored.enumerated().sorted { a, b in
            a.element.score != b.element.score ? a.element.score > b.element.score : a.offset < b.offset
        }.map(\.element)
        guard let top = ranked.first?.score else { return [] }
        return Array(ranked.filter { $0.score >= top * 0.5 }.prefix(max(1, limit)))
    }

    /// Adds the tools each chosen tool depends on, keeps the order, drops duplicates and caps the list
    /// (Apple advises three to five tools per request).
    public func withRequirements(_ chosen: [CatalogEntry], cap: Int = 4) -> [CatalogEntry] {
        var out: [CatalogEntry] = []
        func add(_ e: CatalogEntry) { if !out.contains(where: { $0.id == e.id }) { out.append(e) } }
        for e in chosen {
            add(e)
            for id in e.requires { if let r = entry(id) { add(r) } }
        }
        return Array(out.prefix(cap))
    }

    // MARK: text handling

    static let stopwords: Set<String> = [
        "the", "an", "to", "of", "in", "on", "at", "for", "my", "me", "is", "are", "am", "do", "does", "did", "what", "whats",
        "when", "how", "can", "you", "please", "with", "and", "or", "it", "this", "that", "there", "any", "anything", "have",
        "has", "be", "would", "could", "should", "will", "about", "from", "next", "all", "get", "show", "tell", "give", "need",
        "want", "let", "not", "dont", "now", "just", "some", "up", "out", "by", "as", "if", "so", "we", "us", "our", "your"
    ]

    static func stem(_ word: String) -> String {
        var s = word
        for suffix in ["ing", "ed", "es", "s"] where s.hasSuffix(suffix) && s.count - suffix.count >= 3 {
            s.removeLast(suffix.count); break
        }
        if s.hasSuffix("e"), s.count > 3 { s.removeLast() }
        return s
    }

    /// Lowercase, accent-free, camelCase split, stopwords removed, lightly stemmed.
    static func tokens(_ text: String) -> [String] {
        var spaced = ""
        var previous: Character = " "
        for ch in text {
            if ch.isUppercase, previous.isLowercase { spaced.append(" ") }
            spaced.append(ch); previous = ch
        }
        let folded = spaced.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        var out: [String] = []
        for raw in folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            let w = String(raw)
            if w.count < 2 || stopwords.contains(w) || w.allSatisfy(\.isNumber) { continue }
            out.append(stem(w))
        }
        return out
    }
}
