import Foundation

/// A calendar event reduced to what the skills need. EventKit objects never leave the app target.
public struct EventSlot: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let calendar: String

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false, calendar: String = "") {
        self.id = id; self.title = title; self.start = start; self.end = end; self.isAllDay = isAllDay; self.calendar = calendar
    }
}

/// Date arithmetic for the calendar skills, done in code so the model never computes dates.
public enum CalendarMath {
    private static func parser(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format; return f
    }

    public static func dayString(_ d: Date, calendar: Calendar = .current) -> String {
        let f = parser("yyyy-MM-dd"); f.timeZone = calendar.timeZone; return f.string(from: d)
    }

    /// Resolves yyyy-MM-dd (empty means today) plus a day count (1 to 31) to a half-open range.
    public static func range(startDate: String, days: Int, now: Date = Date(), calendar cal: Calendar = .current) -> (start: Date, end: Date)? {
        let trimmed = startDate.trimmingCharacters(in: .whitespaces)
        var base = cal.startOfDay(for: now)
        if !trimmed.isEmpty {
            let f = parser("yyyy-MM-dd"); f.timeZone = cal.timeZone
            guard let d = f.date(from: trimmed) else { return nil }
            base = cal.startOfDay(for: d)
        }
        guard let end = cal.date(byAdding: .day, value: min(max(days, 1), 31), to: base) else { return nil }
        return (base, end)
    }

    /// Accepts "yyyy-MM-dd HH:mm" or "yyyy-MM-ddTHH:mm" in the given calendar's time zone.
    public static func dateTime(_ text: String, calendar cal: Calendar = .current) -> Date? {
        let t = text.trimmingCharacters(in: .whitespaces)
        for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss"] {
            let f = parser(format); f.timeZone = cal.timeZone
            if let d = f.date(from: t) { return d }
        }
        return nil
    }

    /// Case and accent insensitive match on title or calendar name. An empty query keeps everything.
    public static func filter(_ events: [EventSlot], query: String) -> [EventSlot] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return events }
        let opts: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return events.filter { $0.title.range(of: q, options: opts) != nil || $0.calendar.range(of: q, options: opts) != nil }
    }

    /// Timed events that overlap [start, end). All-day events never conflict.
    public static func conflicts(_ events: [EventSlot], start: Date, end: Date, ignoring id: String? = nil) -> [EventSlot] {
        events.filter { !$0.isAllDay && $0.id != id && $0.start < end && $0.end > start }
    }

    /// Free gaps of at least `minMinutes` inside working hours, one list per day, never before `now`.
    public static func freeSlots(_ events: [EventSlot], in range: (start: Date, end: Date), workStartHour: Int = 8, workEndHour: Int = 20,
                                 minMinutes: Int = 30, now: Date = Date(), calendar cal: Calendar = .current) -> [DateInterval] {
        var out: [DateInterval] = []
        let busy = events.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
        var day = cal.startOfDay(for: range.start)
        while day < range.end {
            defer { day = cal.date(byAdding: .day, value: 1, to: day) ?? range.end }
            guard var cursor = cal.date(bySettingHour: workStartHour, minute: 0, second: 0, of: day),
                  let close = cal.date(bySettingHour: workEndHour, minute: 0, second: 0, of: day) else { continue }
            cursor = max(cursor, now)
            for e in busy where e.end > cursor && e.start < close {
                if e.start > cursor, e.start.timeIntervalSince(cursor) >= Double(minMinutes) * 60 {
                    out.append(DateInterval(start: cursor, end: e.start))
                }
                cursor = max(cursor, e.end)
            }
            if close > cursor, close.timeIntervalSince(cursor) >= Double(minMinutes) * 60 {
                out.append(DateInterval(start: cursor, end: close))
            }
        }
        return out
    }
}
