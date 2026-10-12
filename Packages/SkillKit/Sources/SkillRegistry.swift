import Foundation

/// Every skill, builtin or added later, behind one find/use pair that all model providers call the same way.
public final class SkillRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var skills: [AgentSkill] = []
    private let url: URL?
    private let knownTools: @Sendable () -> Set<String>
    private let visibleTools: @Sendable () -> Set<String>
    private let connectorOn: @Sendable (String) -> Bool

    /// knownTools: every tool name that exists (validates registration). visibleTools: names usable right now.
    /// connectorOn: whether a connector id is switched on; a skill that requires an off connector is neither found nor used.
    public init(url: URL? = nil,
                knownTools: @escaping @Sendable () -> Set<String>,
                visibleTools: (@Sendable () -> Set<String>)? = nil,
                connectorOn: @escaping @Sendable (String) -> Bool = { _ in true }) {
        self.url = url
        self.knownTools = knownTools
        self.visibleTools = visibleTools ?? knownTools
        self.connectorOn = connectorOn
        if let url, let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode([AgentSkill].self, from: data) {
            skills = saved.filter { $0.source != .builtin }
        }
    }

    public func all() -> [AgentSkill] { lock.lock(); defer { lock.unlock() }; return skills }

    /// Builtins are registered in code at launch and never written to disk.
    public func register(_ skill: AgentSkill) throws {
        lock.lock(); defer { lock.unlock() }
        guard skill.id.range(of: #"^[a-z0-9][a-z0-9_-]{1,39}$"#, options: .regularExpression) != nil else { throw SkillError.invalidID }
        guard !skill.name.isEmpty else { throw SkillError.emptyName }
        guard !skill.body.isEmpty else { throw SkillError.emptyBody }
        guard !skills.contains(where: { $0.id == skill.id }) else { throw SkillError.duplicate(skill.id) }
        let known = knownTools()
        if let bad = skill.allowedTools.first(where: { !known.contains($0) }) { throw SkillError.unknownTool(bad) }
        guard skills.count < SkillLimits2.maxSkills else { throw SkillError.full }
        skills.append(skill)
        persist()
    }

    @discardableResult public func remove(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let i = skills.firstIndex(where: { $0.id == id }), skills[i].source != .builtin else { return false }
        skills.remove(at: i)
        persist()
        return true
    }

    public func setEnabled(_ id: String, _ on: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard let i = skills.firstIndex(where: { $0.id == id }) else { return }
        skills[i].enabled = on
        persist()
    }

    private func usable(_ s: AgentSkill) -> Bool {
        s.enabled && s.requires.allSatisfy(connectorOn)
    }

    /// Usable skills ranked by shared words, best first. A skill needs at least two of the query's words (or the one word of a one-word query),
    /// so a calendar question that only mentions "week" does not drag in a weekly-review skill. Returns the index line only.
    public func find(_ query: String, limit: Int = 5) -> [SkillHit] {
        let wanted = SkillTerms.terms(query)
        guard !wanted.isEmpty else { return [] }
        let needed = min(2, wanted.count)
        let scored: [(AgentSkill, Int)] = all().filter(usable).compactMap { s in
            let name = Set(SkillTerms.terms(s.name))
            let keys = Set(s.keywords.flatMap(SkillTerms.terms))
            let text = Set(SkillTerms.terms(s.description + " " + s.examples.joined(separator: " ")))
            var score = 0, matched = 0
            for w in wanted {
                let part = (name.contains(w) ? 4 : 0) + (keys.contains(w) ? 3 : 0) + (text.contains(w) ? 1 : 0)
                if part > 0 { matched += 1; score += part }
            }
            return matched >= needed ? (s, score) : nil
        }
        return scored
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.id < $1.0.id }
            .prefix(max(0, limit))
            .map { SkillHit(id: $0.0.id, name: $0.0.name, description: $0.0.description) }
    }

    /// The body of a usable skill, with the playbook tools that are usable right now. Disabled, hidden or unknown ids fail.
    public func use(_ id: String) throws -> SkillUse {
        guard let s = all().first(where: { $0.id == id.lowercased() }), usable(s) else { throw SkillError.notFound }
        let visible = visibleTools()
        return SkillUse(id: s.id, name: s.name, body: s.body, tools: s.allowedTools.filter { visible.contains($0) }, untrusted: s.untrusted)
    }

    /// One line per usable skill, for a prompt that lists what can be asked for. Ids and descriptions only.
    public func index(limit: Int = 10) -> String {
        all().filter(usable).prefix(limit).map { "- \($0.id): \($0.description)" }.joined(separator: "\n")
    }

    private func persist() {
        guard let url else { return }
        let keep = skills.filter { $0.source != .builtin }
        guard let data = try? JSONEncoder().encode(keep) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}

public enum SkillTerms {
    private static let stop: Set<String> = ["the", "and", "for", "with", "about", "what", "when", "where", "which", "that", "this", "from",
                                            "into", "can", "you", "please", "any", "all", "my", "me", "how", "do", "to", "of", "is", "it", "in", "on", "a", "an", "are", "was",
                                            "your", "our", "its", "put", "get", "make", "then", "next"]

    private static func stem(_ w: String) -> String {
        w.count > 3 && w.hasSuffix("s") && !w.hasSuffix("ss") ? String(w.dropLast()) : w
    }

    public static func terms(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            .filter { $0.count >= 2 && !stop.contains($0) }
            .map(stem)
            .filter { seen.insert($0).inserted }
    }
}
