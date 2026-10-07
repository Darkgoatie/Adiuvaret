import Foundation
import AdiuvaretCore

public enum ApprovalResponse: Sendable { case approved, denied }

public protocol ApprovalPresenter: Sendable {
    func requestApproval(for call: ToolCall, tool: ToolDescriptor, reason: ApprovalReason) async -> ApprovalResponse
}

public protocol ToolExecutor: Sendable {
    func execute(_ call: ToolCall) async throws -> String
}

public enum GateOutcome: Sendable, Equatable {
    case executed(output: String)
    case blocked(DenyReason)
    case failed(message: String)
}

/// The only path from a model's tool call to an executor. Every backend adapter calls through here.
public struct PolicyGate: Sendable {
    let engine: PolicyEngine
    let approvals: any ApprovalPresenter
    let executors: [String: any ToolExecutor]

    public init(engine: PolicyEngine, approvals: any ApprovalPresenter, executors: [String: any ToolExecutor]) {
        self.engine = engine
        self.approvals = approvals
        self.executors = executors
    }

    public func run(_ call: ToolCall, in ctx: CallContext) async -> GateOutcome {
        let decision = await engine.evaluate(call, in: ctx)
        switch decision {
        case .deny(let r):
            return .blocked(r)
        case .requireApproval(let reason):
            guard let tool = await engine.descriptor(for: call.toolName) else { return .blocked(.unknownTool) }
            if await approvals.requestApproval(for: call, tool: tool, reason: reason) == .denied {
                return .blocked(.userDenied)
            }
            // Re-check: kill switch may have flipped while the sheet was open.
            if await engine.killSwitchEngaged { return .blocked(.killSwitch) }
        case .allow:
            break
        }
        guard let exec = executors[call.toolName] else { return .blocked(.unknownTool) }
        await engine.recordExecution(taskID: ctx.taskID)
        do {
            return .executed(output: try await exec.execute(call))
        } catch {
            return .failed(message: String(describing: error))
        }
    }
}
