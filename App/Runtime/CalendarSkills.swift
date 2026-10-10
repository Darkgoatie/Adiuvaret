import Foundation
import EventKit
import FoundationModels
import AdiuvaretCore
import PolicyEngine
import ToolKit

/// Short ids ("e1", "e2") the model uses to point at events it has read. Maps back to an EventKit identifier and start time.
final class EventHandles: @unchecked Sendable {
    private let lock = NSLock()
    private var byHandle: [String: (id: String, start: Date)] = [:]
    private var byKey: [String: String] = [:]
    private var next = 1

    func handle(for id: String, start: Date) -> String {
        lock.lock(); defer { lock.unlock() }
        let key = "\(id)|\(start.timeIntervalSince1970)"
        if let h = byKey[key] { return h }
        let h = "e\(next)"; next += 1
        byKey[key] = h; byHandle[h] = (id, start)
        return h
    }

    func resolve(_ handle: String) -> (id: String, start: Date)? {
        lock.lock(); defer { lock.unlock() }
        return byHandle[handle.trimmingCharacters(in: .whitespaces).lowercased()]
    }
}

enum CalendarStore {
    /// "Work · Google" style label, so events from different accounts can be told apart. The account name is left out when it repeats the calendar name.
    static func label(_ calendar: EKCalendar?) -> String {
        guard let calendar else { return "" }
        let account = calendar.source?.title ?? ""
        return account.isEmpty || account == calendar.title ? calendar.title : "\(calendar.title) · \(account)"
    }

    static func slots(_ store: EKEventStore, start: Date, end: Date, handles: EventHandles) -> [EventSlot] {
        store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
            .sorted { $0.startDate < $1.startDate }
            .map { e in
                EventSlot(id: handles.handle(for: e.eventIdentifier ?? e.calendarItemIdentifier, start: e.startDate),
                          title: e.title ?? "Untitled", start: e.startDate, end: e.endDate, isAllDay: e.isAllDay, calendar: Self.label(e.calendar))
            }
    }

    static func line(_ e: EventSlot) -> String {
        let day = DateFormatter(); day.dateFormat = "EEE d MMM"
        let hm = DateFormatter(); hm.dateFormat = "HH:mm"
        let when = e.isAllDay ? "all day" : "\(hm.string(from: e.start))-\(hm.string(from: e.end))"
        return "\(e.id) \(day.string(from: e.start)) \(when) \(String(e.title.prefix(60))) [\(e.calendar)]"
    }

    static func event(_ store: EKEventStore, handle: String, handles: EventHandles) -> EKEvent? {
        guard let h = handles.resolve(handle) else { return nil }
        let window = store.predicateForEvents(withStart: h.start.addingTimeInterval(-1), end: h.start.addingTimeInterval(1), calendars: nil)
        return store.events(matching: window).first { ($0.eventIdentifier ?? $0.calendarItemIdentifier) == h.id && abs($0.startDate.timeIntervalSince(h.start)) < 1 }
    }

    static func args(_ call: ToolCall) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(call.argumentsJSON.utf8)) as? [String: Any]) ?? [:]
    }

    static func access() async -> Bool { (try? await EKEventStore().requestFullAccessToEvents()) == true }
}

struct FreeTimeExecutor: ToolExecutor {
    func execute(_ call: ToolCall) async throws -> String {
        let a = CalendarStore.args(call)
        let minutes = max(15, min((a["minutes"] as? Int) ?? 30, 480))
        guard let range = CalendarMath.range(startDate: (a["startDate"] as? String) ?? "", days: (a["days"] as? Int) ?? 1) else { return "Invalid date. Use yyyy-MM-dd." }
        let store = EKEventStore()
        guard try await store.requestFullAccessToEvents() else { return "Calendar access denied." }
        let events = CalendarStore.slots(store, start: range.start, end: range.end, handles: EventHandles())
        let free = CalendarMath.freeSlots(events, in: range, minMinutes: minutes)
        let last = Calendar.current.date(byAdding: .day, value: -1, to: range.end) ?? range.end
        let header = "Free slots of at least \(minutes) min between 08:00 and 20:00, \(CalendarMath.dayString(range.start)) to \(CalendarMath.dayString(last))."
        if free.isEmpty { return "No free slots. " + header }
        let day = DateFormatter(); day.dateFormat = "EEE d MMM"
        let hm = DateFormatter(); hm.dateFormat = "HH:mm"
        return ([header] + free.prefix(20).map { "\(day.string(from: $0.start)) \(hm.string(from: $0.start))-\(hm.string(from: $0.end))" }).joined(separator: "\n")
    }
}

