import Foundation
import AdiuvaretCore

public enum PolicyDecision: Sendable, Equatable {
    case allow
    case requireApproval(ApprovalReason)
    case deny(DenyReason)
}

public enum ApprovalReason: Sendable, Equatable {
    case irreversible
    case writeWithoutGrant
    case untrustedContext
}

public enum DenyReason: Sendable, Equatable {
    case killSwitch
    case unknownTool
    case rateLimited
    case scheduledRunWrite
    case userDenied
}

public enum GrantScope: Sendable, Hashable {
    case chat(UUID)
    case always
}

public struct PolicyLimits: Sendable {
    public var maxToolCallsPerTask: Int
    public init(maxToolCallsPerTask: Int = 12) { self.maxToolCallsPerTask = maxToolCallsPerTask }
}

/// Sole authority on whether a tool call may run. Has no knowledge of model providers.
public actor PolicyEngine {
    private var tools: [String: ToolDescriptor] = [:]
    private var grants: [String: Set<GrantScope>] = [:]
    private var callsPerTask: [UUID: Int] = [:]
    private let limits: PolicyLimits
    public private(set) var killSwitchEngaged = false

    public init(tools: [ToolDescriptor], limits: PolicyLimits = PolicyLimits()) {
        for t in tools { self.tools[t.name] = t }
        self.limits = limits
    }

    public func setKillSwitch(_ on: Bool) { killSwitchEngaged = on }

    public func grant(_ toolName: String, scope: GrantScope) {
        grants[toolName, default: []].insert(scope)
    }

    public func revoke(_ toolName: String, scope: GrantScope) {
        grants[toolName]?.remove(scope)
    }

    public func descriptor(for name: String) -> ToolDescriptor? { tools[name] }

    public func evaluate(_ call: ToolCall, in ctx: CallContext) -> PolicyDecision {
        if killSwitchEngaged { return .deny(.killSwitch) }
        guard let tool = tools[call.toolName] else { return .deny(.unknownTool) }
        if callsPerTask[ctx.taskID, default: 0] >= limits.maxToolCallsPerTask { return .deny(.rateLimited) }
        if ctx.isScheduledRun && tool.permission > .readOnly { return .deny(.scheduledRunWrite) }

        switch tool.permission {
        case .readOnly:
            return .allow
        case .irreversible:
            return .requireApproval(.irreversible)
        case .reversibleWrite:
            if ctx.contextContainsUntrusted { return .requireApproval(.untrustedContext) }
            let g = grants[tool.name] ?? []
            if g.contains(.always) || g.contains(.chat(ctx.chatID)) { return .allow }
            return .requireApproval(.writeWithoutGrant)
        }
    }

    func recordExecution(taskID: UUID) {
        callsPerTask[taskID, default: 0] += 1
    }

    public func endTask(_ taskID: UUID) { callsPerTask[taskID] = nil }
}
