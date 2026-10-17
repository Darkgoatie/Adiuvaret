import Foundation

/// What a shell command line can do, lowest to highest. Anything above `read` needs the user's approval when the assistant runs it.
public enum ShellClass: Int, Comparable, Sendable {
    case read = 0, write, network, delete
    public static func < (a: ShellClass, b: ShellClass) -> Bool { a.rawValue < b.rawValue }
    public var needsCard: Bool { self != .read }
}

/// Who typed the command. The user's own typing in the Shell screen needs no card and may use a few more programs;
/// the assistant gets the stricter table.
public enum ShellAudience: Sendable { case assistant, user }

public struct ShellCommand: Equatable, Sendable {
    public let name: String
    public let args: [String]
    public let cls: ShellClass
}

public struct ShellPlan: Equatable, Sendable {
    public let commands: [ShellCommand]
    public let cls: ShellClass
    /// Hosts the line would contact, for the approval card.
    public let hosts: [String]
    /// Set when the line must not run. The text says why, in a sentence the assistant can pass on.
    public let refusal: String?
    public var allowed: Bool { refusal == nil }
}

/// Parses one command line into commands, classifies each, and keeps every path inside the workspace.
/// Pure text work: it never touches the file system. The runner adds the real-path check for symlinks.
public enum ShellPolicy {
    public static let maxLine = 2000
    public static let maxCommands = 8

    private struct Spec {
        var cls: ShellClass
        var free = false
        var patternFirst = false
        /// Options whose value is the search pattern itself (grep -e), so the next word is already a file.
        var patternOpts: Set<String> = []
        /// Options whose value is a file that is read (grep -f), so it is path-checked like any other argument.
        var fileOpts: Set<String> = []
        /// Options whose value is a number or other plain text.
        var valueOpts: Set<String> = []
    }

    private static let table: [String: Spec] = {
        var t: [String: Spec] = [:]
        // Only commands the bundled ios_system frameworks provide (its commandDictionary.plist), so a refusal is never a "not found" at run time.
        for n in ["ls", "cat", "head", "tail", "wc", "sort", "uniq", "diff", "stat", "du", "pwd", "readlink"] { t[n] = Spec(cls: .read) }
        for n in ["echo", "tr", "date"] { t[n] = Spec(cls: .read, free: true) }
        for n in ["grep", "egrep", "fgrep"] { t[n] = Spec(cls: .read, patternFirst: true, patternOpts: ["-e"], fileOpts: ["-f"], valueOpts: ["-m", "-A", "-B", "-C"]) }
        t["find"] = Spec(cls: .read)
        for n in ["mkdir", "touch", "cp", "mv", "tee", "chmod", "gzip", "gunzip"] { t[n] = Spec(cls: .write) }
        t["tar"] = Spec(cls: .read)
        t["sed"] = Spec(cls: .read, patternFirst: true)
        for n in ["curl", "scp", "sftp", "ssh"] { t[n] = Spec(cls: .network) }
        for n in ["rm", "rmdir"] { t[n] = Spec(cls: .delete) }
        return t
    }()

    private static let userOnly: Set<String> = ["awk"]
    private static let interactive: Set<String> = ["vi", "vim", "nano", "emacs", "less", "more", "top", "htop", "man", "ed"]
    private static let launchers: Set<String> = ["sh", "bash", "zsh", "dash", "ksh", "csh", "fish", "eval", "exec", "source", ".", "xargs", "sudo", "su",
                                                  "env", "nohup", "command", "builtin", "time", "timeout", "nice", "watch", "script"]
    private static let scripting: Set<String> = ["awk", "perl", "python", "python3", "node", "ruby", "lua", "tclsh", "php"]
    private static let navigation: Set<String> = ["cd", "pushd", "popd", "chdir"]

