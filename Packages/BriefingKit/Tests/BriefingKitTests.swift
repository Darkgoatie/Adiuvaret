import Testing
import Foundation
@testable import BriefingKit

private func utc() -> Calendar {
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; c.locale = Locale(identifier: "en_US"); return c
}
private func date(_ s: String) -> Date {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f.date(from: s)!
}

@Suite struct BriefingScheduleTests {
    @Test func firesOnChosenWeekdaysOnly() {
        // 2026-10-12 is a Monday (weekday 2).
        let b = Briefing(title: "Morning", hour: 8, minute: 30, weekdays: [2, 4])
        let fires = BriefingSchedule.fireDates(b, from: date("2026-10-12T06:00:00Z"), calendar: utc(), days: 7)
        #expect(fires == [date("2026-10-12T08:30:00Z"), date("2026-10-14T08:30:00Z")])
    }

    @Test func skipsATimeThatHasPassedToday() {
        let b = Briefing(title: "Morning", hour: 8, minute: 0, weekdays: [2])
        let fires = BriefingSchedule.fireDates(b, from: date("2026-10-12T09:00:00Z"), calendar: utc(), days: 7)
        #expect(fires == [])
    }

    @Test func disabledOrEmptyNeverFires() {
        var b = Briefing(title: "x", weekdays: Array(1...7))
        b.enabled = false
        #expect(BriefingSchedule.fireDates(b, from: date("2026-10-12T06:00:00Z"), calendar: utc()).isEmpty)
        let none = Briefing(title: "x", weekdays: [])
        #expect(BriefingSchedule.fireDates(none, from: date("2026-10-12T06:00:00Z"), calendar: utc()).isEmpty)
    }

    @Test func everyDayGivesOneFirePerDay() {
        let b = Briefing(title: "x", hour: 7, minute: 0)
        let fires = BriefingSchedule.fireDates(b, from: date("2026-10-12T06:00:00Z"), calendar: utc(), days: 5)
        #expect(fires.count == 5)
    }

    @Test func budgetIsSharedBetweenBriefings() {
        #expect(BriefingSchedule.daysPerBriefing(count: 1) == 7)
        #expect(BriefingSchedule.daysPerBriefing(count: 8) == 7)
        #expect(BriefingSchedule.daysPerBriefing(count: 20) == 3)
        #expect(BriefingSchedule.daysPerBriefing(count: 100) == 1)
    }

    @Test func requestIDsRoundTrip() {
        let b = Briefing(title: "x")
        let id = BriefingSchedule.requestID(b, fire: date("2026-10-12T08:00:00Z"), calendar: utc())
        #expect(id.hasSuffix("20261012"))
        #expect(BriefingSchedule.briefingID(fromRequestID: id) == b.id)
        #expect(BriefingSchedule.briefingID(fromRequestID: "download.x") == nil)
    }

    @Test func summaryReads() {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        #expect(BriefingSchedule.summary(Briefing(title: "x", hour: 8, minute: 5), weekdayNames: names, every: "Every day") == "Every day 08:05")
        #expect(BriefingSchedule.summary(Briefing(title: "x", hour: 8, minute: 0, weekdays: [2, 3]), weekdayNames: names, every: "Every day") == "Mon Tue 08:00")
    }
}

