import Foundation
import EventKit
import FoundationModels
import AdiuvaretCore
import PolicyEngine
import ToolKit

/// Per-task state the policy engine needs. A new task id is issued for every user message.
final class TaskContext: @unchecked Sendable {
    let chatID = UUID()
    private let lock = NSLock()
    private var taskID = UUID()
    private var untrusted = false
    private var personal = false
    private var userMessage = ""
    private var privateText = ""

    func beginTask(message: String = "") { lock.lock(); taskID = UUID(); untrusted = false; personal = false; userMessage = message; privateText = ""; lock.unlock() }
    /// Calendar or reminder text read in this task, kept only to stop it reaching a search.
    func notePrivate(_ text: String) { lock.lock(); privateText += " " + text.prefix(4000); lock.unlock() }
    func scrub(_ query: String) -> QueryScrubber.Result { lock.lock(); defer { lock.unlock() }; return QueryScrubber.scrub(query: query, userMessage: userMessage, privateText: privateText) }
    /// `personal` is true for calendar and reminder content, false for web pages.
    func markUntrusted(personal: Bool = true) { lock.lock(); untrusted = true; if personal { self.personal = true }; lock.unlock() }
    func sawPersonalData() -> Bool { lock.lock(); defer { lock.unlock() }; return personal }
    func callContext() -> CallContext {
        lock.lock(); defer { lock.unlock() }
        return CallContext(taskID: taskID, chatID: chatID, contextContainsUntrusted: untrusted)
    }
}

/// What the chat screen hears about while tools run.
protocol ToolReporter: Sendable {
    func toolStarted(_ id: UUID, title: String) async
    func toolFinished(_ id: UUID, title: String, details: [String], failed: Bool) async
    func actionDone(title: String, detail: String, undo: UndoAction?) async
}

/// How to take back a finished action.
enum UndoAction: Sendable {
    case removeReminder(id: String)
    case removeEvent(id: String)
    case restoreEvent(id: String, start: Date, end: Date)
}

enum LiveDescriptors {
    static let readCalendar = ToolDescriptor(name: "readCalendar", summary: "Lists calendar events for a day.", permission: .readOnly, outputSensitivity: .personal)
    static let createReminder = ToolDescriptor(name: "createReminder", summary: "Creates a reminder.", permission: .reversibleWrite, outputSensitivity: .personal)
    static let findFreeTime = ToolDescriptor(name: "findFreeTime", summary: "Finds free time slots.", permission: .readOnly, outputSensitivity: .personal)
    static let createEvent = ToolDescriptor(name: "createEvent", summary: "Creates a calendar event.", permission: .reversibleWrite, outputSensitivity: .personal)
    static let moveEvent = ToolDescriptor(name: "moveEvent", summary: "Moves a calendar event.", permission: .reversibleWrite, outputSensitivity: .personal)
    static let deleteEvent = ToolDescriptor(name: "deleteEvent", summary: "Deletes a calendar event.", permission: .irreversible, outputSensitivity: .personal)
    static let listReminders = ToolDescriptor(name: "listReminders", summary: "Lists open reminders.", permission: .readOnly, outputSensitivity: .personal)
    static let searchWeb = ToolDescriptor(name: "searchWeb", summary: "Searches the web.", permission: .readOnly, outputSensitivity: .personal)
    static let openWebsite = ToolDescriptor(name: "openWebsite", summary: "Opens a website.", permission: .readOnly, outputSensitivity: .personal)
    static let lookAtPage = ToolDescriptor(name: "lookAtPage", summary: "Reads the open page.", permission: .readOnly, outputSensitivity: .personal)
    static let actOnPage = ToolDescriptor(name: "actOnPage", summary: "Clicks or types on the open page.", permission: .readOnly, outputSensitivity: .personal)
    /// Opening a site the chat has not visited, with strict mode on. Always asks.
    static let openOtherSite = ToolDescriptor(name: "openOtherSite", summary: "Opens a different website.", permission: .reversibleWrite, outputSensitivity: .personal)
    /// A click that could buy, send, delete or sign in. Always asks and cannot be undone.
    static let actOnPageRisky = ToolDescriptor(name: "actOnPageRisky", summary: "Does something on a page that cannot be undone.", permission: .irreversible, outputSensitivity: .personal)
    static let searchNotes = ToolDescriptor(name: "searchNotes", summary: "Searches the notes folder.", permission: .readOnly, outputSensitivity: .personal)
    static let readNote = ToolDescriptor(name: "readNote", summary: "Reads one note.", permission: .readOnly, outputSensitivity: .personal)
    static let writeNote = ToolDescriptor(name: "writeNote", summary: "Creates or extends a note.", permission: .reversibleWrite, outputSensitivity: .personal)
    static let findContact = ToolDescriptor(name: "findContact", summary: "Looks up a contact.", permission: .readOnly, outputSensitivity: .sensitive)
    static let runShortcut = ToolDescriptor(name: "runShortcut", summary: "Runs a shortcut.", permission: .reversibleWrite, outputSensitivity: .personal)
    static let draftEmail = ToolDescriptor(name: "draftEmail", summary: "Opens a mail draft.", permission: .reversibleWrite, outputSensitivity: .personal)
    static let all = [readCalendar, findFreeTime, createEvent, moveEvent, deleteEvent, createReminder, listReminders,
                      searchWeb, openWebsite, lookAtPage, actOnPage, openOtherSite, actOnPageRisky,
                      searchNotes, readNote, writeNote, findContact, runShortcut, draftEmail]
}

