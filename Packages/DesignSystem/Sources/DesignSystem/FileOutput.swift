import Foundation

/// A file the model wrote into its reply, shown as a card the user can save or share.
public struct GeneratedFile: Equatable, Sendable {
    public let name: String
    public let text: String
    public init(name: String, text: String) { self.name = name; self.text = text }
}

public enum FileOutput {
    /// Only plain-text formats. A reply can write these; it cannot write a PDF, a picture or an app.
    public static let allowed: Set<String> = [
        "txt", "md", "csv", "tsv", "json", "xml", "html", "yaml", "yml", "log", "ics", "toml",
        "swift", "py", "js", "ts", "css", "sql", "sh", "java", "kt", "c", "h", "cpp", "go", "rs", "rb", "php",
    ]
    public static let maxBytes = 200_000

    /// The file name from a fence line such as `file:report.md` or `file report.md`. Nil when the fence is not a file fence.
    public static func name(fromFenceInfo info: String) -> String? {
        let t = info.trimmingCharacters(in: .whitespaces)
        guard t.lowercased().hasPrefix("file") else { return nil }
        var rest = String(t.dropFirst(4))
        guard rest.isEmpty || rest.first == ":" || rest.first == " " || rest.first == "=" else { return nil }
        rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: ": =\t"))
        if rest.lowercased().hasPrefix("name=") { rest = String(rest.dropFirst(5)) }
        rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        return rest.isEmpty ? nil : safeName(rest)
    }

    /// A name that stays inside the app's temporary folder and ends in a known text extension.
    public static func safeName(_ raw: String) -> String {
        var last = raw
        if let i = last.lastIndex(where: { $0 == "/" || $0 == "\\" }) { last = String(last[last.index(after: i)...]) }
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_ "))
        let cleaned = String(last.unicodeScalars.filter { allowedChars.contains($0) }.map(Character.init))
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        var base = cleaned, ext = ""
        if let dot = cleaned.lastIndex(of: "."), dot != cleaned.startIndex {
            base = String(cleaned[..<dot]); ext = String(cleaned[cleaned.index(after: dot)...]).lowercased()
        }
        if base.isEmpty { base = "reply" }
        if !allowed.contains(ext) { ext = "txt" }
        return String(base.prefix(50)) + "." + ext
    }

    public static func sizeText(_ file: GeneratedFile) -> String {
        let n = file.text.utf8.count
        if n < 1024 { return "\(n) B" }
        return String(format: "%.1f KB", Double(n) / 1024)
    }

    public static func symbol(for name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "csv", "tsv": "tablecells"
        case "json", "xml", "yaml", "yml", "toml": "curlybraces"
        case "md", "txt", "log": "doc.text"
        case "html", "css": "globe"
        case "ics": "calendar"
        default: "chevron.left.forwardslash.chevron.right"
        }
    }

    /// Writes the file to a temporary folder so it can be shared under its own name. Returns nil when it is too large or cannot be written.
    public static func write(_ file: GeneratedFile) -> URL? {
        guard file.text.utf8.count <= maxBytes else { return nil }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("GeneratedFiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(safeName(file.name))
        do { try file.text.write(to: url, atomically: true, encoding: .utf8); return url } catch { return nil }
    }
}
