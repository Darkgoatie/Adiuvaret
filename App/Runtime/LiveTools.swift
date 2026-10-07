import Foundation
import EventKit
import FoundationModels
import AdiuvaretCore
import PolicyEngine

/// Per-task state the policy engine needs. A new task id is issued for every user message.
final class TaskContext: @unchecked Sendable {
    let chatID = UUID()
    private let lock = NSLock()
    private var taskID = UUID()
    private var untrusted = false

    func beginTask() { lock.lock(); taskID = UUID(); untrusted = false; lock.unlock() }
    func markUntrusted() { lock.lock(); untrusted = true; lock.unlock() }
    func callContext() -> CallContext {
        lock.lock(); defer { lock.unlock() }
        return CallContext(taskID: taskID, chatID: chatID, contextContainsUntrusted: untrusted)
    }
}

/// What the chat screen hears about while tools run.
protocol ToolReporter: Sendable {
    func toolStarted(_ id: UUID, title: String) async
    func toolFinished(_ id: UUID, title: String, details: [String], failed: Bool) async
    func reminderCreated(id: String, title: String, due: Date) async
}

enum LiveDescriptors {
    static let readCalendar = ToolDescriptor(name: "readCalendar", summary: "Lists calendar events for a day.", permission: .readOnly, outputSensitivity: .personal)
    static let createReminder = ToolDescriptor(name: "createReminder", summary: "Creates a reminder.", permission: .reversibleWrite, outputSensitivity: .personal)
    static let all = [readCalendar, createReminder]
}

struct LiveCalendarExecutor: ToolExecutor {
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
            .prefix(10)
        if events.isEmpty { return "No events." }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return events.map { "\(f.string(from: $0.startDate)) \(String(($0.title ?? "Untitled").prefix(60)))" }.joined(separator: "\n")
    }
}

struct LiveReminderExecutor: ToolExecutor {
    let reporter: any ToolReporter

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
        await reporter.reminderCreated(id: r.calendarItemIdentifier, title: title, due: due)
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "Created reminder \(title) due \(f.string(from: due))."
    }
}

enum ReminderUndo {
    static func remove(id: String) async -> Bool {
        let store = EKEventStore()
        guard (try? await store.requestFullAccessToReminders()) == true,
              let item = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }
        return (try? store.remove(item, commit: true)) != nil
    }
}

struct LiveReadCalendarTool: Tool {
    let name = "readCalendar"
    let description = "Lists the user's calendar events for one day."
    let gate: PolicyGate
    let ctx: TaskContext
    let reporter: any ToolReporter

    @Generable
    struct Arguments {
        @Guide(description: "0 is today, 1 is tomorrow, -1 is yesterday")
        var dayOffset: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let id = UUID()
        await reporter.toolStarted(id, title: String(localized: "Checking your calendar…"))
        let json = "{\"dayOffset\":\(arguments.dayOffset)}"
        let outcome = await gate.run(ToolCall(toolName: name, argumentsJSON: json), in: ctx.callContext())
        switch outcome {
        case .executed(let out):
            ctx.markUntrusted()
            let lines = out == "No events." ? [] : out.split(separator: "\n").map(String.init)
            let title = lines.isEmpty ? String(localized: "Looked at calendar · no events")
                                      : String(localized: "Looked at calendar · \(lines.count) events")
            await reporter.toolFinished(id, title: title, details: lines, failed: false)
            return out
        case .blocked(let r):
            await reporter.toolFinished(id, title: String(localized: "Couldn't read your calendar"), details: [], failed: true)
            return "Not done: \(r)."
        case .failed(let m):
            await reporter.toolFinished(id, title: String(localized: "Couldn't read your calendar"), details: [], failed: true)
            return "Failed: \(m)"
        }
    }
}

struct LiveCreateReminderTool: Tool {
    let name = "createReminder"
    let description = "Creates a reminder for the user. Ask the user to approve; do not claim it was created unless the result says so."
    let gate: PolicyGate
    let ctx: TaskContext
    let reporter: any ToolReporter

    @Generable
    struct Arguments {
        var title: String
        @Guide(description: "Minutes from now until the reminder is due")
        var dueInMinutes: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let payload: [String: Any] = ["title": arguments.title, "dueInMinutes": arguments.dueInMinutes]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let outcome = await gate.run(ToolCall(toolName: name, argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext())
        switch outcome {
        case .executed(let out): return out
        case .blocked(let r): return "Not done: \(r). Tell the user nothing was created."
        case .failed(let m): return "Failed: \(m)"
        }
    }
}
