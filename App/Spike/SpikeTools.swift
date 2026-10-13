import Foundation
import EventKit
import FoundationModels
import AdiuvaretCore
import PolicyEngine

/// Task-level state the policy engine needs: ids and whether untrusted data entered the context.
final class SpikeContext: @unchecked Sendable {
    let taskID = UUID()
    let chatID = UUID()
    private let lock = NSLock()
    private var untrusted = false

    func markUntrusted() { lock.lock(); untrusted = true; lock.unlock() }

    func callContext() -> CallContext {
        lock.lock(); defer { lock.unlock() }
        return CallContext(taskID: taskID, chatID: chatID, contextContainsUntrusted: untrusted)
    }
}

enum SpikeDescriptors {
    static let readCalendar = ToolDescriptor(name: "readCalendar", summary: "Lists calendar events for a day.", permission: .readOnly, outputSensitivity: .personal)
    static let createReminder = ToolDescriptor(name: "createReminder", summary: "Creates a reminder.", permission: .reversibleWrite, outputSensitivity: .personal)
    static let all = [readCalendar, createReminder]
}

struct CalendarExecutor: ToolExecutor {
    func execute(_ call: ToolCall) async throws -> String {
        let args = try JSONSerialization.jsonObject(with: Data(call.argumentsJSON.utf8)) as? [String: Any] ?? [:]
        let offset = (args["dayOffset"] as? Int) ?? 0
        let store = EKEventStore()
        guard try await store.requestFullAccessToEvents() else { return "Calendar access denied." }
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date()))!
        let end = cal.date(byAdding: .day, value: 1, to: day)!
        let events = store.events(matching: store.predicateForEvents(withStart: day, end: end, calendars: nil))
            .sorted { $0.startDate < $1.startDate }
            .prefix(8)
        if events.isEmpty { return "No events." }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return events.map { "\(f.string(from: $0.startDate)) \(String(($0.title ?? "Untitled").prefix(40)))" }.joined(separator: "\n")
    }
}

struct ReminderExecutor: ToolExecutor {
    func execute(_ call: ToolCall) async throws -> String {
        let args = try JSONSerialization.jsonObject(with: Data(call.argumentsJSON.utf8)) as? [String: Any] ?? [:]
        let title = (args["title"] as? String) ?? "Reminder"
        let minutes = (args["dueInMinutes"] as? Int) ?? 60
        let store = EKEventStore()
        guard try await store.requestFullAccessToReminders() else { return "Reminders access denied." }
        let r = EKReminder(eventStore: store)
        r.title = title
        r.calendar = store.defaultCalendarForNewReminders()
        let due = Date().addingTimeInterval(Double(minutes) * 60)
        r.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        try store.save(r, commit: true)
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "Created reminder \(title) due \(f.string(from: due))."
    }
}

@available(iOS 26.0, *)
struct ReadCalendarTool: Tool {
    let name = "readCalendar"
    let description = "Lists calendar events for a day."
    let gate: PolicyGate
    let ctx: SpikeContext

    @Generable
    struct Arguments {
        @Guide(description: "0 is today, 1 is tomorrow")
        var dayOffset: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let json = "{\"dayOffset\":\(arguments.dayOffset)}"
        let outcome = await gate.run(ToolCall(toolName: name, argumentsJSON: json), in: ctx.callContext())
        return SpikeOutcome.text(outcome, markUntrusted: ctx)
    }
}

@available(iOS 26.0, *)
struct CreateReminderTool: Tool {
    let name = "createReminder"
    let description = "Creates a reminder."
    let gate: PolicyGate
    let ctx: SpikeContext

    @Generable
    struct Arguments {
        var title: String
        @Guide(description: "Minutes from now")
        var dueInMinutes: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let payload: [String: Any] = ["title": arguments.title, "dueInMinutes": arguments.dueInMinutes]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let outcome = await gate.run(ToolCall(toolName: name, argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext())
        return SpikeOutcome.text(outcome, markUntrusted: nil)
    }
}

enum SpikeOutcome {
    /// Maps gate results to a short string for the model. Never throws: a throw would end the session.
    static func text(_ o: GateOutcome, markUntrusted ctx: SpikeContext?) -> String {
        switch o {
        case .executed(let out): ctx?.markUntrusted(); return out
        case .blocked(let r): return "Not done: \(r)."
        case .failed(let m): return "Failed: \(m)"
        }
    }
}

@available(iOS 26.0, *)
struct DummyTool: Tool {
    let name: String
    let description = "Returns a short note."

    @Generable
    struct Arguments {
        var topic: String
    }

    func call(arguments: Arguments) async throws -> String { "note" }
}