    /// ssh, scp and sftp are checked option by option: a known list of flags, `-o` only for a few harmless names, and `-i` or `-F`
    /// files must be inside the workspace. Anything else (ProxyCommand, LocalCommand, tunnels, jump hosts) is refused.
    private static let remoteFlags: [String: (plain: Set<Character>, valued: Set<Character>)] = [
        "ssh": (Set("46CqvTnNtxa"), Set("ilpcmFEo")),
        "scp": (Set("46BCpqrTv3"), Set("cFilioP")),
        "sftp": (Set("46aCpqrv"), Set("cFiloP")),
    ]
    private static let remoteOptionNames: Set<String> = ["stricthostkeychecking", "batchmode", "connecttimeout", "serveraliveinterval",
                                                         "serveralivecountmax", "port", "user", "userknownhostsfile", "identityfile",
                                                         "compression", "addressfamily"]
    private static let remotePathOptions: Set<String> = ["userknownhostsfile", "identityfile"]

    private static func remoteValueProblem(_ letter: Character, _ value: String, workspace: String) -> String? {
        if "iFE".contains(letter) {
            if value.hasPrefix("-") { return "a file name is needed after -\(letter)" }
            if globOutside(value) != nil { return "\(value) could reach the folder above the workspace; name the files instead" }
            if let bad = outsidePath(value, workspace: workspace) { return "\(bad) is outside the workspace" }
            return nil
        }
        if letter == "o" {
            let v = value.trimmingCharacters(in: .whitespaces)
            let cut = v.firstIndex(where: { $0 == "=" || $0 == " " }) ?? v.endIndex
            let name = String(v[..<cut]).lowercased()
            let rest = cut < v.endIndex ? String(v[v.index(after: cut)...]).trimmingCharacters(in: .whitespaces) : ""
            if !remoteOptionNames.contains(name) { return "the ssh option \(name) is not available" }
            if remotePathOptions.contains(name) {
                if globOutside(rest) != nil { return "\(rest) could reach the folder above the workspace; name the files instead" }
                if let bad = outsidePath(rest, workspace: workspace) { return "\(bad) is outside the workspace" }
            }
        }
        return nil
    }

    /// Returns a refusal, or the hosts the command would contact.
    private static func remotePlan(_ name: String, _ args: [String], workspace: String) -> (refusal: String?, hosts: [String]) {
        guard let flags = remoteFlags[name] else { return (nil, []) }
        var operands: [String] = []
        var i = 0
        while i < args.count {
            let a = args[i]
            if a == "--" {
                if name == "ssh" { return ("-- is not available for ssh", []) }
                operands += args[(i + 1)...]; break
            }
            if !a.hasPrefix("-") || a.count <= 1 || (name == "ssh" && !operands.isEmpty) { operands.append(a); i += 1; continue }
            let letters = Array(a.dropFirst())
            var j = 0
            while j < letters.count {
                let l = letters[j]
                if flags.plain.contains(l) { j += 1; continue }
                guard flags.valued.contains(l) else { return ("the option -\(l) is not available for \(name)", []) }
                let value: String
                if j + 1 < letters.count { value = String(letters[(j + 1)...]) }
                else if i + 1 < args.count { i += 1; value = args[i] }
                else { return ("the option -\(l) needs a value", []) }
                if let why = remoteValueProblem(l, value, workspace: workspace) { return (why, []) }
                break
            }
            i += 1
        }
        var hosts: [String] = []
        if name == "ssh" {
            guard let first = operands.first else { return ("name a host to connect to", []) }
            if operands.count > 1, operands[1].hasPrefix("-") { return ("options go before the host name", []) }
            if let h = hostName(first) { hosts.append(h) }
            return (nil, hosts)
        }
        guard !operands.isEmpty else { return ("name a file or host", []) }
        if name == "sftp" { return (nil, hostName(operands[0]).map { [$0] } ?? []) }
        for a in operands {
            if a.contains("://") { if let h = hostName(a) { hosts.append(h) } }
            else if isRemoteSpec(a) { if let h = hostName(String(a[..<a.firstIndex(of: ":")!])) { hosts.append(h) } }
            else {
                if globOutside(a) != nil { return ("\(a) could reach the folder above the workspace; name the files instead", []) }
                if let bad = outsidePath(a, workspace: workspace) { return ("\(bad) is outside the workspace", []) }
            }
        }
        return (nil, hosts)
    }

