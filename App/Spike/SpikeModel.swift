import Foundation
import Observation
import FoundationModels
import AdiuvaretCore
import PolicyEngine

struct PendingApproval: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let resume: CheckedContinuation<ApprovalResponse, Never>
}

@available(iOS 26.0, *)
@MainActor @Observable
final class SpikeModel {
    var prompt = ""
    var output = ""
    var report = ""
    var running = false
    var pending: PendingApproval?

    func ask(call: ToolCall, tool: ToolDescriptor) async -> ApprovalResponse {
        await withCheckedContinuation { c in
            pending = PendingApproval(title: tool.name, detail: call.argumentsJSON, resume: c)
        }
    }

    func answer(_ r: ApprovalResponse) {
        pending?.resume.resume(returning: r)
        pending = nil
    }

    func send() async {
        guard !running, !prompt.isEmpty else { return }
        running = true; output = ""
        defer { running = false }
        let ctx = SpikeContext()
        let engine = PolicyEngine(tools: SpikeDescriptors.all)
        let gate = PolicyGate(engine: engine, approvals: ModelApprover(model: self),
                              executors: ["readCalendar": CalendarExecutor(), "createReminder": ReminderExecutor()])
        let session = LanguageModelSession(
            tools: [ReadCalendarTool(gate: gate, ctx: ctx), CreateReminderTool(gate: gate, ctx: ctx)],
            instructions: "You manage the user's calendar and reminders. Use tools. Be brief."
        )
        let start = Date()
        var first: TimeInterval?
        do {
            for try await partial in session.streamResponse(to: prompt) {
                if first == nil { first = Date().timeIntervalSince(start) }
                output = partial.content
            }
            let total = Date().timeIntervalSince(start)
            report += String(format: "send ok: ttft %.2fs total %.2fs prompt \"%@\"\n", first ?? -1, total, prompt)
            report += toolTrace(session)
        } catch {
            output = "Error: \(error)"
            report += "send error: \(error)\n"
        }
    }

    private func toolTrace(_ s: LanguageModelSession) -> String {
        var o = ""
        for e in s.transcript {
            switch e {
            case .toolCalls(let c): o += "  toolCalls: \(c.map { $0.toolName })\n"
            case .toolOutput(let t): o += "  toolOutput: \(t.toolName)\n"
            default: break
            }
        }
        return o
    }

    func contextReport() async {
        running = true; defer { running = false }
        let m = SystemLanguageModel.default
        report += "availability: \(m.availability)\n"
        if #available(iOS 26.4, *) {
            report += "contextSize: \(m.contextSize)\n"
            for n in 1...8 {
                let tools: [any Tool] = (1...n).map { DummyTool(name: "tool\($0)") }
                let tokens = (try? await m.tokenCount(for: tools)) ?? -1
                let session = LanguageModelSession(tools: tools, instructions: "Be brief.")
                let t0 = Date()
                var status = "ok"
                do { _ = try await session.respond(to: "Say hello.") } catch { status = "error \(error)" }
                report += String(format: "tools %d: toolTokens %d, respond %@ in %.2fs\n", n, tokens, status, Date().timeIntervalSince(t0))
            }
        } else {
            report += "contextSize needs iOS 26.4+\n"
        }
    }
}

@available(iOS 26.0, *)
struct ModelApprover: ApprovalPresenter {
    let model: SpikeModel
    func requestApproval(for call: ToolCall, tool: ToolDescriptor, reason: ApprovalReason) async -> ApprovalResponse {
        await model.ask(call: call, tool: tool)
    }
}
