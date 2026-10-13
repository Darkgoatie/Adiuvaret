import Foundation

/// A scheduled summary the user sets up once. The phone shows a short notification at the chosen time and builds the full briefing when the user opens it.
public struct Briefing: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var hour: Int
    public var minute: Int
    /// Calendar weekdays, 1 = Sunday ... 7 = Saturday.
    public var weekdays: [Int]
    public var enabled: Bool
    public var includeCalendar: Bool
    public var includeReminders: Bool
    /// Free words the user adds, such as "Betis result and weather in Seville".
    public var extra: String
    /// Event titles on the lock screen. Off by default, so the notification shows counts and times only.
    public var titlesOnLockScreen: Bool

    public init(id: UUID = UUID(), title: String, hour: Int = 8, minute: Int = 0, weekdays: [Int] = Array(1...7), enabled: Bool = true,
                includeCalendar: Bool = true, includeReminders: Bool = true, extra: String = "", titlesOnLockScreen: Bool = false) {
        self.id = id; self.title = title
        self.hour = min(max(hour, 0), 23); self.minute = min(max(minute, 0), 59)
        self.weekdays = Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
        self.enabled = enabled; self.includeCalendar = includeCalendar; self.includeReminders = includeReminders
        self.extra = String(extra.prefix(BriefingLimits.maxExtra)); self.titlesOnLockScreen = titlesOnLockScreen
    }
}

public enum BriefingLimits {
    public static let maxBriefings = 8
    public static let maxExtra = 200
    /// iOS keeps 64 pending notifications per app, so the schedule looks this many days ahead for each briefing.
    public static let daysAhead = 7
}

/// Tools a briefing chat may use. Everything here only reads; nothing that writes, sends or clicks is on the list.
public enum BriefingTools {
    public static let allowed: Set<String> = ["readCalendar", "findFreeTime", "listReminders", "searchWeb", "searchNotes", "readNote",
                                               "listGitHubIssues", "searchNotion"]

    public static func filter(_ ids: [String]) -> [String] { ids.filter(allowed.contains) }

    /// The tools a briefing chat is given, fixed by what the briefing asks for. No router guess is involved.
    public static func tools(for b: Briefing) -> [String] {
        var ids: [String] = []
        if b.includeCalendar { ids.append("readCalendar") }
        if b.includeReminders { ids.append("listReminders") }
        if !b.extra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { ids.append("searchWeb") }
        return filter(ids)
    }
}

public enum BriefingPrompt {
    /// The message that starts a briefing chat. It names what to read and tells the model not to change anything.
    public static func text(for b: Briefing, now: Date = Date(), calendar: Calendar = .current) -> String {
        var parts: [String] = []
        if b.includeCalendar { parts.append("read my calendar events for today") }
        if b.includeReminders { parts.append("list my open reminders") }
        let extra = b.extra.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty { parts.append("look up: \(extra)") }
        if parts.isEmpty { parts.append("say good morning in one sentence") }
        let day = now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(calendar.locale ?? .current))
        return "Give me my briefing \"\(b.title)\" for \(day). Please " + parts.joined(separator: ", ") + ". Keep it short, one line per item. Only read, do not create, move, delete or send anything."
    }
}
