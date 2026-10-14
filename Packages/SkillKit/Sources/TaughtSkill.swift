import Foundation

public enum TaughtLimits {
    public static let maxInstructions = 1500
    public static let maxName = 60
    public static let maxDescription = 160
    public static let maxTools = 8
    public static let maxHosts = 6
    public static let maxKeywords = 12
    public static let maxSkills = 50
}

public enum TaughtSource: String, Codable, Sendable, CaseIterable {
    /// Written by the assistant after doing a task with the user, saved on the user's approval.
    case taught
    /// Brought in from a file. Always untrusted.
    case imported
}

/// A procedure the assistant was taught: instructions plus the generic tools and approved hosts it uses.
/// Data only. It cannot add a tool, raise a permission or skip an approval, and it never holds a credential.
public struct TaughtSkill: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public var name: String
    public var description: String
    public var keywords: [String]
    public var instructions: String
    public var tools: [String]
    public var hosts: [String]
    public var version: Int
    public var source: TaughtSource
    /// True when the text came from a web page or a pasted document, which can carry instructions meant for the model.
    public var untrusted: Bool
    public var enabled: Bool

    public init(id: String, name: String, description: String, keywords: [String] = [], instructions: String,
                tools: [String] = [], hosts: [String] = [], version: Int = 1, source: TaughtSource = .taught,
                untrusted: Bool = true, enabled: Bool = true) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(TaughtLimits.maxName))
        self.description = String(description.trimmingCharacters(in: .whitespacesAndNewlines).prefix(TaughtLimits.maxDescription))
        self.keywords = Array(keywords.prefix(TaughtLimits.maxKeywords))
        self.instructions = String(instructions.trimmingCharacters(in: .whitespacesAndNewlines).prefix(TaughtLimits.maxInstructions))
        self.tools = Array(tools.prefix(TaughtLimits.maxTools))
        self.hosts = Array(hosts.prefix(TaughtLimits.maxHosts))
        self.version = version
        self.source = source
        self.untrusted = source == .imported ? true : untrusted
        self.enabled = enabled
    }

    /// A short id made from the name, with a numeric suffix to keep it unique.
    public static func makeID(from name: String, taken: Set<String>) -> String {
        let words = SkillTerms.terms(name).prefix(4)
        var base = words.joined(separator: "-")
        if base.count < 2 { base = "skill" }
        base = String(base.prefix(30))
        if !taken.contains(base) { return base }
        var n = 2
        while taken.contains("\(base)-\(n)") { n += 1 }
        return "\(base)-\(n)"
    }
}

public enum TaughtError: Error, Sendable, Equatable {
    case invalidID
    case emptyName
    case emptyInstructions
    case unknownTool(String)
    case badHost(String)
    case secretInText
    case full
    case notFound
}

public struct TaughtUse: Sendable, Equatable {
    public let id: String
    public let name: String
    public let instructions: String
    public let tools: [String]
    public let hosts: [String]
    public let untrusted: Bool
}

/// Looks for text that is probably a credential, so a taught skill never stores one.
public enum SecretGuard {
    public static func containsSecret(_ text: String) -> Bool {
        let patterns = [
            #"(?i)bearer\s+[A-Za-z0-9._\-]{16,}"#,
            #"\b(sk|pk|rk|ghp|gho|ghs|github_pat|xox[abprs]|glpat|AKIA)[-_][A-Za-z0-9_\-]{12,}"#,
            #"\bAKIA[0-9A-Z]{16}\b"#,
            #"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#,
            #"(?i)(api[_-]?key|token|secret|password|passwd)\s*[:=]\s*["']?[A-Za-z0-9._\-/+]{16,}"#,
            #"\b[A-Fa-f0-9]{40,}\b"#,
            #"\b[A-Za-z0-9+/]{40,}={0,2}\b"#,
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }
}

/// The taught skills, searched in code so only a match enters the prompt. Pure apart from the optional JSON file.
public final class TaughtSkillStore: @unchecked Sendable {
    private let lock = NSLock()
    private var skills: [TaughtSkill] = []
    private let url: URL?
    private let knownTools: @Sendable () -> Set<String>
    private let visibleTools: @Sendable () -> Set<String>
    private let normalizeHost: @Sendable (String) -> String?

    /// normalizeHost returns the clean host or nil; it is the same rule the API tool applies, passed in so this package stays independent.
    public init(url: URL? = nil,
                knownTools: @escaping @Sendable () -> Set<String>,
                visibleTools: (@Sendable () -> Set<String>)? = nil,
                normalizeHost: @escaping @Sendable (String) -> String?) {
        self.url = url
        self.knownTools = knownTools
        self.visibleTools = visibleTools ?? knownTools
        self.normalizeHost = normalizeHost
        if let url, let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode([TaughtSkill].self, from: data) { skills = saved }
    }

