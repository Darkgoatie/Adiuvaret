import Testing
import Foundation
@testable import ToolKit

@Suite struct CalendarMathTests {
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }()
    static func at(_ s: String) -> Date { CalendarMath.dateTime(s, calendar: cal)! }
    static func ev(_ id: String, _ title: String, _ a: String, _ b: String, allDay: Bool = false, cal name: String = "Home") -> EventSlot {
        EventSlot(id: id, title: title, start: at(a), end: at(b), isAllDay: allDay, calendar: name)
    }

    @Test func rangeFromDateAndDays() {
        let r = CalendarMath.range(startDate: "2026-10-20", days: 7, now: Self.at("2026-10-07 10:00"), calendar: Self.cal)!
        #expect(r.start == Self.at("2026-10-20 00:00") && r.end == Self.at("2026-10-27 00:00"))
    }

    @Test func emptyStartMeansTodayAndDaysAreClamped() {
        let now = Self.at("2026-10-07 15:30")
        let r = CalendarMath.range(startDate: "", days: 99, now: now, calendar: Self.cal)!
        #expect(r.start == Self.at("2026-10-07 00:00") && r.end == Self.at("2026-11-07 00:00"))
        #expect(CalendarMath.range(startDate: "2026-10-07", days: 0, now: now, calendar: Self.cal)!.end == Self.at("2026-10-08 00:00"))
    }

    @Test func pastRangesWork() {
        let r = CalendarMath.range(startDate: "2026-03-01", days: 31, now: Self.at("2026-10-07 10:00"), calendar: Self.cal)!
        #expect(r.start == Self.at("2026-03-01 00:00") && r.end == Self.at("2026-04-01 00:00"))
    }

    @Test func badDateIsRejected() {
        #expect(CalendarMath.range(startDate: "next tuesday", days: 1, calendar: Self.cal) == nil)
        #expect(CalendarMath.dateTime("tomorrow 9", calendar: Self.cal) == nil)
    }

    @Test func dateTimeAcceptsBothSeparators() {
        #expect(Self.at("2026-10-20T09:30") == Self.at("2026-10-20 09:30"))
    }

    @Test func filterIgnoresCaseAndAccents() {
        let list = [Self.ev("1", "Café with Ana", "2026-10-20 10:00", "2026-10-20 11:00"), Self.ev("2", "Dentist", "2026-10-20 12:00", "2026-10-20 13:00", cal: "Health")]
        #expect(CalendarMath.filter(list, query: "cafe").map(\.id) == ["1"])
        #expect(CalendarMath.filter(list, query: "health").map(\.id) == ["2"])
        #expect(CalendarMath.filter(list, query: "  ").count == 2)
    }

    @Test func conflictsUseHalfOpenIntervalsAndSkipAllDay() {
        let list = [Self.ev("1", "A", "2026-10-20 10:00", "2026-10-20 11:00"),
                    Self.ev("2", "Holiday", "2026-10-20 00:00", "2026-10-21 00:00", allDay: true)]
        #expect(CalendarMath.conflicts(list, start: Self.at("2026-10-20 10:30"), end: Self.at("2026-10-20 11:30")).map(\.id) == ["1"])
        #expect(CalendarMath.conflicts(list, start: Self.at("2026-10-20 11:00"), end: Self.at("2026-10-20 12:00")).isEmpty)
        #expect(CalendarMath.conflicts(list, start: Self.at("2026-10-20 10:30"), end: Self.at("2026-10-20 11:30"), ignoring: "1").isEmpty)
    }

    @Test func freeSlotsAroundEvents() {
        let list = [Self.ev("1", "A", "2026-10-20 09:00", "2026-10-20 10:00"), Self.ev("2", "B", "2026-10-20 13:00", "2026-10-20 14:00"),
                    Self.ev("3", "Overlap", "2026-10-20 13:30", "2026-10-20 15:00")]
        let r = CalendarMath.range(startDate: "2026-10-20", days: 1, calendar: Self.cal)!
        let slots = CalendarMath.freeSlots(list, in: r, now: Self.at("2026-10-01 00:00"), calendar: Self.cal)
        #expect(slots.map { $0.start } == [Self.at("2026-10-20 08:00"), Self.at("2026-10-20 10:00"), Self.at("2026-10-20 15:00")])
        #expect(slots.map { $0.end } == [Self.at("2026-10-20 09:00"), Self.at("2026-10-20 13:00"), Self.at("2026-10-20 20:00")])
    }

    @Test func freeSlotsSkipThePastAndShortGaps() {
        let list = [Self.ev("1", "A", "2026-10-20 10:00", "2026-10-20 10:45")]
        let r = CalendarMath.range(startDate: "2026-10-20", days: 1, calendar: Self.cal)!
        let slots = CalendarMath.freeSlots(list, in: r, minMinutes: 60, now: Self.at("2026-10-20 09:30"), calendar: Self.cal)
        #expect(slots.map { $0.start } == [Self.at("2026-10-20 10:45")])
    }

    @Test func allDayEventsDoNotBlockTime() {
        let list = [Self.ev("1", "Holiday", "2026-10-20 00:00", "2026-10-21 00:00", allDay: true)]
        let r = CalendarMath.range(startDate: "2026-10-20", days: 1, calendar: Self.cal)!
        let slots = CalendarMath.freeSlots(list, in: r, now: Self.at("2026-10-01 00:00"), calendar: Self.cal)
        #expect(slots.count == 1 && slots[0].duration == 12 * 3600)
    }
}
