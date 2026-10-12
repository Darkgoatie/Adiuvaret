import Foundation

public enum SkillLimits2 {
    public static let maxBody = 1200
    public static let maxName = 60
    public static let maxDescription = 160
    public static let maxTools = 8
    public static let maxSkills = 100
}

public enum SkillSource: String, Codable, Sendable, CaseIterable {
    case builtin, user, learned, imported
}

/// A named block of instructions plus the tool names it expects. Text only: it cannot add a tool, raise a permission or skip an approval.
public struct AgentSkill: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public var name: String
    public var description: String
    public var keywords: [String]
    public var examples: [String]
    public var body: String
    public var allowedTools: [String]
    public var requires: [String]
    public var version: Int
    public var source: SkillSource
    public var enabled: Bool

    public init(id: String, name: String, description: String, keywords: [String] = [], examples: [String] = [], body: String,
                allowedTools: [String] = [], requires: [String] = [], version: Int = 1, source: SkillSource = .user, enabled: Bool = true) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(SkillLimits2.maxName))
        self.description = String(description.trimmingCharacters(in: .whitespacesAndNewlines).prefix(SkillLimits2.maxDescription))
        self.keywords = keywords
        self.examples = examples
        self.body = String(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(SkillLimits2.maxBody))
        self.allowedTools = Array(allowedTools.prefix(SkillLimits2.maxTools))
        self.requires = requires
        self.version = version
        self.source = source
        self.enabled = enabled
    }

    /// Imported skills come from outside the app, so anything they say is treated as untrusted context.
    public var untrusted: Bool { source == .imported }
}

public enum SkillError: Error, Sendable, Equatable {
    case invalidID
    case duplicate(String)
    case emptyBody
    case emptyName
    case unknownTool(String)
    case full
    case notFound
}

/// What a model sees when it searches: no body, so the prompt stays small.
public struct SkillHit: Sendable, Equatable {
    public let id: String
    public let name: String
    public let description: String
}

public struct SkillUse: Sendable, Equatable {
    public let id: String
    public let body: String
    /// The playbook's tools that exist and are switched on right now.
    public let tools: [String]
    public let untrusted: Bool
}
