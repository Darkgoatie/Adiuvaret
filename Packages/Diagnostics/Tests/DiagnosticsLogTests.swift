import Testing
import Foundation
@testable import Diagnostics

@Suite struct DiagnosticsLogTests {
    @Test func keepsOnlyTheNewestEvents() {
        let log = DiagnosticsLog(capacity: 3)
        for i in 1...5 { log.record("e", "\(i)") }
        #expect(log.snapshot.map(\.detail) == ["3", "4", "5"])
    }

    @Test func detailIsFlattenedAndCapped() {
        let log = DiagnosticsLog()
        log.record("error", String(repeating: "x", count: 1000) + "\nsecond line")
        let d = log.snapshot[0].detail
        #expect(d.count == DiagnosticsLog.maxDetail && !d.contains("\n"))
        log.record("error", "line one\nline two")
        #expect(log.snapshot[1].detail == "line one line two")
    }

    @Test func survivesRestartThroughTheFile() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("diag-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        DiagnosticsLog(capacity: 5, fileURL: url).record("launch", "0.2.0 (19)")
        let again = DiagnosticsLog(capacity: 5, fileURL: url)
        #expect(again.snapshot.map(\.kind) == ["launch"])
        again.clear()
        #expect(DiagnosticsLog(capacity: 5, fileURL: url).snapshot.isEmpty)
    }

    @Test func reportHasHeaderThenEventsOldestFirst() {
        let log = DiagnosticsLog()
        log.record("route", "tools=readCalendar 420 ms", at: Date(timeIntervalSince1970: 0))
        log.record("reply", "first token 900 ms", at: Date(timeIntervalSince1970: 60))
        let text = log.report(header: ["iOS": "26.5", "Device": "iPhone"])
        let lines = text.components(separatedBy: "\n")
        #expect(lines[0] == "Adiuvaret diagnostics")
        #expect(lines.contains("Device: iPhone") && lines.contains("iOS: 26.5"))
        #expect(lines.contains("Events (2)"))
        #expect(text.range(of: "route")!.lowerBound < text.range(of: "reply")!.lowerBound)
    }

    @Test func durationGivesMilliseconds() {
        #expect(Duration.milliseconds(1500).milliseconds == 1500)
        #expect(Duration.seconds(2).milliseconds == 2000)
    }
}
