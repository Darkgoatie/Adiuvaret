import Foundation
import Testing
import AdiuvaretCore
@testable import PolicyEngine

@Suite struct ActivityLogTests {
    let call = ToolCall(toolName: "createReminder", argumentsJSON: "{\"title\":\"Call the dentist about the root canal\"}")

    @Test func outcomesAreMapped() {
        #expect(ActivityEntry.make(call, .executed(output: "Created reminder"), asked: true, milliseconds: 40).outcome == .done)
        #expect(ActivityEntry.make(call, .executed(output: "Not done: access denied"), asked: false, milliseconds: 5).outcome == .failed)
        #expect(ActivityEntry.make(call, .failed(message: "boom"), asked: false, milliseconds: 5).outcome == .failed)
        let declined = ActivityEntry.make(call, .blocked(.userDenied), asked: true, milliseconds: 0)
        #expect(declined.outcome == .declined && declined.asked)
        let blocked = ActivityEntry.make(call, .blocked(.killSwitch), asked: false, milliseconds: 0)
        #expect(blocked.outcome == .blocked && blocked.reason == "killSwitch")
    }

    @Test func entriesNeverHoldArgumentsOrResults() throws {
        let e = ActivityEntry.make(call, .executed(output: "Created reminder Call the dentist"), asked: true, milliseconds: 12)
        let json = String(decoding: try JSONEncoder().encode(e), as: UTF8.self)
        #expect(!json.contains("dentist") && !json.contains("root canal"))
        #expect(json.contains("createReminder"))
    }

    @Test func storeKeepsNewestFirstAndCaps() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("activity-\(UUID().uuidString).json")
        let store = ActivityStore(url: url)
        for i in 0..<(ActivityStore.limit + 20) {
            store.record(ActivityEntry(tool: "t\(i)", outcome: .done, asked: false, milliseconds: i))
        }
        #expect(store.all().count == ActivityStore.limit)
        #expect(store.all().first?.tool == "t\(ActivityStore.limit + 19)")
        #expect(ActivityStore(url: url).all().count == ActivityStore.limit)
        store.clear()
        #expect(ActivityStore(url: url).all().isEmpty)
        try? FileManager.default.removeItem(at: url)
    }

    @Test func gateReportsEveryCallOnce() async {
        final class Box: @unchecked Sendable {
            private let lock = NSLock()
            private var items: [String] = []
            func add(_ s: String) { lock.lock(); items.append(s); lock.unlock() }
            var all: [String] { lock.lock(); defer { lock.unlock() }; return items }
        }
        let box = Box()
        let engine = PolicyEngine(tools: allTools)
        let gate = PolicyGate(engine: engine, approvals: FixedApprover(answer: .approved, asked: Counter()),
                              executors: Dictionary(uniqueKeysWithValues: allTools.map { ($0.name, CountingExecutor(runs: Counter()) as any ToolExecutor) }),
                              observer: { call, outcome, asked, _ in
                                  var ran = false
                                  if case .executed = outcome { ran = true }
                                  box.add("\(call.toolName) asked=\(asked) ran=\(ran)")
                              })
        _ = await gate.run(ToolCall(toolName: "calendar.read", argumentsJSON: "{}"), in: ctx())
        _ = await gate.run(ToolCall(toolName: "reminders.create", argumentsJSON: "{}"), in: ctx())
        _ = await gate.run(ToolCall(toolName: "shell.exec", argumentsJSON: "{}"), in: ctx())
        #expect(box.all == ["calendar.read asked=false ran=true", "reminders.create asked=true ran=true", "shell.exec asked=false ran=false"])
    }
}
