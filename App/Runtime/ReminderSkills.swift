import Foundation
import EventKit
import FoundationModels
import AdiuvaretCore
import PolicyEngine
import ToolKit

struct ListRemindersExecutor: ToolExecutor {
    func execute(_ call: ToolCall) async throws -> String {
        let a = CalendarStore.args(call)
        let search = (a["search"] as? String) ?? ""
        let store = EKEventStore()
        guard try await store.requestFullAccessToReminders() else { return "Reminders access denied." }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        let rows: [(title: String, due: Date?, list: String)] = await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { found in
                cont.resume(returning: (found ?? []).map { r in
                    (r.title ?? "Untitled", r.dueDateComponents.flatMap { Calendar.current.date(from: $0) }, r.calendar?.title ?? "")
                })
            }
        }
        let slots = rows.map { EventSlot(id: "", title: $0.title, start: $0.due ?? .distantFuture, end: $0.due ?? .distantFuture, calendar: $0.list) }
        let matched = CalendarMath.filter(slots, query: search).sorted { $0.start < $1.start }
        if matched.isEmpty { return search.isEmpty ? "No open reminders." : "No open reminders matching '\(search)'." }
        let f = DateFormatter(); f.dateFormat = "EEE d MMM HH:mm"
        let lines = matched.prefix(30).map { s in
            (s.start == .distantFuture ? "no date" : f.string(from: s.start)) + " " + String(s.title.prefix(60)) + " [\(s.calendar)]"
        }
        return (["\(matched.count) open reminders."] + lines + (matched.count > 30 ? ["(\(matched.count - 30) more not shown)"] : [])).joined(separator: "\n")
    }
}

struct LiveListRemindersTool: Tool {
    let name = "listReminders"
    let description = "Lists the user's open reminders and to-dos with due dates."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    @Generable
    struct Arguments {
        @Guide(description: "Optional words to look for in reminder titles or list names. Empty lists everything.") var search: String
    }

    func call(arguments a: Arguments) async throws -> String {
        let id = UUID()
        await reporter.toolStarted(id, title: String(localized: "Checking your reminders…"))
        let data = (try? JSONSerialization.data(withJSONObject: ["search": a.search])) ?? Data()
        let outcome = await gate.run(ToolCall(toolName: name, argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext())
        switch outcome {
        case .executed(let out):
            ctx.markUntrusted(); ctx.notePrivate(out)
            let lines = out.split(separator: "\n").map(String.init).filter { !$0.hasPrefix("(") && !$0.contains(" open reminders.") && !$0.hasPrefix("No open") }
            let title = lines.isEmpty ? String(localized: "Looked at reminders · none open") : String(localized: "Looked at reminders · \(lines.count) open")
            await reporter.toolFinished(id, title: title, details: lines, failed: false)
            return out
        case .blocked(let r):
            await reporter.toolFinished(id, title: String(localized: "Couldn't read your reminders"), details: [], failed: true)
            return "Not done: \(r)."
        case .failed(let m):
            await reporter.toolFinished(id, title: String(localized: "Couldn't read your reminders"), details: [], failed: true)
            return "Failed: \(m)"
        }
    }
}