struct CreateEventExecutor: ToolExecutor {
    let reporter: any ToolReporter
    private static func label(_ c: EKCalendar) -> String { CalendarStore.label(c) }
    func execute(_ call: ToolCall) async throws -> String {
        let a = CalendarStore.args(call)
        let title = ((a["title"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "No title given." }
        guard let start = CalendarMath.dateTime((a["start"] as? String) ?? "") else { return "Invalid start. Use yyyy-MM-dd HH:mm." }
        let minutes = max(5, min((a["durationMinutes"] as? Int) ?? 60, 1440))
        let store = EKEventStore()
        guard try await store.requestFullAccessToEvents() else { return "Calendar access denied." }
        guard let calendar = CalendarChoice.target(in: store) else { return "No calendar can take new events." }
        let e = EKEvent(eventStore: store)
        e.title = title; e.startDate = start; e.endDate = start.addingTimeInterval(Double(minutes) * 60); e.calendar = calendar
        try store.save(e, span: .thisEvent, commit: true)
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        await reporter.actionDone(title: String(localized: "Added \(title) to Calendar"), detail: f.string(from: start),
                                  undo: .removeEvent(id: e.eventIdentifier ?? e.calendarItemIdentifier))
        return "Created event \(title) on \(f.string(from: start)) in \(Self.label(calendar))."
    }
}

struct MoveEventExecutor: ToolExecutor {
    let reporter: any ToolReporter
    let handles: EventHandles
    func execute(_ call: ToolCall) async throws -> String {
        let a = CalendarStore.args(call)
        guard let newStart = CalendarMath.dateTime((a["newStart"] as? String) ?? "") else { return "Invalid newStart. Use yyyy-MM-dd HH:mm." }
        let store = EKEventStore()
        guard try await store.requestFullAccessToEvents() else { return "Calendar access denied." }
        guard let e = CalendarStore.event(store, handle: (a["event"] as? String) ?? "", handles: handles) else { return "Event not found. Read the calendar again to get its id." }
        guard e.calendar?.allowsContentModifications == true else { return "That calendar is read-only." }
        let oldStart = e.startDate!, oldEnd = e.endDate!
        let length = oldEnd.timeIntervalSince(oldStart)
        e.startDate = newStart; e.endDate = newStart.addingTimeInterval(length)
        try store.save(e, span: .thisEvent, commit: true)
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        await reporter.actionDone(title: String(localized: "Moved \(e.title ?? "event")"), detail: f.string(from: newStart),
                                  undo: .restoreEvent(id: e.eventIdentifier ?? e.calendarItemIdentifier, start: oldStart, end: oldEnd))
        return "Moved \(e.title ?? "event") to \(f.string(from: newStart))."
    }
}

struct DeleteEventExecutor: ToolExecutor {
    let reporter: any ToolReporter
    let handles: EventHandles
    func execute(_ call: ToolCall) async throws -> String {
        let a = CalendarStore.args(call)
        let store = EKEventStore()
        guard try await store.requestFullAccessToEvents() else { return "Calendar access denied." }
        guard let e = CalendarStore.event(store, handle: (a["event"] as? String) ?? "", handles: handles) else { return "Event not found. Read the calendar again to get its id." }
        guard e.calendar?.allowsContentModifications == true else { return "That calendar is read-only." }
        let title = e.title ?? "event", when = e.startDate!
        try store.remove(e, span: .thisEvent, commit: true)
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        await reporter.actionDone(title: String(localized: "Deleted \(title)"), detail: f.string(from: when), undo: nil)
        return "Deleted \(title) from \(f.string(from: when))."
    }
}

enum EventUndo {
    static func run(_ action: UndoAction) async -> Bool {
        let store = EKEventStore()
        guard (try? await store.requestFullAccessToEvents()) == true else { return false }
        switch action {
        case .removeEvent(let id):
            guard let e = store.event(withIdentifier: id) else { return false }
            return (try? store.remove(e, span: .thisEvent, commit: true)) != nil
        case .restoreEvent(let id, let start, let end):
            guard let e = store.event(withIdentifier: id) else { return false }
            e.startDate = start; e.endDate = end
            return (try? store.save(e, span: .thisEvent, commit: true)) != nil
        case .removeReminder(let id):
            return await ReminderUndo.remove(id: id)
        case .removeTodoist(let id):
            return (try? await ServiceClient.send(ServiceRequest.todoistDelete(id: id), to: "todoist")) != nil
        }
    }
}

// MARK: tools the model sees

private func report(_ gate: PolicyGate, _ ctx: TaskContext, name: String, json: [String: Any]) async -> GateOutcome {
    let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
    return await gate.run(ToolCall(toolName: name, argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext())
}

private func text(_ o: GateOutcome, nothingDone: String) -> String {
    switch o {
    case .executed(let out): out
    case .blocked(let r): "Not done: \(r). \(nothingDone)"
    case .failed(let m): "Failed: \(m)"
    }
}

struct LiveFreeTimeTool: Tool {
    let name = "findFreeTime"
    let description = "Finds free time slots in the user's calendar between 08:00 and 20:00."
    let gate: PolicyGate; let ctx: TaskContext

    @Generable
    struct Arguments {
        @Guide(description: "First day as yyyy-MM-dd. Empty means today.") var startDate: String
        @Guide(description: "Number of days, 1 to 31") var days: Int
        @Guide(description: "Shortest slot in minutes, for example 30 or 60") var minutes: Int
    }

    func call(arguments a: Arguments) async throws -> String {
        text(await report(gate, ctx, name: name, json: ["startDate": a.startDate, "days": a.days, "minutes": a.minutes]), nothingDone: "")
    }
}

struct LiveCreateEventTool: Tool {
    let name = "createEvent"
    let description = "Creates a calendar event. The user must approve. Do not say it was created unless the result says so."
    let gate: PolicyGate; let ctx: TaskContext

    @Generable
    struct Arguments {
        var title: String
        @Guide(description: "Start as yyyy-MM-dd HH:mm in the user's time zone") var start: String
        @Guide(description: "Length in minutes, 60 if the user did not say") var durationMinutes: Int
    }

    func call(arguments a: Arguments) async throws -> String {
        text(await report(gate, ctx, name: name, json: ["title": a.title, "start": a.start, "durationMinutes": a.durationMinutes]), nothingDone: "Tell the user nothing was created.")
    }
}

struct LiveMoveEventTool: Tool {
    let name = "moveEvent"
    let description = "Moves an event the user has just seen to a new start time, keeping its length. Needs the event id from readCalendar. The user must approve."
    let gate: PolicyGate; let ctx: TaskContext

    @Generable
    struct Arguments {
        @Guide(description: "Event id such as e3, from readCalendar") var event: String
        @Guide(description: "New start as yyyy-MM-dd HH:mm") var newStart: String
    }

    func call(arguments a: Arguments) async throws -> String {
        text(await report(gate, ctx, name: name, json: ["event": a.event, "newStart": a.newStart]), nothingDone: "Tell the user nothing was moved.")
    }
}

struct LiveDeleteEventTool: Tool {
    let name = "deleteEvent"
    let description = "Deletes an event the user has just seen. Needs the event id from readCalendar. The user must confirm."
    let gate: PolicyGate; let ctx: TaskContext

    @Generable
    struct Arguments {
        @Guide(description: "Event id such as e3, from readCalendar") var event: String
    }

    func call(arguments a: Arguments) async throws -> String {
        text(await report(gate, ctx, name: name, json: ["event": a.event]), nothingDone: "Tell the user nothing was deleted.")
    }
}
