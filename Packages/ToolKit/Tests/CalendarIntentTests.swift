import Testing
import Foundation
@testable import ToolKit

@Suite struct CalendarIntentTests {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    /// Friday 9 October 2026.
    private var friday: Date { cal.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 15))! }
    private func range(_ t: String) -> String {
        let r = CalendarIntent.range(for: t, now: friday, calendar: cal)
        return "\(r.startDate) \(r.days)"
    }

    @Test func calendarQuestionsAreRecognised() {
        for t in ["What's on my calendar tomorrow?", "Do I have any meetings today?", "Am I free on Monday?", "What does my schedule look like?", "any appointments this week"] {
            #expect(CalendarIntent.looksLikeCalendarRequest(t), "\(t)")
        }
        for t in ["Tell me a joke", "When is Real Betis' next game?", "Write an email", "What is a free market?"] {
            #expect(!CalendarIntent.looksLikeCalendarRequest(t), "\(t)")
        }
    }

    @Test func reminderQuestionsAreRecognised() {
        #expect(CalendarIntent.looksLikeReminderRequest("What are my reminders?"))
        #expect(CalendarIntent.looksLikeReminderRequest("show my to do list"))
        #expect(!CalendarIntent.looksLikeReminderRequest("What's on my calendar?"))
    }

    @Test func daysAreResolved() {
        #expect(range("what's on tomorrow") == "2026-10-10 1")
        #expect(range("events today") == "2026-10-09 1")
        #expect(range("meetings this week") == "2026-10-09 7")
        #expect(range("what do I have next week") == "2026-10-12 7")
        #expect(range("am I free on Monday") == "2026-10-12 1")
        #expect(range("anything on Friday") == "2026-10-09 1")
        #expect(range("anything next Friday") == "2026-10-16 1")
        #expect(range("what's in my calendar") == "2026-10-09 7")
        #expect(range("events this month") == "2026-10-09 31")
    }
}
