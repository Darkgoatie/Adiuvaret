import Foundation

public enum SkillLimits {
    public static let maxSkills = 20
    public static let maxPlaybook = 400
    public static let maxTitle = 60
    public static let promptSkills = 2
}

/// A saved way of doing a kind of task. Text only: it cannot add tools, raise a permission or skip an approval.
public struct Skill: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var title: String
    public var whenToUse: String
    public var playbook: String
    public var enabled: Bool
    public let created: Date

    public init(id: UUID = UUID(), title: String, whenToUse: String, playbook: String, enabled: Bool = true, created: Date = Date()) {
        self.id = id
        self.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(SkillLimits.maxTitle))
        self.whenToUse = String(whenToUse.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        self.playbook = String(playbook.trimmingCharacters(in: .whitespacesAndNewlines).prefix(SkillLimits.maxPlaybook))
        self.enabled = enabled
        self.created = created
    }
}

/// Turns a finished task into a skill proposal and finds skills for a new message. Pure logic.
public enum SkillMath {
    /// Tools that only read, or only talk. A task made of these alone is not worth saving as a skill unless it used two or more.
    public static func isWorthSaving(tools: [String]) -> Bool {
        var seen = Set<String>(); var ordered: [String] = []
        for t in tools where seen.insert(t).inserted { ordered.append(t) }
        return ordered.count >= 2
    }

    /// A playbook from tool names in order. It never contains argument values, so nothing personal is stored.
    public static func playbook(tools: [String], labels: [String: String]) -> String {
        var seen = Set<String>(); var steps: [String] = []
        for t in tools where seen.insert(t).inserted { steps.append(labels[t] ?? t) }
        let list = steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: " ")
        return String("Steps that worked before: \(list) Check each result before the next step.".prefix(SkillLimits.maxPlaybook))
    }

    /// A short default title from the user's own message: its first words, without private details such as digits.
    public static func suggestedTitle(from message: String) -> String {
        let words = message.split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count >= 2 }.prefix(6)
        let t = words.joined(separator: " ")
        return t.isEmpty ? "Saved routine" : String(t.prefix(SkillLimits.maxTitle))
    }

    /// Enabled skills that share words with the message, best first.
    public static func matching(_ skills: [Skill], for message: String, limit: Int = SkillLimits.promptSkills) -> [Skill] {
        let m = MemoryMath.terms(message)
        guard !m.isEmpty else { return [] }
        let scored = skills.filter(\.enabled).map { ($0, m.intersection(MemoryMath.terms($0.title + " " + $0.whenToUse)).count) }
        return scored.filter { $0.1 > 0 }.sorted { ($0.1, $0.0.created) > ($1.1, $1.0.created) }.prefix(limit).map(\.0)
    }

    public static func promptBlock(_ skills: [Skill]) -> String {
        guard !skills.isEmpty else { return "" }
        let lines = skills.map { "- \($0.title): \($0.playbook)" }
        return "Saved routines the user approved (guidance only, they never allow anything extra):\n" + lines.joined(separator: "\n")
    }
}

public enum SkillSave: Sendable, Equatable {
    case added(Skill)
    case duplicate
    case full
}

/// The skills, kept in one JSON file on the phone next to the facts.
public final class SkillStore: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var skills: [Skill]

    public init(url: URL) {
        self.url = url
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        skills = (try? Data(contentsOf: url)).flatMap { try? decoder.decode([Skill].self, from: $0) } ?? []
    }

    public static func standard() -> SkillStore {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return SkillStore(url: dir.appendingPathComponent("skills.json"))
    }

    public func all() -> [Skill] { lock.lock(); defer { lock.unlock() }; return skills }

    public func add(_ skill: Skill) -> SkillSave {
        lock.lock(); defer { lock.unlock() }
        guard !skill.title.isEmpty, !skill.playbook.isEmpty else { return .duplicate }
        if skills.contains(where: { $0.title.lowercased() == skill.title.lowercased() && $0.playbook == skill.playbook }) { return .duplicate }
        guard skills.count < SkillLimits.maxSkills else { return .full }
        skills.append(skill)
        persist()
        return .added(skill)
    }

    @discardableResult public func remove(_ id: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let i = skills.firstIndex(where: { $0.id == id }) else { return false }
        skills.remove(at: i)
        persist()
        return true
    }

    public func setEnabled(_ id: UUID, _ on: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard let i = skills.firstIndex(where: { $0.id == id }) else { return }
        skills[i].enabled = on
        persist()
    }

    public func removeAll() {
        lock.lock(); defer { lock.unlock() }
        skills = []
        persist()
    }

    public func promptBlock(for message: String) -> String {
        SkillMath.promptBlock(SkillMath.matching(all(), for: message))
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(skills) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