    public func all() -> [TaughtSkill] { lock.lock(); defer { lock.unlock() }; return skills }

    /// Checks and stores a skill. Hosts are cleaned. Text holding something that looks like a token is refused.
    @discardableResult
    public func register(_ input: TaughtSkill) throws -> TaughtSkill {
        lock.lock(); defer { lock.unlock() }
        var skill = input
        guard skill.id.range(of: #"^[a-z0-9][a-z0-9_-]{1,39}$"#, options: .regularExpression) != nil else { throw TaughtError.invalidID }
        guard !skill.name.isEmpty else { throw TaughtError.emptyName }
        guard !skill.instructions.isEmpty else { throw TaughtError.emptyInstructions }
        let known = knownTools()
        if let bad = skill.tools.first(where: { !known.contains($0) }) { throw TaughtError.unknownTool(bad) }
        var hosts: [String] = []
        for h in skill.hosts {
            guard let clean = normalizeHost(h) else { throw TaughtError.badHost(h) }
            if !hosts.contains(clean) { hosts.append(clean) }
        }
        skill.hosts = hosts
        let all = [skill.name, skill.description, skill.instructions, skill.keywords.joined(separator: " ")].joined(separator: "\n")
        guard !SecretGuard.containsSecret(all) else { throw TaughtError.secretInText }
        if let i = skills.firstIndex(where: { $0.id == skill.id }) {
            skill.version = skills[i].version + 1
            skills[i] = skill
        } else {
            guard skills.count < TaughtLimits.maxSkills else { throw TaughtError.full }
            skills.append(skill)
        }
        persist()
        return skill
    }

    public func takenIDs() -> Set<String> { Set(all().map(\.id)) }

    @discardableResult public func remove(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let i = skills.firstIndex(where: { $0.id == id }) else { return false }
        skills.remove(at: i)
        persist()
        return true
    }

    public func removeAll() {
        lock.lock(); defer { lock.unlock() }
        skills = []
        persist()
    }

    public func setEnabled(_ id: String, _ on: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard let i = skills.firstIndex(where: { $0.id == id }) else { return }
        skills[i].enabled = on
        persist()
    }

    /// One line per enabled skill (id and what it does), for a prompt that lets the model recognise something taught earlier.
    public func index(limit: Int = 8) -> String {
        all().filter(\.enabled).prefix(limit).map { "- \($0.id): \(String($0.description.prefix(90)))" }.joined(separator: "\n")
    }

    /// Enabled skills ranked by shared words. Two words must match, or one word that names the skill (its name and keywords, or its host).
    /// A short message such as "do it again" is read together with the message before it (`previous`).
    public func find(_ query: String, previous: String? = nil, limit: Int = 3) -> [TaughtSkill] {
        var wanted = SkillTerms.terms(query)
        if wanted.count < 3, let previous { for t in SkillTerms.terms(previous) where !wanted.contains(t) { wanted.append(t) } }
        guard !wanted.isEmpty else { return [] }
        let needed = min(2, wanted.count)
        let scored: [(TaughtSkill, Int)] = all().filter(\.enabled).compactMap { s in
            let name = Set(SkillTerms.terms(s.name))
            let keys = Set(s.keywords.flatMap(SkillTerms.terms))
            let hosts = Set(s.hosts.flatMap { SkillTerms.terms($0.replacingOccurrences(of: ".", with: " ")) })
            let text = Set(SkillTerms.terms(s.description))
            var score = 0, matched = 0
            var identity = false
            for w in wanted {
                let part = (name.contains(w) ? 4 : 0) + (keys.contains(w) ? 3 : 0) + (hosts.contains(w) ? 2 : 0) + (text.contains(w) ? 1 : 0)
                if part > 0 { matched += 1; score += part }
                if (name.contains(w) && keys.contains(w)) || hosts.contains(w) { identity = true }
            }
            return (matched >= needed || (matched >= 1 && identity)) ? (s, score) : nil
        }
        return scored.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.id < $1.0.id }.prefix(max(0, limit)).map(\.0)
    }

    public func use(_ id: String) throws -> TaughtUse {
        guard let s = all().first(where: { $0.id == id.lowercased() && $0.enabled }) else { throw TaughtError.notFound }
        let visible = visibleTools()
        return TaughtUse(id: s.id, name: s.name, instructions: s.instructions, tools: s.tools.filter { visible.contains($0) }, hosts: s.hosts, untrusted: s.untrusted)
    }

    private func persist() {
        guard let url, let data = try? JSONEncoder().encode(skills) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
