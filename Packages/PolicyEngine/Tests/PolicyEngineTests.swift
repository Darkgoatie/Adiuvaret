import Foundation
import Testing
import AdiuvaretCore
@testable import PolicyEngine

let readEvents = ToolDescriptor(name: "calendar.read", summary: "", permission: .readOnly, outputSensitivity: .personal)
let addReminder = ToolDescriptor(name: "reminders.create", summary: "", permission: .reversibleWrite, outputSensitivity: .personal)
let draftMessage = ToolDescriptor(name: "messages.draft", summary: "", permission: .irreversible, outputSensitivity: .personal)
let allTools = [readEvents, addReminder, draftMessage]

func call(_ name: String) -> ToolCall { ToolCall(toolName: name, argumentsJSON: "{}") }
func ctx(task: UUID = UUID(), chat: UUID = UUID(), scheduled: Bool = false, untrusted: Bool = false) -> CallContext {
    CallContext(taskID: task, chatID: chat, isScheduledRun: scheduled, contextContainsUntrusted: untrusted)
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func bump() { lock.lock(); n += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return n }
}

struct FixedApprover: ApprovalPresenter {
    let answer: ApprovalResponse
    let asked: Counter
    func requestApproval(for call: ToolCall, tool: ToolDescriptor, reason: ApprovalReason) async -> ApprovalResponse {
        asked.bump(); return answer
    }
}

struct CountingExecutor: ToolExecutor {
    let runs: Counter
    func execute(_ call: ToolCall) async throws -> String { runs.bump(); return "ok" }
}

@Suite struct Decisions {
    @Test func readOnlyRuns() async {
        let e = PolicyEngine(tools: allTools)
        #expect(await e.evaluate(call("calendar.read"), in: ctx()) == .allow)
    }

    @Test func irreversibleAlwaysAsksEvenWithGrant() async {
        let e = PolicyEngine(tools: allTools)
        await e.grant("messages.draft", scope: .always)
        #expect(await e.evaluate(call("messages.draft"), in: ctx()) == .requireApproval(.irreversible))
    }

    @Test func reversibleWriteAsksWithoutGrant() async {
        let e = PolicyEngine(tools: allTools)
        #expect(await e.evaluate(call("reminders.create"), in: ctx()) == .requireApproval(.writeWithoutGrant))
    }

    @Test func chatGrantOnlyCoversThatChat() async {
        let e = PolicyEngine(tools: allTools)
        let chat = UUID()
        await e.grant("reminders.create", scope: .chat(chat))
        #expect(await e.evaluate(call("reminders.create"), in: ctx(chat: chat)) == .allow)
        #expect(await e.evaluate(call("reminders.create"), in: ctx()) == .requireApproval(.writeWithoutGrant))
    }

    @Test func untrustedContextOverridesGrant() async {
        let e = PolicyEngine(tools: allTools)
        await e.grant("reminders.create", scope: .always)
        #expect(await e.evaluate(call("reminders.create"), in: ctx(untrusted: true)) == .requireApproval(.untrustedContext))
    }

    @Test func scheduledRunsNeverWrite() async {
        let e = PolicyEngine(tools: allTools)
        await e.grant("reminders.create", scope: .always)
        #expect(await e.evaluate(call("reminders.create"), in: ctx(scheduled: true)) == .deny(.scheduledRunWrite))
        #expect(await e.evaluate(call("messages.draft"), in: ctx(scheduled: true)) == .deny(.scheduledRunWrite))
        #expect(await e.evaluate(call("calendar.read"), in: ctx(scheduled: true)) == .allow)
    }

    @Test func killSwitchDeniesEverything() async {
        let e = PolicyEngine(tools: allTools)
        await e.setKillSwitch(true)
        for t in allTools {
            #expect(await e.evaluate(call(t.name), in: ctx()) == .deny(.killSwitch))
        }
    }

    @Test func unknownToolDenied() async {
        let e = PolicyEngine(tools: allTools)
        #expect(await e.evaluate(call("shell.exec"), in: ctx()) == .deny(.unknownTool))
    }
}

@Suite struct Gate {
    func gate(_ e: PolicyEngine, answer: ApprovalResponse, asked: Counter, runs: Counter) -> PolicyGate {
        let ex = CountingExecutor(runs: runs)
        return PolicyGate(engine: e, approvals: FixedApprover(answer: answer, asked: asked),
                          executors: Dictionary(uniqueKeysWithValues: allTools.map { ($0.name, ex as any ToolExecutor) }))
    }

    @Test func deniedApprovalNeverExecutes() async {
        let asked = Counter(), runs = Counter()
        let g = gate(PolicyEngine(tools: allTools), answer: .denied, asked: asked, runs: runs)
        for name in ["reminders.create", "messages.draft"] {
            #expect(await g.run(call(name), in: ctx()) == .blocked(.userDenied))
        }
        #expect(asked.value == 2)
        #expect(runs.value == 0)
    }

    @Test func approvedWriteExecutesOnce() async {
        let asked = Counter(), runs = Counter()
        let g = gate(PolicyEngine(tools: allTools), answer: .approved, asked: asked, runs: runs)
        #expect(await g.run(call("messages.draft"), in: ctx()) == .executed(output: "ok"))
        #expect(runs.value == 1)
    }

    @Test func readRunsWithoutAsking() async {
        let asked = Counter(), runs = Counter()
        let g = gate(PolicyEngine(tools: allTools), answer: .denied, asked: asked, runs: runs)
        #expect(await g.run(call("calendar.read"), in: ctx()) == .executed(output: "ok"))
        #expect(asked.value == 0)
    }

    @Test func rateLimitStopsLoop() async {
        let asked = Counter(), runs = Counter()
        let e = PolicyEngine(tools: allTools, limits: PolicyLimits(maxToolCallsPerTask: 3))
        let g = gate(e, answer: .approved, asked: asked, runs: runs)
        let c = ctx()
        for _ in 0..<3 { _ = await g.run(call("calendar.read"), in: c) }
        #expect(await g.run(call("calendar.read"), in: c) == .blocked(.rateLimited))
        #expect(runs.value == 3)
    }

    @Test func injectionInUntrustedContextCannotSkipApproval() async {
        let asked = Counter(), runs = Counter()
        let e = PolicyEngine(tools: allTools)
        await e.grant("reminders.create", scope: .always)
        let g = gate(e, answer: .denied, asked: asked, runs: runs)
        #expect(await g.run(call("reminders.create"), in: ctx(untrusted: true)) == .blocked(.userDenied))
        #expect(runs.value == 0)
    }
}
