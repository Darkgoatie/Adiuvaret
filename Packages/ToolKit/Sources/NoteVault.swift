import Foundation

/// Safe names and paths for notes in the user's folder. The model never picks a raw path.
public enum NoteName {
    public static let maxTitle = 80

    /// A file name for a new note, or nil when the title holds nothing usable.
    public static func fileName(for title: String) -> String? {
        var t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasSuffix(".md") { t = String(t.dropLast(3)) }
        let bad = CharacterSet(charactersIn: "/\\:*?\"<>|#^[]").union(.controlCharacters)
        t = String(String.UnicodeScalarView(t.unicodeScalars.map { bad.contains($0) ? " " : $0 }))
        t = t.split(separator: " ").joined(separator: " ")
        while let first = t.first, first == "." || first == " " { t.removeFirst() }
        t = String(t.prefix(maxTitle)).trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t + ".md"
    }

    /// A path inside the notes folder that a search returned: no climbing out, no hidden folders, Markdown only.
    public static func isSafeRelative(_ path: String) -> Bool {
        guard !path.isEmpty, path.count <= 300, !path.hasPrefix("/"), !path.contains("\\") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.contains(where: { $0.isEmpty || $0.hasPrefix(".") }) else { return false }
        return ["md", "markdown"].contains((path as NSString).pathExtension.lowercased())
    }

    public static func title(of path: String) -> String {
        ((path as NSString).lastPathComponent as NSString).deletingPathExtension
    }
}

public struct NoteHit: Sendable, Equatable {
    public let path: String
    public let snippet: String
    public let score: Int
}

/// Keyword search over note text. Pure logic: the app reads the files and passes the text in.
public enum NoteSearch {
    private static let stop: Set<String> = [
        "the", "and", "for", "with", "about", "what", "when", "where", "which", "that", "this", "from", "into", "note", "notes",
        "obsidian", "vault", "find", "search", "look", "show", "did", "write", "wrote", "written", "have", "has", "are", "was", "were",
        "can", "you", "please", "any", "all", "folder", "markdown"]

    public static func terms(_ query: String) -> [String] {
        let all = query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 2 }
        var seen = Set<String>()
        let kept = all.filter { !stop.contains($0) && seen.insert($0).inserted }
        if !kept.isEmpty { return Array(kept.prefix(8)) }
        var again = Set<String>()
        return Array(all.filter { again.insert($0).inserted }.prefix(8))
    }

    public static func rank(_ notes: [(path: String, text: String)], query: String, limit: Int = 5) -> [NoteHit] {
        let wanted = terms(query)
        guard !wanted.isEmpty else { return [] }
        var hits: [NoteHit] = []
        for n in notes {
            let title = NoteName.title(of: n.path).lowercased()
            let body = n.text.lowercased()
            var score = 0
            var matched = 0
            for term in wanted {
                let inTitle = title.contains(term)
                let count = min(body.components(separatedBy: term).count - 1, 5)
                if inTitle || count > 0 { matched += 1 }
                score += (inTitle ? 5 : 0) + count
            }
            guard matched > 0 else { continue }
            if matched == wanted.count { score += 10 }
            hits.append(NoteHit(path: n.path, snippet: snippet(n.text, terms: wanted), score: score))
        }
        let ordered = hits.sorted { $0.score != $1.score ? $0.score > $1.score : $0.path < $1.path }
        return Array(ordered.prefix(max(1, limit)))
    }

    /// About 160 characters around the first place a search word appears.
    static func snippet(_ text: String, terms: [String], width: Int = 160) -> String {
        let flat = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        var first: Int?
        for term in terms {
            if let r = flat.range(of: term, options: .caseInsensitive) {
                let d = flat.distance(from: flat.startIndex, to: r.lowerBound)
                first = min(first ?? d, d)
            }
        }
        let offset = max(0, (first ?? 0) - 50)
        let start = flat.index(flat.startIndex, offsetBy: offset)
        let end = flat.index(start, offsetBy: width, limitedBy: flat.endIndex) ?? flat.endIndex
        return (start > flat.startIndex ? "…" : "") + String(flat[start..<end]) + (end < flat.endIndex ? "…" : "")
    }
}

public enum NoteFormat {
    public static func newNote(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    /// The note text with a new paragraph added at the end.
    public static func appended(existing: String, text: String) -> String {
        var base = existing
        if !base.isEmpty, !base.hasSuffix("\n") { base += "\n" }
        if !base.isEmpty { base += "\n" }
        return base + text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    /// One part of a long note, so a read never floods the model's context.
    public static func slice(_ text: String, part: Int, size: Int = 3000) -> (text: String, parts: Int) {
        let chars = Array(text)
        let parts = max(1, (chars.count + size - 1) / size)
        let p = min(max(part, 1), parts)
        let from = (p - 1) * size
        let to = min(from + size, chars.count)
        return (String(chars[from..<to]), parts)
    }
}
