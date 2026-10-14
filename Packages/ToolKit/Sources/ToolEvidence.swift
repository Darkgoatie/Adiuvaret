import Foundation

/// Calendar and reminder tools are only offered when the message shows evidence of being about them. Without a model reading the
/// message first, one generic word (add, schedule, week, free, list) is enough for the catalog search to pick them, so a request
/// about a server or an API ended up with the calendar. Pure logic.
public enum ToolEvidence {
    public static let guarded: Set<String> = ["Calendar", "Reminders"]

    /// Phrases that make a calendar or reminder request on their own.
    private static let strong: [String] = [
        " calendar ", " calendars ", " event ", " events ", " appointment ", " appointments ", " meeting ", " meetings ", " agenda ",
        " birthday ", " birthdays ", " remind ", " reminder ", " reminders ", " todo ", " todos ", " to do ", " checklist ", " overdue ",
        " free time ", " am i free ", " am i busy ", " my day ", " my week ", " my weekend ", " what do i have ", " do i have ",
        " what s on ", " whats on ", " my schedule ", " reschedule ", " postpone ",
        " book a ", " book an ", " schedule a ", " schedule an ", " schedule my ", " haircut ", " dentist ", " lunch with ", " dinner with ",
        " call on ", " a gap ", " gap for ", " push lunch ", " forget to ", " pending tasks ", " my tasks ", " my to do ", " set a reminder ",
        " on monday ", " on tuesday ", " on wednesday ", " on thursday ", " on friday ", " on saturday ", " on sunday ",
        " next monday ", " next tuesday ", " next wednesday ", " next thursday ", " next friday ", " next saturday ", " next sunday "]

    /// Words that fit a calendar request but also fit many others. They count only when nothing else matched the message.
    private static let weak: Set<String> = ["task", "tasks", "schedule", "scheduled", "free", "busy", "available", "availability",
                                            "tomorrow", "today", "tonight", "week", "weekend"]

    private static func padded(_ text: String) -> String {
        " " + text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ") + " "
    }

    public static func calendarAllowed(prompt: String, previous: String?, otherMatch: Bool) -> Bool {
        let p = padded(prompt)
        if strong.contains(where: { p.contains($0) }) { return true }
        // A clock time ("at 3pm", "10:30") is a calendar clue.
        if p.range(of: #"\b\d{1,2}:\d\d\b|\b\d{1,2}\s?(am|pm)\b"#, options: .regularExpression) != nil { return true }
        // A short follow-up ("and the day after?") continues a calendar question.
        if let previous, p.split(separator: " ").count <= 7 {
            let before = padded(previous)
            if strong.contains(where: { before.contains($0) }) { return true }
        }
        if otherMatch { return false }
        return !Set(p.split(separator: " ").map(String.init)).isDisjoint(with: weak)
    }

    /// The entries without calendar and reminder tools when the message gives no evidence for them.
    /// `otherMatch` is true when a specific tool, skill, connector or API request already explains the message.
    public static func filter(_ entries: [CatalogEntry], prompt: String, previous: String?, otherMatch: Bool = false) -> [CatalogEntry] {
        let others = otherMatch || entries.contains { !guarded.contains($0.category) }
        return calendarAllowed(prompt: prompt, previous: previous, otherMatch: others)
            ? entries : entries.filter { !guarded.contains($0.category) }
    }
}
