import Foundation

/// What `runShell` does with a command line before and after the runner: the check, the text rebuilt for ios_system, and the answer the model reads.
/// Pure text work, so the package tests cover it. The runner (App/Shell) only executes what this returns.
public enum ShellCommandBuilder {
    /// Characters ios_system never treats specially in an unquoted word. `~` (home), `=` (a variable set before the command), `^`, `$`,
    /// wildcards, quotes, backslash and the operators are all left out, so those words always go in single quotes and stay literal.
    private static let safe = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./:,+@%")

    /// One word, quoted so ios_system reads it back unchanged. ios_system expands `$` and `~` and wildcards in unquoted words only,
    /// so anything unusual goes in single quotes and the policy has already refused real expansions.
    static func quote(_ word: String) -> String {
        if !word.isEmpty, word != "-", word.allSatisfy({ safe.contains($0) }) { return word }
        if word.contains("'") { return "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        return "'" + word + "'"
    }

    /// The command line rebuilt from the checked tokens: one space between parts, every word quoted as needed, operators bare.
    /// The model's own spacing and quoting never reach ios_system, so a trick in how a line is written cannot change what runs.
    public static func rebuild(_ line: String) -> String? {
        let parsed = ShellPolicy.tokenize(line.trimmingCharacters(in: .whitespacesAndNewlines))
        guard parsed.refusal == nil, !parsed.tokens.isEmpty else { return nil }
        let tokens = parsed.tokens
        return tokens.map { token -> String in
            switch token {
            case .word(let w): return quote(w)
            case .op(let o): return o
            }
        }.joined(separator: " ")
    }

    /// The answer the model reads: the output, the exit status when it failed, and a note when the time ran out or the output was cut.
    public static func answer(output: String, status: Int32, timedOut: Bool, limit: Int = ShellPolicy.outputLimit) -> String {
        var text = ShellPolicy.capped(output.trimmingCharacters(in: .whitespacesAndNewlines), limit: limit)
        if timedOut { text += (text.isEmpty ? "" : "\n") + "[stopped after \(Int(ShellPolicy.timeLimit)) seconds]" }
        else if status != 0 { text += (text.isEmpty ? "" : "\n") + "[exit status \(status)]" }
        return text.isEmpty ? (status == 0 ? "Done. The command printed nothing." : "[exit status \(status)]") : text
    }

    /// The rows of the approval card: the exact command, what it can do, and the hosts it would contact.
    public static func cardRows(command: String, plan: ShellPlan) -> [(label: String, value: String)] {
        var rows: [(String, String)] = [("Command", String(command.prefix(400)))]
        rows.append(("What it does", ShellPolicy.note(for: plan.cls)))
        if !plan.hosts.isEmpty { rows.append(("Connects to", plan.hosts.joined(separator: ", "))) }
        let names = plan.commands.map(\.name)
        if names.count > 1 { rows.append(("Steps", names.joined(separator: ", then "))) }
        return rows
    }

    /// The title of the approval card.
    public static func cardTitle(for cls: ShellClass) -> String {
        switch cls {
        case .read: return "Run this command?"
        case .write: return "Run this command? It changes files."
        case .network: return "Run this command? It uses the internet."
        case .delete: return "Run this command? It deletes files."
        }
    }

    /// The workspace-relative paths in a listing that the runner passes to `ShellPolicy.broadRefusal`.
    public static func relativePaths(_ absolute: [String], workspace: String) -> [String] {
        let prefix = workspace.hasSuffix("/") ? workspace : workspace + "/"
        return absolute.compactMap { $0.hasPrefix(prefix) ? String($0.dropFirst(prefix.count)) : nil }
    }
}
