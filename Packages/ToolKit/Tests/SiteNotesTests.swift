import Testing
import Foundation
@testable import ToolKit

struct SiteNotesTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func personalLabelsAreDropped() {
        #expect(SiteNoteRules.cleanLabel("Calendar") == "Calendar")
        #expect(SiteNoteRules.cleanLabel("  My   timetable ") == "My timetable")
        #expect(SiteNoteRules.cleanLabel("ana@example.com") == nil)
        #expect(SiteNoteRules.cleanLabel("Student 12345678") == nil)
        #expect(SiteNoteRules.cleanLabel("https://x.org/a") == nil)
        #expect(SiteNoteRules.cleanLabel("   ") == nil)
        #expect(SiteNoteRules.cleanLabel(String(repeating: "a", count: 90))?.count == 40)
    }

    @Test func mergeKeepsOrderAndRemovesRepeats() {
        var notes = SiteNoteRules.merge([], host: "Example.org", steps: ["Menu", "Menu", "Calendar", "ana@x.com"], now: now)
        #expect(notes.count == 1)
        #expect(notes[0].host == "example.org")
        #expect(notes[0].routes[0].steps == ["Menu", "Calendar"])
        notes = SiteNoteRules.merge(notes, host: "example.org", steps: ["Menu", "Calendar", "Week"], now: now)
        #expect(notes[0].routes.count == 1)
        #expect(notes[0].routes[0].steps == ["Menu", "Calendar", "Week"])
        notes = SiteNoteRules.merge(notes, host: "example.org", steps: ["Grades"], now: now)
        #expect(notes[0].routes.map(\.steps) == [["Grades"], ["Menu", "Calendar", "Week"]])
    }

    @Test func limitsHold() {
        var notes: [SiteNote] = []
        for i in 0..<40 { notes = SiteNoteRules.merge(notes, host: "h\(i).org", steps: ["A"], now: now) }
        #expect(notes.count == SiteNoteRules.maxHosts)
        #expect(notes[0].host == "h39.org")
        for i in 0..<6 { notes = SiteNoteRules.merge(notes, host: "h39.org", steps: ["S\(i)"], now: now) }
        #expect(notes[0].routes.count == SiteNoteRules.maxRoutes)
        let long = SiteNoteRules.merge([], host: "a.org", steps: (0..<20).map { "Step \($0)" }, now: now)
        #expect(long[0].routes[0].steps.count == SiteNoteRules.maxSteps)
        #expect(SiteNoteRules.merge([], host: "", steps: ["A"], now: now).isEmpty)
        #expect(SiteNoteRules.merge([], host: "a.org", steps: [], now: now).isEmpty)
    }

    @Test func renderNamesTheRoute() {
        let notes = SiteNoteRules.merge([], host: "a.org", steps: ["Menu", "Calendar"], now: now)
        let text = SiteNoteRules.render(notes[0])
        #expect(text.contains("a.org"))
        #expect(text.contains("1. Menu > Calendar"))
        #expect(SiteNoteRules.render(nil).isEmpty)
    }

    @Test func removingRoutesAndHosts() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sitenotes-\(UUID().uuidString).json")
        let store = SiteNoteStore(url: url)
        store.record(host: "a.org", steps: ["Menu", "Calendar"])
        store.record(host: "a.org", steps: ["Grades"])
        store.record(host: "b.org", steps: ["Home"])
        store.removeRoute(host: "a.org", at: 0)
        #expect(store.note(for: "a.org")?.routes.map(\.steps) == [["Menu", "Calendar"]])
        store.removeRoute(host: "a.org", at: 5)
        #expect(store.note(for: "a.org")?.routes.count == 1)
        store.removeRoute(host: "a.org", at: 0)
        #expect(store.note(for: "a.org") == nil)
        store.remove(host: "b.org")
        #expect(SiteNoteStore(url: url).all().isEmpty)
        try? FileManager.default.removeItem(at: url)
    }

    @Test func storePersistsAndClears() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sitenotes-\(UUID().uuidString).json")
        let store = SiteNoteStore(url: url)
        store.record(host: "a.org", steps: ["Menu", "Calendar"])
        #expect(SiteNoteStore(url: url).note(for: "A.org")?.routes.first?.steps == ["Menu", "Calendar"])
        store.clear()
        #expect(SiteNoteStore(url: url).all().isEmpty)
        try? FileManager.default.removeItem(at: url)
    }
}
