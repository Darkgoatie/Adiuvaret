import Foundation
import FoundationModels
import AdiuvaretCore
import PolicyEngine
import ToolKit

/// Keeps a note or task in the app's own list. The approval card is shown first; the finished card carries Undo.
struct SaveItemExecutor: ToolExecutor {
    let reporter: any ToolReporter

    func execute(_ call: ToolCall) async throws -> String {
        let a = CalendarStore.args(call)
        let kind = SavedItemRules.kind(from: (a["kind"] as? String) ?? "")
        let title = (a["title"] as? String) ?? ""
        let body = (a["text"] as? String) ?? ""
        switch SavedItemStore.shared.add(kind: kind, title: title, text: body, source: .assistant) {
        case .added(let item):
            let shown = kind == .task ? String(localized: "Kept the task \(item.title)") : String(localized: "Kept the note \(item.title)")
            await reporter.actionDone(title: shown, detail: String(localized: "In Notes and Tasks"), undo: .removeSavedItem(id: item.id))
            return "Kept the \(kind.rawValue) \(item.title) in Notes and Tasks."
        case .empty: return "Not done: there was no text to keep."
        case .full: return "Not done: Notes and Tasks is full (\(SavedItemRules.maxItems) items). Tell the user to delete some."
        }
    }
}

struct FindSavedItemsExecutor: ToolExecutor {
    func execute(_ call: ToolCall) async throws -> String {
        let a = CalendarStore.args(call)
        let kindWord = (a["kind"] as? String) ?? ""
        let kind: SavedItem.Kind? = kindWord.isEmpty ? nil : SavedItemRules.kind(from: kindWord)
        let hits = SavedItemRules.search(SavedItemStore.shared.all(), query: (a["query"] as? String) ?? "", kind: kind)
        return SavedItemRules.render(hits)
    }
}

struct LiveSaveItemTool: Tool {
    let name = "saveItem"
    let description = "Keeps a note or a task inside this app's own Notes and Tasks list, after the user approves. Not the Obsidian folder, not Reminders, not Todoist. Do not claim it was kept unless the result says so."
    let gate: PolicyGate; let ctx: TaskContext

    @Generable struct Arguments {
        @Guide(description: "Either note or task.")
        var kind: String
        @Guide(description: "A short title. May be empty; the first words of the text are used then.")
        var title: String
        @Guide(description: "The text to keep, in the user's own words.")
        var text: String
    }

    func call(arguments a: Arguments) async throws -> String {
        let data = (try? JSONSerialization.data(withJSONObject: ["kind": a.kind, "title": a.title, "text": a.text])) ?? Data()
        switch await gate.run(ToolCall(toolName: name, argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext()) {
        case .executed(let out): return out
        case .blocked(let r): return "Not done: \(r). Tell the user nothing was kept."
        case .failed(let m): return "Failed: \(m)"
        }
    }
}

struct LiveFindSavedItemsTool: Tool {
    let name = "findSavedItems"
    let description = "Searches the notes and tasks kept inside this app, or lists the newest. Read only. Only report what the result contains."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    @Generable struct Arguments {
        @Guide(description: "Words to look for. Empty lists the newest items.")
        var query: String
        @Guide(description: "note, task, or empty for both.")
        var kind: String
    }

    func call(arguments a: Arguments) async throws -> String {
        let id = UUID()
        await reporter.toolStarted(id, title: String(localized: "Looking through your saved items…"))
        let data = (try? JSONSerialization.data(withJSONObject: ["query": a.query, "kind": a.kind])) ?? Data()
        let outcome = await gate.run(ToolCall(id: id, toolName: name, argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext())
        switch outcome {
        case .executed(let out):
            ctx.markUntrusted(); ctx.notePrivate(out)
            let lines = out.split(separator: "\n").map(String.init).filter { $0.first?.isNumber == true }
            await reporter.toolFinished(id, title: lines.isEmpty ? String(localized: "Saved items · nothing found") : String(localized: "Saved items · \(lines.count) found"), details: Array(lines.prefix(8)), failed: false)
            return out
        case .blocked(let r):
            await reporter.toolFinished(id, title: String(localized: "Not allowed"), details: [], failed: true)
            return "Not done: \(r)."
        case .failed(let m):
            await reporter.toolFinished(id, title: String(localized: "Couldn't do that"), details: [], failed: true)
            return "Failed: \(m)"
        }
    }
}
