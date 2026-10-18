import Foundation
import AdiuvaretCore
import PolicyEngine
import ToolKit

/// Runs the command after the gate allowed it. The text was checked and rebuilt in `LiveRunShellTool` before the gate saw it.
struct RunShellExecutor: ToolExecutor {
    func execute(_ call: ToolCall) async throws -> String {
        let a = ManifestExecutor.strings(CalendarStore.args(call))
        let line = a["command"] ?? ""
        let plan = ShellPolicy.plan(line, workspace: ShellRunner.workspacePath)
        if let why = plan.refusal { return "Not done: \(why)." }
        if let why = ShellPolicy.broadRefusal(plan, workspacePaths: ShellRunner.listing()) { return "Not done: \(why)." }
        guard let rebuilt = ShellCommandBuilder.rebuild(line) else { return "Not done: the command could not be read." }
        let result = await ShellRunner.shared.run(rebuilt)
        return ShellCommandBuilder.answer(output: result.output, status: result.status, timedOut: result.timedOut)
    }
}

/// The model's single shell tool. Reading commands run without a card; anything that changes files, uses the internet or
/// deletes goes through the gate under a name that always asks, so a read-only name can never reach a write.
struct LiveRunShellTool: AppTool {
    let name = "runShell"
    let description = "Runs a command in the assistant's own Shell folder: ls, cat, head, tail, grep, sort, uniq, wc, cp, mv, mkdir, touch, rm, tar, gzip, sed, tr, diff, stat, du, find, date, echo and curl. Pipes (|), && and ; and redirects (> >> <) work. No variables, no $(), no wildcards that leave the folder, and no scripting languages. It cannot read keys or passwords. Output is cut at 64 KB and a command stops after 20 seconds. Use it to list, read, search, organise, archive or download files, never for anything outside the Shell folder."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    let params: [ToolParam] = [
        .string("command", "One command line, for example: grep -c error log.txt | sort. At most 2000 characters, at most 8 steps."),
    ]

    func run(_ args: ToolArgs) async -> String {
        let line = args.string("command")
        let plan = ShellPolicy.plan(line, workspace: ShellRunner.workspacePath)
        if let why = plan.refusal { return "Not done: \(why)." }
        if let why = ShellPolicy.broadRefusal(plan, workspacePaths: ShellRunner.listing()) { return "Not done: \(why)." }

        let toolName: String
        switch plan.cls {
        case .read: toolName = "runShell"
        case .write: toolName = "runShellWrite"
        case .network: toolName = "runShellNetwork"
        case .delete: toolName = "runShellDelete"
        }
        let rowID = UUID()
        let short = String(line.prefix(80))
        if plan.cls == .read { await reporter.toolStarted(rowID, title: String(localized: "Running a command…")) }
        let json: [String: Any] = ["command": line]
        let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
        switch await gate.run(ToolCall(id: rowID, toolName: toolName, argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext()) {
        case .executed(let out):
            ctx.markUntrusted(personal: false)
            let failed = out.hasPrefix("Not done")
            if plan.cls == .read {
                await reporter.toolFinished(rowID, title: failed ? String(localized: "The command did not run") : String(localized: "Ran a command"), details: [short], failed: failed)
            } else if !failed {
                await reporter.actionDone(title: String(localized: "Ran a command"), detail: short, undo: nil)
            }
            return out
        case .blocked(let r):
            if plan.cls == .read { await reporter.toolFinished(rowID, title: String(localized: "Not allowed"), details: [], failed: true) }
            return "Not done: \(r). Tell the user nothing was run."
        case .failed(let m):
            if plan.cls == .read { await reporter.toolFinished(rowID, title: String(localized: "Couldn't do that"), details: [], failed: true) }
            return "Failed: \(m)"
        }
    }
}
