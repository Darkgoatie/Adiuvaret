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

enum CalendarRange {
    static let iso: DateFormatter = {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; return f
    }()

    /// Resolves a yyyy-MM-dd string (empty means today) plus a day count to a half-open range.
    static func resolve(startDate: String, days: Int, now: Date = Date(), calendar cal: Calendar = .current) -> (start: Date, end: Date)? {
        let trimmed = startDate.trimmingCharacters(in: .whitespaces)
        var base = cal.startOfDay(for: now)
        if !trimmed.isEmpty {
            guard let d = iso.date(from: trimmed) else { return nil }
            let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: d)
            guard let local = cal.date(from: c) else { return nil }
            base = cal.startOfDay(for: local)
        }
        guard let end = cal.date(byAdding: .day, value: min(max(days, 1), 31), to: base) else { return nil }
        return (base, end)
    }
}

struct LiveCalendarExecutor: ToolExecutor {
    func execute(_ call: ToolCall) async throws -> String {
        let args = try JSONSerialization.jsonObject(with: Data(call.argumentsJSON.utf8)) as? [String: Any] ?? [:]
        let startText = (args["startDate"] as? String) ?? ""
        let days = (args["days"] as? Int) ?? 1
        guard let range = CalendarRange.resolve(startDate: startText, days: days) else {
            return "Invalid date '\(startText)'. Use yyyy-MM-dd."
        }
        let store = EKEventStore()
        guard try await store.requestFullAccessToEvents() else { return "Calendar access denied." }
        let cal = Calendar.current
        let all = store.events(matching: store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil))
            .sorted { $0.startDate < $1.startDate }
        let lastDay = cal.date(byAdding: .day, value: -1, to: range.end) ?? range.end
        let header = "Checked \(CalendarRange.iso.string(from: range.start)) to \(CalendarRange.iso.string(from: lastDay)) in \(store.sources.count) accounts."
        if all.isEmpty { return "No events. " + header }
        let shown = all.prefix(40)
        let day = DateFormatter(); day.dateFormat = "EEE d MMM"
        let hm = DateFormatter(); hm.dateFormat = "HH:mm"
        var lines = shown.map { e -> String in
            let when = e.isAllDay ? "all day" : "\(hm.string(from: e.startDate))-\(hm.string(from: e.endDate))"
            let title = String((e.title ?? "Untitled").prefix(60))
            let where_ = e.calendar.map { " [\($0.title)]" } ?? ""
            return "\(day.string(from: e.startDate)) \(when) \(title)\(where_)"
        }
        if all.count > shown.count { lines.append("(\(all.count - shown.count) more not shown)") }
        return ([header] + lines).joined(separator: "\n")
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
        @Guide(description: "First day to read as yyyy-MM-dd, for example 2026-10-20. Empty means today.")
        var startDate: String
        @Guide(description: "Number of days to read from startDate, 1 to 31. Use 7 for a week.")
        var days: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let id = UUID()
        await reporter.toolStarted(id, title: String(localized: "Checking your calendar…"))
        let payload: [String: Any] = ["startDate": arguments.startDate, "days": arguments.days]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
        let outcome = await gate.run(ToolCall(toolName: name, argumentsJSON: json), in: ctx.callContext())
        switch outcome {
        case .executed(let out):
            ctx.markUntrusted()
            let all = out.split(separator: "\n").map(String.init)
            let lines = all.filter { !$0.hasPrefix("Checked") && !$0.hasPrefix("No events") && !$0.hasPrefix("(") }
            let count = lines.count
            let title = lines.isEmpty ? String(localized: "Looked at calendar · no events")
                                      : String(localized: "Looked at calendar · \(count) events")
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
