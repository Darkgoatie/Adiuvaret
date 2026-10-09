import Foundation

/// Spots calendar and reminder questions and works out which days they mean, so a model without tools still gets the real data.
public enum CalendarIntent {
    private static let calendarWords = ["calendar", "schedule", "agenda", "event", "events", "meeting", "meetings", "appointment", "appointments",
                                        "my day", "free time", "am i free", "am i busy", "busy"]
    private static let reminderWords = ["reminders", "reminder list", "todo", "to do list", "to do"]

    private static func padded(_ text: String) -> String {
        " " + text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ") + " "
    }

    public static func looksLikeCalendarRequest(_ text: String) -> Bool {
        let p = padded(text)
        return calendarWords.contains { p.contains(" " + $0 + " ") }
    }

    public static func looksLikeReminderRequest(_ text: String) -> Bool {
        let p = padded(text)
        return reminderWords.contains { p.contains(" " + $0 + " ") }
    }

    private static let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]

    /// The first day and the number of days to read. Without a clue it is today and the next six days.
    public static func range(for text: String, now: Date = Date(), calendar cal: Calendar = .current) -> (startDate: String, days: Int) {
        let words = padded(text).split(separator: " ").map(String.init)
        let today = cal.startOfDay(for: now)
        let weekday = cal.component(.weekday, from: today)
        func day(_ offset: Int, _ days: Int) -> (String, Int) {
            (CalendarMath.dayString(cal.date(byAdding: .day, value: offset, to: today) ?? today, calendar: cal), days)
        }
        if words.contains("tomorrow") { return day(1, 1) }
        if words.contains("yesterday") { return day(-1, 1) }
        if words.contains("next"), words.contains("week") {
            var toMonday = (9 - weekday) % 7
            if toMonday == 0 { toMonday = 7 }
            return day(toMonday, 7)
        }
        if words.contains("month") { return day(0, 31) }
        if words.contains("week") { return day(0, 7) }
        for (i, w) in words.enumerated() {
            guard let target = weekdays[w] else { continue }
            var diff = (target - weekday + 7) % 7
            if diff == 0, i > 0, words[i - 1] == "next" { diff = 7 }
            return day(diff, 1)
        }
        if words.contains("today") || words.contains("tonight") { return day(0, 1) }
        return day(0, 7)
    }
}