@Suite struct BriefingContentTests {
    private let time: (Date) -> String = { d in
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "UTC"); return f.string(from: d)
    }

    @Test func inputsAreClamped() {
        let b = Briefing(title: "x", hour: 99, minute: -4, weekdays: [0, 9, 3, 3])
        #expect(b.hour == 23 && b.minute == 0 && b.weekdays == [3])
    }

    @Test func templateCountsAndHidesTitlesByDefault() {
        let b = Briefing(title: "x")
        let events = [BriefingEvent(title: "Dentist", start: date("2026-10-12T14:00:00Z")), BriefingEvent(title: "Standup", start: date("2026-10-12T09:30:00Z")), BriefingEvent(title: "Holiday", start: date("2026-10-12T00:00:00Z"), isAllDay: true)]
        let body = BriefingTemplate.body(for: b, events: events, openReminders: 2, time: time)
        #expect(body == "3 events today. First at 09:30. 2 open reminders.")
        #expect(!body.contains("Standup"))
    }

    @Test func templateShowsTitleWhenAllowed() {
        var b = Briefing(title: "x"); b.titlesOnLockScreen = true
        let body = BriefingTemplate.body(for: b, events: [BriefingEvent(title: "Standup", start: date("2026-10-12T09:30:00Z"))], openReminders: nil, time: time)
        #expect(body == "1 event today. Standup at 09:30.")
    }

    @Test func templateWithoutDataFallsBack() {
        let b = Briefing(title: "x")
        #expect(BriefingTemplate.body(for: b, events: [], openReminders: 0, time: time) == "Nothing on your calendar today.")
        #expect(BriefingTemplate.body(for: b, events: nil, openReminders: nil, time: time) == "Tap for your briefing.")
    }

    @Test func promptNamesWhatToReadAndForbidsWrites() {
        var b = Briefing(title: "Morning"); b.extra = "Betis result"
        let p = BriefingPrompt.text(for: b, now: date("2026-10-12T06:00:00Z"), calendar: utc())
        #expect(p.contains("read my calendar events for today"))
        #expect(p.contains("list my open reminders"))
        #expect(p.contains("Betis result"))
        #expect(p.contains("do not create, move, delete or send"))
    }

    @Test func toolsFollowTheBriefing() {
        var b = Briefing(title: "x")
        #expect(BriefingTools.tools(for: b) == ["readCalendar", "listReminders"])
        b.includeReminders = false; b.extra = "weather"
        #expect(BriefingTools.tools(for: b) == ["readCalendar", "searchWeb"])
        b.includeCalendar = false; b.extra = "  "
        #expect(BriefingTools.tools(for: b).isEmpty)
    }

    @Test func briefingToolsHaveNoWriteTools() {
        for id in ["createEvent", "moveEvent", "deleteEvent", "createReminder", "writeNote", "draftEmail", "runShortcut", "addTodoistTask", "actOnPage", "actOnPageRisky", "openWebsite"] {
            #expect(!BriefingTools.allowed.contains(id), "\(id)")
        }
        #expect(BriefingTools.filter(["readCalendar", "createEvent", "searchWeb"]) == ["readCalendar", "searchWeb"])
    }
}

@Suite struct BriefingStoreTests {
    private func tmp() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("briefings-\(UUID().uuidString).json") }

    @Test func savesAndReopens() {
        let url = tmp()
        let s = BriefingStore(url: url)
        let b = Briefing(title: "Morning")
        #expect(s.save(b))
        var edited = b; edited.title = "Early"
        #expect(s.save(edited))
        let reopened = BriefingStore(url: url)
        #expect(reopened.all().count == 1 && reopened.find(b.id)?.title == "Early")
        reopened.remove(b.id)
        #expect(BriefingStore(url: url).all().isEmpty)
    }

    @Test func limitIsEnforced() {
        let s = BriefingStore(url: tmp())
        for i in 0..<BriefingLimits.maxBriefings { #expect(s.save(Briefing(title: "b\(i)"))) }
        #expect(!s.save(Briefing(title: "one too many")))
    }

    @Test func attemptLogCountsAndCaps() {
        let log = BriefingAttemptLog(url: tmp())
        log.record(.scheduled); log.record(.ran, "ok"); log.record(.ran); log.record(.expired)
        let s = log.summary()
        #expect(s.scheduled == 1 && s.ran == 2 && s.expired == 1 && s.firstRun != nil)
        for _ in 0..<(BriefingAttemptLog.cap + 20) { log.record(.scheduled) }
        #expect(log.all().count == BriefingAttemptLog.cap)
    }
}