    private static func hostName(_ s: String) -> String? {
        var t = s
        if let r = t.range(of: "://") { t = String(t[r.upperBound...]) }
        if let at = t.lastIndex(of: "@") { t = String(t[t.index(after: at)...]) }
        let h = t.prefix(while: { $0 != "/" && $0 != ":" && $0 != "?" && $0 != "#" })
        return h.isEmpty ? nil : String(h).lowercased()
    }

    // MARK: Tokens

    enum Token: Equatable { case word(String), op(String) }

    static func tokenize(_ line: String) -> (tokens: [Token], refusal: String?) {
        var tokens: [Token] = []
        var cur = ""
        var inWord = false
        let chars = Array(line)
        var i = 0
        let subst = "variables and command substitution are not available; write the value out"
        func flush() { if inWord { tokens.append(.word(cur)); cur = ""; inWord = false } }
        func peek(_ k: Int) -> Character? { i + k < chars.count ? chars[i + k] : nil }
        while i < chars.count {
            let c = chars[i]
            if c == "'" {
                inWord = true; i += 1
                var closed = false
                while i < chars.count {
                    if chars[i] == "'" { closed = true; i += 1; break }
                    cur.append(chars[i]); i += 1
                }
                if !closed { return ([], "a quote is not closed") }
                continue
            }
            if c == "\"" {
                inWord = true; i += 1
                var closed = false
                while i < chars.count {
                    let d = chars[i]
                    if d == "\"" { closed = true; i += 1; break }
                    if d == "$" || d == "`" { return ([], subst) }
                    if d == "\\", let n = peek(1), n == "\"" || n == "\\" { cur.append(n); i += 2; continue }
                    cur.append(d); i += 1
                }
                if !closed { return ([], "a quote is not closed") }
                continue
            }
            if c == "\\" {
                guard let n = peek(1) else { return ([], "the line ends with a backslash") }
                inWord = true; cur.append(n); i += 2; continue
            }
            if c == "$" || c == "`" { return ([], subst) }
            if c == "\n" || c == "\r" { return ([], "send one command line at a time") }
            if c == " " || c == "\t" { flush(); i += 1; continue }
            if c == "(" || c == ")" { return ([], "subshells are not available") }
            if c == "|" {
                if peek(1) == "&" { return ([], "|& is not available; use 2>&1 and a pipe") }
                flush()
                if peek(1) == "|" { tokens.append(.op("||")); i += 2 } else { tokens.append(.op("|")); i += 1 }
                continue
            }
            if c == "&" {
                if peek(1) == "&" { flush(); tokens.append(.op("&&")); i += 2; continue }
                return ([], "background jobs and & redirects are not available")
            }
            if c == ";" { flush(); tokens.append(.op(";")); i += 1; continue }
            if c == "<" {
                if peek(1) == "<" { return ([], "here-documents are not available") }
                flush(); tokens.append(.op("<")); i += 1; continue
            }
            if c == ">" {
                if inWord && cur == "2" {
                    cur = ""; inWord = false
                    if peek(1) == "&" && peek(2) == "1" { tokens.append(.op("2>&1")); i += 3; continue }
                    if peek(1) == ">" { tokens.append(.op("2>>")); i += 2; continue }
                    tokens.append(.op("2>")); i += 1; continue
                }
                if peek(1) == "&" { return ([], "background jobs and & redirects are not available") }
                flush()
                if peek(1) == ">" { tokens.append(.op(">>")); i += 2 } else { tokens.append(.op(">")); i += 1 }
                continue
            }
            inWord = true; cur.append(c); i += 1
        }
        flush()
        return (tokens, nil)
    }

    // MARK: Paths

    /// Resolves `path` against the workspace without touching the disk. `~` is the workspace.
    public static func resolve(_ path: String, workspace: String) -> String? {
        var p = path
        if p == "~" { p = workspace } else if p.hasPrefix("~/") { p = workspace + "/" + p.dropFirst(2) } else if p.hasPrefix("~") { return nil }
        let full = p.hasPrefix("/") ? p : workspace + "/" + p
        var parts: [Substring] = []
        for comp in full.split(separator: "/", omittingEmptySubsequences: true) {
            if comp == "." { continue }
            if comp == ".." { if !parts.isEmpty { parts.removeLast() }; continue }
            parts.append(comp)
        }
        return "/" + parts.joined(separator: "/")
    }

