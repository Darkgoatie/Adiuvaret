import Foundation

public struct BriefingEvent: Sendable, Equatable {
    public let title: String
    public let start: Date
    public let isAllDay: Bool
    public init(title: String, start: Date, isAllDay: Bool = false) { self.title = title; self.start = start; self.isAllDay = isAllDay }
}

/// The fixed text of the notification, built from numbers and times without any model. It is rebuilt every time the app runs, so it is only as fresh as the last run.
public enum BriefingTemplate {
    public struct Words: Sendable {
        public var noEvents: String
        public var oneEvent: String
        public var manyEvents: String   // contains %d
        public var firstAt: String      // contains %@ (time)
        public var firstTitled: String  // contains %@ (title) then %@ (time)
        public var reminders: String    // contains %d
        public var tapToOpen: String
        public init(noEvents: String = "Nothing on your calendar today.", oneEvent: String = "1 event today.", manyEvents: String = "%d events today.",
                    firstAt: String = "First at %@.", firstTitled: String = "%@ at %@.", reminders: String = "%d open reminders.", tapToOpen: String = "Tap for your briefing.") {
            self.noEvents = noEvents; self.oneEvent = oneEvent; self.manyEvents = manyEvents; self.firstAt = firstAt
            self.firstTitled = firstTitled; self.reminders = reminders; self.tapToOpen = tapToOpen
        }
    }

    public static func body(for b: Briefing, events: [BriefingEvent]?, openReminders: Int?, time: (Date) -> String, words: Words = Words()) -> String {
        var lines: [String] = []
        if b.includeCalendar, let events {
            let timed = events.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
            if events.isEmpty { lines.append(words.noEvents) }
            else {
                lines.append(events.count == 1 ? words.oneEvent : words.manyEvents.replacingOccurrences(of: "%d", with: "\(events.count)"))
                if let first = timed.first {
                    let t = time(first.start)
                    lines.append(b.titlesOnLockScreen
                                 ? words.firstTitled.replacingOccurrences(of: "%@", with: first.title, options: [], range: words.firstTitled.range(of: "%@")).replacingOccurrences(of: "%@", with: t)
                                 : words.firstAt.replacingOccurrences(of: "%@", with: t))
                }
            }
        }
        if b.includeReminders, let n = openReminders, n > 0 { lines.append(words.reminders.replacingOccurrences(of: "%d", with: "\(n)")) }
        if lines.isEmpty { lines.append(words.tapToOpen) }
        return lines.joined(separator: " ")
    }
}
