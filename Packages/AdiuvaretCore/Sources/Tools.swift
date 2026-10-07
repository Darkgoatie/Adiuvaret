import Foundation

public enum ModelTier: Int, Sendable, Codable, CaseIterable {
    case appleFoundation = 0
    case mlx = 1
    case localServer = 2
    case cloud = 3
}

public enum PermissionTier: Int, Sendable, Codable, Comparable {
    case readOnly = 1
    case reversibleWrite = 2
    case irreversible = 3

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

public enum Sensitivity: Int, Sendable, Codable, Comparable {
    case `public` = 0
    case personal = 1
    case sensitive = 2

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

public struct ToolDescriptor: Sendable, Hashable, Codable {
    public let name: String
    public let summary: String
    public let permission: PermissionTier
    public let outputSensitivity: Sensitivity

    public init(name: String, summary: String, permission: PermissionTier, outputSensitivity: Sensitivity) {
        self.name = name
        self.summary = summary
        self.permission = permission
        self.outputSensitivity = outputSensitivity
    }
}

public struct ToolCall: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let toolName: String
    public let argumentsJSON: String

    public init(id: UUID = UUID(), toolName: String, argumentsJSON: String) {
        self.id = id
        self.toolName = toolName
        self.argumentsJSON = argumentsJSON
    }
}

/// Where the current turn comes from and what the model has seen.
public struct CallContext: Sendable, Hashable {
    public let taskID: UUID
    public let chatID: UUID
    public let isScheduledRun: Bool
    /// True once any tool output or user data (calendar text, contacts, shared content) entered the model context.
    public let contextContainsUntrusted: Bool

    public init(taskID: UUID, chatID: UUID, isScheduledRun: Bool = false, contextContainsUntrusted: Bool = false) {
        self.taskID = taskID
        self.chatID = chatID
        self.isScheduledRun = isScheduledRun
        self.contextContainsUntrusted = contextContainsUntrusted
    }
}