    public static func isInside(_ path: String, workspace: String) -> Bool {
        guard let ws = resolve(workspace, workspace: "/"), let r = resolve(path, workspace: ws) else { return false }
        return r == ws || r.hasPrefix(ws + "/")
    }

    private static func looksLikePath(_ w: String) -> Bool {
        w.hasPrefix("/") || w.hasPrefix("~") || w.split(separator: "/").contains("..")
    }

    /// The first argument that points outside the workspace, or nil.
    private static func outsidePath(_ w: String, workspace: String) -> String? {
        if w.hasPrefix("--") {
            guard let eq = w.firstIndex(of: "=") else { return nil }
            let v = String(w[w.index(after: eq)...])
            return looksLikePath(v) && !isInside(v, workspace: workspace) ? v : nil
        }
        if w.hasPrefix("-") {
            if w.count > 2 {
                let rest = String(w.dropFirst(2))
                if rest.hasPrefix("/") || rest.hasPrefix("~") || rest.hasPrefix("..") { return isInside(rest, workspace: workspace) ? nil : rest }
            }
            return nil
        }
        return looksLikePath(w) && !isInside(w, workspace: workspace) ? w : nil
    }

    /// `-rf` style clusters: the last letter takes the next word as a file, which is path-checked like any argument.
    private static func endsWithFileOption(_ a: String, _ spec: Spec) -> Bool {
        guard a.hasPrefix("-"), !a.hasPrefix("--"), a.count > 2, let last = a.last else { return false }
        return spec.fileOpts.contains("-" + String(last))
    }

    /// A word whose path part starts with a dot and holds a glob character, such as `.*`, can expand to `..`.
    private static func globOutside(_ w: String) -> String? {
        if w.hasPrefix("-") && !w.contains("=") { return nil }
        let value = w.contains("=") && w.hasPrefix("--") ? String(w[w.index(after: w.firstIndex(of: "=")!)...]) : w
        for comp in value.split(separator: "/") where comp.hasPrefix(".") && comp.contains(where: { "*?[".contains($0) }) { return w }
        return nil
    }

    // MARK: Plan

    public static func plan(_ line: String, workspace: String, audience: ShellAudience = .assistant) -> ShellPlan {
        func refuse(_ why: String) -> ShellPlan { ShellPlan(commands: [], cls: .read, hosts: [], refusal: why) }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return refuse("the command is empty") }
        if trimmed.count > maxLine { return refuse("the command is longer than \(maxLine) characters") }
        let (tokens, tokenError) = tokenize(trimmed)
        if let e = tokenError { return refuse(e) }

        // Split into segments at ; && || |, pulling redirects out of each.
        struct Segment { var words: [String] = []; var redirects: [(op: String, target: String)] = [] }
        var segments: [Segment] = []
        var cur = Segment()
        var i = 0
        while i < tokens.count {
            switch tokens[i] {
            case .word(let w):
                cur.words.append(w)
            case .op(let o):
                if o == "|" || o == "||" || o == "&&" || o == ";" {
                    if cur.words.isEmpty { return refuse("a command is missing next to \(o)") }
                    segments.append(cur); cur = Segment()
                } else if o == "2>&1" {
                    break
                } else {
                    guard i + 1 < tokens.count, case .word(let target) = tokens[i + 1] else { return refuse("a file name is missing after \(o)") }
                    cur.redirects.append((o, target)); i += 1
                }
            }
            i += 1
        }
        if case .op(let last)? = tokens.last, last == "|" || last == "&&" || last == "||" { return refuse("the line ends with \(last) and needs another command") }
        if !cur.words.isEmpty { segments.append(cur) } else if !cur.redirects.isEmpty { return refuse("a command is missing before the redirect") }
        if segments.isEmpty { return refuse("the command is empty") }
        if segments.count > maxCommands { return refuse("more than \(maxCommands) commands in one line") }