enum CalendarRange {
    static let iso: DateFormatter = {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; return f
    }()
}

struct LiveCalendarExecutor: ToolExecutor {
    let handles: EventHandles

    func execute(_ call: ToolCall) async throws -> String {
        let args = try JSONSerialization.jsonObject(with: Data(call.argumentsJSON.utf8)) as? [String: Any] ?? [:]
        let startText = (args["startDate"] as? String) ?? ""
        let days = (args["days"] as? Int) ?? 1
        let search = (args["search"] as? String) ?? ""
        guard let range = CalendarMath.range(startDate: startText, days: days) else {
            return "Invalid date '\(startText)'. Use yyyy-MM-dd."
        }
        let store = EKEventStore()
        guard try await store.requestFullAccessToEvents() else { return "Calendar access denied." }
        let cal = Calendar.current
        let slots = CalendarStore.slots(store, start: range.start, end: range.end, handles: handles)
        let all = CalendarMath.filter(slots, query: search)
        let lastDay = cal.date(byAdding: .day, value: -1, to: range.end) ?? range.end
        let header = "Checked \(CalendarMath.dayString(range.start)) to \(CalendarMath.dayString(lastDay)) in \(store.sources.count) accounts" + (search.isEmpty ? "." : " for '\(search)'.")
        if all.isEmpty { return "No events. " + header }
        let shown = all.prefix(40)
        var lines = shown.map(CalendarStore.line)
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
        let shown = DateFormatter(); shown.dateStyle = .medium; shown.timeStyle = .short
        await reporter.actionDone(title: String(localized: "Added \(title) to Reminders"), detail: shown.string(from: due), undo: .removeReminder(id: r.calendarItemIdentifier))
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
        @Guide(description: "Optional words to look for in event titles or calendar names. Empty lists everything.")
        var search: String
    }

    func call(arguments: Arguments) async throws -> String {
        let id = UUID()
        await reporter.toolStarted(id, title: String(localized: "Checking your calendar…"))
        let payload: [String: Any] = ["startDate": arguments.startDate, "days": arguments.days, "search": arguments.search]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
        let outcome = await gate.run(ToolCall(toolName: name, argumentsJSON: json), in: ctx.callContext())
        switch outcome {
        case .executed(let out):
            ctx.markUntrusted(); ctx.notePrivate(out)
            let all = out.split(separator: "\n").map(String.init)
            let lines = all.filter { !$0.hasPrefix("Checked") && !$0.hasPrefix("No events") && !$0.hasPrefix("(") }.map { l in
                l.split(separator: " ", maxSplits: 1).dropFirst().first.map(String.init) ?? l
            }
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
