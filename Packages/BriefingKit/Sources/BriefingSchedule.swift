import Foundation

public enum BriefingSchedule {
    /// The next times this briefing should fire, soonest first, within `days` days of `now`. Disabled briefings never fire.
    public static func fireDates(_ b: Briefing, from now: Date, calendar: Calendar = .current, days: Int = BriefingLimits.daysAhead) -> [Date] {
        guard b.enabled, !b.weekdays.isEmpty else { return [] }
        let startOfToday = calendar.startOfDay(for: now)
        var result: [Date] = []
        for offset in 0..<max(days, 0) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  b.weekdays.contains(calendar.component(.weekday, from: day)),
                  let fire = calendar.date(bySettingHour: b.hour, minute: b.minute, second: 0, of: day),
                  fire > now else { continue }
            result.append(fire)
        }
        return result
    }

    /// Spreads the 64-notification budget over the enabled briefings. Returns how many days each may look ahead.
    public static func daysPerBriefing(count: Int, budget: Int = 60) -> Int {
        guard count > 0 else { return BriefingLimits.daysAhead }
        return max(1, min(BriefingLimits.daysAhead, budget / count))
    }

    /// A readable line such as "Mon Tue Wed 08:00" or "Every day 08:00".
    public static func summary(_ b: Briefing, weekdayNames: [String], every: String) -> String {
        let time = String(format: "%02d:%02d", b.hour, b.minute)
        if b.weekdays.count == 7 { return "\(every) \(time)" }
        let names = b.weekdays.compactMap { (1...weekdayNames.count).contains($0) ? weekdayNames[$0 - 1] : nil }
        return names.joined(separator: " ") + " " + time
    }

    /// Stable id for one notification so rescheduling replaces instead of duplicating.
    public static func requestID(_ b: Briefing, fire: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: fire)
        return String(format: "briefing.%@.%04d%02d%02d", b.id.uuidString, c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func briefingID(fromRequestID id: String) -> UUID? {
        let parts = id.split(separator: ".")
        guard parts.count >= 2, parts[0] == "briefing" else { return nil }
        return UUID(uuidString: String(parts[1]))
    }
}