        var commands: [ShellCommand] = []
        var hosts: [String] = []
        var highest = ShellClass.read
        for seg in segments {
            let name = seg.words[0]
            let args = Array(seg.words.dropFirst())
            if name.contains("/") { return refuse("run programs by name, for example ls, not by path") }
            if navigation.contains(name) { return refuse("every command starts in the workspace and cd does not carry over; use paths such as notes/a.txt") }
            if interactive.contains(name) { return refuse("\(name) is interactive and not available") }
            if launchers.contains(name) { return refuse("\(name) would start other programs and is not available") }
            var spec = table[name]
            if spec == nil, audience == .user, userOnly.contains(name) { spec = Spec(cls: .write, free: false) }
            if spec == nil {
                if scripting.contains(name) { return refuse("\(name) is not available to the assistant; use sed, grep and sort, or runScript for calculations") }
                return refuse("\(name) is not available in this shell")
            }
            if let why = unsafeOptions(name, args) { return refuse(why) }

            var cls = spec!.cls
            cls = max(cls, refine(name, args))
            if remoteFlags[name] != nil {
                let remote = remotePlan(name, args, workspace: workspace)
                if let why = remote.refusal { return refuse(why) }
                hosts += remote.hosts
            } else if !spec!.free {
                var sawPattern = !spec!.patternFirst
                var skipNext = false
                for a in args {
                    if skipNext { skipNext = false; continue }
                    if spec!.fileOpts.contains(a) || Self.endsWithFileOption(a, spec!) { sawPattern = true; continue }
                    if spec!.patternOpts.contains(a) { sawPattern = true; skipNext = true; continue }
                    if spec!.valueOpts.contains(a) { skipNext = true; continue }
                    if !sawPattern, !a.hasPrefix("-") { sawPattern = true; continue }
                    if let bad = globOutside(a) { return refuse("\(bad) could reach the folder above the workspace; name the files instead") }
                    if name == "curl", let bad = curlOutside(a, workspace: workspace) { return refuse("\(bad) is outside the workspace") }
                    if a.contains("://") { continue }
                    if let bad = outsidePath(a, workspace: workspace) { return refuse("\(bad) is outside the workspace") }
                }
            }
            for r in seg.redirects {
                if r.target.hasPrefix("-") { return refuse("a redirect needs a file name") }
                if r.target == "/dev/null" { continue }
                if let bad = globOutside(r.target) { return refuse("\(bad) could reach the folder above the workspace; name the files instead") }
                if let bad = outsidePath(r.target, workspace: workspace) { return refuse("\(bad) is outside the workspace") }
                if r.op != "<" { cls = max(cls, .write) }
            }
            if name == "curl" { hosts += args.filter { $0.contains("://") }.compactMap(hostName) }
            if name == "curl" {
                for a in args where a.contains("://") && !(a.lowercased().hasPrefix("http://") || a.lowercased().hasPrefix("https://")) {
                    return refuse("only http and https addresses are allowed")
                }
            }
            highest = max(highest, cls)
            commands.append(ShellCommand(name: name, args: args, cls: cls))
        }
        var seen = Set<String>()
        let uniqueHosts = hosts.filter { seen.insert($0).inserted }
        return ShellPlan(commands: commands, cls: highest, hosts: uniqueHosts, refusal: nil)
    }

    // MARK: Per-command rules

    private static func unsafeOptions(_ name: String, _ args: [String]) -> String? {
        switch name {
        case "find":
            for a in args where ["-exec", "-execdir", "-ok", "-okdir", "-fprint", "-fprint0", "-fprintf", "-fls"].contains(a) {
                return "find \(a) is not available; use find with -name and read the result"
            }
        case "date":
            if args.contains(where: { $0 == "-s" || $0 == "--set" || $0.hasPrefix("--set=") }) { return "the clock cannot be set" }
        case "curl":
            for a in args where a == "-K" || a == "--config" || a.hasPrefix("--config=") { return "curl config files are not available" }
        case "tar":
            if args.contains(where: { $0 == "-P" || $0 == "--absolute-names" }) { return "tar -P is not available" }
        case "sed":
            return sedProblem(args)
        default: break
        }
        return nil
    }

    /// The assistant may run one substitution or print/delete command per sed call, so a script cannot write files or run programs.
    private static func sedProblem(_ args: [String]) -> String? {
        var script: String?
        for a in args {
            if a == "-n" || a == "-E" || a == "-r" || a == "-i" || a.hasPrefix("-i") && a.count > 2 && !a.hasPrefix("-i/") && !a.contains("=") { continue }
            if a.hasPrefix("-") { return "sed option \(a) is not available; use -n, -E or -i with one script" }
            if a.isEmpty { continue }
            script = a; break
        }
        guard let s = script else { return nil }
        let chars = Array(s)
        var i = 0
        while i < chars.count, chars[i].isNumber || chars[i] == "," || chars[i] == "$" { i += 1 }
        guard i < chars.count else { return "that sed script is not available" }
        if chars[i] == "p" || chars[i] == "d" { return i + 1 == chars.count ? nil : "that sed script is not available" }
        guard chars[i] == "s", i + 1 < chars.count else { return "that sed script is not available" }
        let delim = chars[i + 1]
        if delim.isLetter || delim.isNumber || delim == "\\" || delim == " " { return "that sed script is not available" }
        var parts = 0
        var j = i + 2
        while j < chars.count {
            if chars[j] == "\\", j + 1 < chars.count { j += 2; continue }
            if chars[j] == delim { parts += 1; if parts == 2 { j += 1; break } }
            j += 1
        }
        guard parts == 2 else { return "that sed script is not available" }
        let flags = String(chars[j...])
        if flags.contains(where: { !"gpI0123456789".contains($0) }) { return "that sed script is not available" }
        return nil
    }

    private static func refine(_ name: String, _ args: [String]) -> ShellClass {
        let nonOptions = args.filter { !$0.hasPrefix("-") && !$0.isEmpty }
        switch name {
        case "find":
            return args.contains("-delete") ? .delete : .read
        case "sort":
            return args.contains(where: { $0 == "-o" || $0.hasPrefix("-o") && $0.count > 2 && !$0.hasPrefix("--") }) ? .write : .read
        case "uniq":
            return nonOptions.count >= 2 ? .write : .read
        case "tar":
            guard let first = args.first else { return .read }
            let ops = first.hasPrefix("--") ? "" : first.replacingOccurrences(of: "-", with: "")
            if args.contains(where: { ["--create", "--extract", "--append", "--update"].contains($0) }) { return .write }
            return ops.contains(where: { "cxru".contains($0) }) ? .write : .read
        case "sed":
            return args.contains(where: { $0.hasPrefix("-i") }) ? .write : .read
        default:
            return .read
        }
    }

    private static func isRemoteSpec(_ a: String) -> Bool {
        guard let colon = a.firstIndex(of: ":") else { return false }
        if let slash = a.firstIndex(of: "/"), slash < colon { return false }
        return !a.hasPrefix("-")
    }

    private static func curlOutside(_ a: String, workspace: String) -> String? {
        if a.contains("://") { return nil }
        guard let at = a.firstIndex(of: "@") else { return nil }
        let p = String(a[a.index(after: at)...])
        return looksLikePath(p) && !isInside(p, workspace: workspace) ? p : nil
    }

    // MARK: Cards and output

    /// A plain-language line for the approval card.
    public static func note(for cls: ShellClass) -> String {
        switch cls {
        case .read: return "Reads files in the shell workspace."
        case .write: return "Creates or changes files in the shell workspace."
        case .network: return "Connects to the internet and may save files in the shell workspace."
        case .delete: return "Deletes files in the shell workspace. This cannot be undone."
        }
    }

    public static let outputLimit = 64 * 1024
    public static let timeLimit: TimeInterval = 20

    /// Cuts output at `limit` bytes on a character boundary and says so.
    public static func capped(_ text: String, limit: Int = outputLimit) -> String {
        let bytes = Array(text.utf8)
        guard bytes.count > limit else { return text }
        var end = limit
        while end > 0, bytes[end] & 0xC0 == 0x80 { end -= 1 }
        return String(decoding: bytes[..<end], as: UTF8.self) + "\n[output cut after \(limit / 1024) KB]"
    }
}
