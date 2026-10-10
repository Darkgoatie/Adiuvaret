import Foundation
import FoundationModels
import AdiuvaretCore
import PolicyEngine
import ToolKit

/// Runs a read-only connector step: shows a progress row, calls the gate, and fills the row from the result.
private func readStep(_ gate: PolicyGate, _ ctx: TaskContext, _ reporter: any ToolReporter, name: String, json: [String: Any],
                      running: String, summary: (String) -> (title: String, details: [String])) async -> String {
    let id = UUID()
    await reporter.toolStarted(id, title: running)
    let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
    let outcome = await gate.run(ToolCall(id: id, toolName: name, argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext())
    switch outcome {
    case .executed(let out):
        ctx.markUntrusted(); ctx.notePrivate(out)
        let failed = out.hasPrefix("Not done") || out.hasPrefix("Contacts access denied")
        let s = failed ? (title: String(localized: "Couldn't do that"), details: [String]()) : summary(out)
        await reporter.toolFinished(id, title: s.title, details: s.details, failed: failed)
        return out
    case .blocked(let r):
        await reporter.toolFinished(id, title: String(localized: "Not allowed"), details: [], failed: true)
        return "Not done: \(r)."
    case .failed(let m):
        await reporter.toolFinished(id, title: String(localized: "Couldn't do that"), details: [], failed: true)
        return "Failed: \(m)"
    }
}

/// Runs a write step. The approval card and the finished-action card are the user's feedback, so no progress row.
private func writeStep(_ gate: PolicyGate, _ ctx: TaskContext, name: String, json: [String: Any]) async -> String {
    let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
    switch await gate.run(ToolCall(toolName: name, argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext()) {
    case .executed(let out): return out
    case .blocked(let r): return "Not done: \(r). Tell the user nothing was done."
    case .failed(let m): return "Failed: \(m)"
    }
}

private func numbered(_ out: String) -> [String] {
    out.split(separator: "\n").map(String.init).filter { $0.first?.isNumber == true && $0.contains(". ") }
}

struct LiveSearchNotesTool: Tool {
    let name = "searchNotes"
    let description = "Searches the user's notes folder (Obsidian or Markdown) by words. Returns note paths with short excerpts. Never invent notes."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    @Generable struct Arguments {
        @Guide(description: "Two to six words to look for in note titles and text, for example: Seville trip")
        var query: String
    }

    func call(arguments a: Arguments) async throws -> String {
        await readStep(gate, ctx, reporter, name: name, json: ["query": a.query], running: String(localized: "Searching your notes…")) { out in
            let items = numbered(out)
            return (items.isEmpty ? String(localized: "Searched your notes · nothing found") : String(localized: "Searched your notes · \(items.count) found"), items)
        }
    }
}

struct LiveReadNoteTool: Tool {
    let name = "readNote"
    let description = "Reads one note from the user's notes folder. Use a path returned by searchNotes. Long notes come in parts."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    @Generable struct Arguments {
        @Guide(description: "The note path exactly as searchNotes returned it, for example Trips/Spain.md")
        var path: String
        @Guide(description: "Which part to read, starting at 1.")
        var part: Int
    }

    func call(arguments a: Arguments) async throws -> String {
        await readStep(gate, ctx, reporter, name: name, json: ["path": a.path, "part": a.part], running: String(localized: "Reading a note…")) { _ in
            (String(localized: "Read \(NoteName.title(of: a.path))"), [])
        }
    }
}

struct LiveWriteNoteTool: Tool {
    let name = "writeNote"
    let description = "Creates a new note in the user's notes folder, or adds text to the end of an existing one. The user approves first. Do not claim it was saved unless the result says so."
    let gate: PolicyGate; let ctx: TaskContext

    @Generable struct Arguments {
        @Guide(description: "Title for a new note. Leave empty when adding to an existing note.")
        var title: String
        @Guide(description: "The text to write, in the user's own words.")
        var text: String
        @Guide(description: "Path of an existing note to add to, from searchNotes. Empty to create a new note.")
        var appendTo: String
    }

    func call(arguments a: Arguments) async throws -> String {
        await writeStep(gate, ctx, name: name, json: ["title": a.title, "text": a.text, "appendTo": a.appendTo])
    }
}

struct LiveFindContactTool: Tool {
    let name = "findContact"
    let description = "Looks up a person in the user's contacts. Returns phone numbers, emails and birthday. Read only."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    @Generable struct Arguments {
        @Guide(description: "The person's name or part of it, for example Ana Ruiz")
        var name: String
    }

    func call(arguments a: Arguments) async throws -> String {
        await readStep(gate, ctx, reporter, name: name, json: ["name": a.name], running: String(localized: "Looking in your contacts…")) { out in
            let items = numbered(out)
            return (items.isEmpty ? String(localized: "Looked in contacts · no match") : String(localized: "Looked in contacts · \(items.count) found"), items.map { String($0.prefix(60)) })
        }
    }
}

struct LiveRunShortcutTool: Tool {
    let name = "runShortcut"
    let description = "Runs a shortcut from the Shortcuts app by its exact name. The user approves first. The result cannot be read back."
    let gate: PolicyGate; let ctx: TaskContext

    @Generable struct Arguments {
        @Guide(description: "The shortcut's name exactly as the user said it, for example Morning routine")
        var name: String
    }

    func call(arguments a: Arguments) async throws -> String { await writeStep(gate, ctx, name: name, json: ["name": a.name]) }
}

struct LiveDraftEmailTool: Tool {
    let name = "draftEmail"
    let description = "Opens a draft in the Mail app with the recipient, subject and text filled in. The user approves, then reads it and presses send. Nothing is sent by you."
    let gate: PolicyGate; let ctx: TaskContext

    @Generable struct Arguments {
        @Guide(description: "Recipient email address. Leave empty when the user gave none. Never guess an address.")
        var to: String
        var subject: String
        @Guide(description: "The email text, written in the user's voice.")
        var body: String
    }

    func call(arguments a: Arguments) async throws -> String {
        await writeStep(gate, ctx, name: name, json: ["to": a.to, "subject": a.subject, "body": a.body])
    }
}
