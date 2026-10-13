import Foundation

/// Code-side rule for "the user asked for a skill", so the tool is offered whatever the router decided.
public enum SkillIntent {
    private static let actions: Set<String> = ["use", "run", "apply", "follow", "saved", "available", "installed", "registered", "playbook", "playbooks"]

    public static func looksLikeSkillRequest(_ text: String) -> Bool {
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        guard words.contains("skill") || words.contains("skills") || words.contains("workflow") || words.contains("workflows") else { return false }
        let flat = " " + words.joined(separator: " ") + " "
        if flat.contains(" workflows do you ") || flat.contains(" workflows you have ") || flat.contains(" your workflows ") || flat.contains(" list workflows ") || flat.contains(" skills do you ") || flat.contains(" skills you have ") || flat.contains(" your skills ") || flat.contains(" list skills ") || flat.contains(" list your skills ") { return true }
        return words.contains { actions.contains($0) }
    }
}

/// How a model without tool calling asks for a skill: a reply that is only `skill_use: <id>`.
public enum SkillCall {
    public static let marker = "skill_use:"

    /// The skill id when the whole reply is a request for one, else nil.
    public static func parse(_ reply: String) -> String? {
        let fence = CharacterSet(charactersIn: "`")
        var t = reply.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: fence).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.contains("\n"), t.lowercased().hasPrefix(marker) else { return nil }
        t = String(t.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces).lowercased()
        guard t.range(of: #"^[a-z0-9][a-z0-9_-]{1,39}$"#, options: .regularExpression) != nil else { return nil }
        return t
    }

    /// True while a streamed reply is, or may still turn out to be, a skill request. The chat holds it back instead of showing it.
    public static func hidesPartial(_ shown: String) -> Bool {
        let t = shown.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "`"))).lowercased()
        if t.isEmpty { return false }
        if marker.hasPrefix(t) { return true }
        return t.hasPrefix(marker) && t.count < 60 && !t.contains("\n")
    }

    /// The line added to the instructions of a model without tool calling, listing what it may ask for.
    public static func instruction(index: String) -> String {
        guard !index.isEmpty else { return "" }
        return "Workflows you can use (named sets of steps):\n\(index)\nTo use one, reply with only this line and nothing else: \(marker) <id>"
    }
}
