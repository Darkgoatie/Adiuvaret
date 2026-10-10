import Foundation

/// One short thing the user told the assistant about themselves.
public struct MemoryFact: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var text: String
    public let created: Date

    public init(id: UUID = UUID(), text: String, created: Date = Date()) {
        self.id = id; self.text = text; self.created = created
    }
}

/// What the assistant may keep. The caps stop the prompt from growing and make the user choose what to forget.
public enum MemoryLimits {
    public static let maxFacts = 40
    public static let maxFactLength = 200
    public static let promptFacts = 8
    public static let promptCharacters = 900
}
