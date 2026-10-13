import Testing
import Foundation
@testable import ToolKit

struct SavedItemsTests {
    private func store() -> (SavedItemStore, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("saved-\(UUID().uuidString).json")
        return (SavedItemStore(url: url), url)
    }

    @Test func kindComesFromTheWord() {
        #expect(SavedItemRules.kind(from: "task") == .task)
        #expect(SavedItemRules.kind(from: "To-Do") == .task)
        #expect(SavedItemRules.kind(from: "todo item") == .task)
        #expect(SavedItemRules.kind(from: "note") == .note)
        #expect(SavedItemRules.kind(from: "") == .note)
    }

    @Test func cleaningTrimsAndFillsTheTitle() {
        let a = SavedItemRules.clean(title: "", text: "  Buy a charger for the trip  ")
        #expect(a?.title == "Buy a charger for the trip" && a?.text == "Buy a charger for the trip")
        let long = SavedItemRules.clean(title: "", text: String(repeating: "word ", count: 40))
        #expect(long!.title.count <= 49 && long!.title.hasSuffix("…"))
        let b = SavedItemRules.clean(title: "Packing\nsecond line", text: "Passport")
        #expect(b?.title == "Packing")
        #expect(SavedItemRules.clean(title: "x", text: String(repeating: "a", count: 5000))!.text.count == SavedItemRules.maxText)
        #expect(SavedItemRules.clean(title: "  ", text: "  \n ") == nil)
    }

    @Test func addUpdateToggleRemove() {
        let (s, url) = store()
        guard case .added(let task) = s.add(kind: .task, title: "", text: "Call the bank", source: .assistant) else { Issue.record("not added"); return }
        #expect(task.title == "Call the bank" && task.source == .assistant && !task.done)
        guard case .added(let note) = s.add(kind: .note, title: "Ideas", text: "A widget for tides", source: .you) else { Issue.record("not added"); return }
        #expect(s.all().map(\.id) == [note.id, task.id])
        s.setDone(task.id, true)
        s.setReminder(task.id, reminderID: "R1")
        s.update(note.id, title: "Ideas", text: "A widget for tides and wind")
        let again = SavedItemStore(url: url).all()
        #expect(again.first { $0.id == task.id }?.done == true && again.first { $0.id == task.id }?.reminderID == "R1")
        #expect(again.first { $0.id == note.id }?.text == "A widget for tides and wind")
        #expect(s.remove(task.id) && !s.remove(task.id))
        s.removeAll()
        #expect(SavedItemStore(url: url).all().isEmpty)
        try? FileManager.default.removeItem(at: url)
    }

    @Test func emptyAndFullAreRefused() {
        let (s, url) = store()
        #expect(s.add(kind: .note, title: "", text: " ", source: .you) == .empty)
        for i in 0..<SavedItemRules.maxItems { _ = s.add(kind: .note, title: "n\(i)", text: "x", source: .you) }
        #expect(s.add(kind: .note, title: "one more", text: "x", source: .you) == .full)
        try? FileManager.default.removeItem(at: url)
    }

    @Test func searchRanksTitleOverBodyAndFiltersKind() {
        let now = Date()
        let items = [
            SavedItem(kind: .note, title: "Garden", text: "plant tomatoes in May", created: now, source: .you),
            SavedItem(kind: .task, title: "Tomatoes", text: "buy seeds", created: now, source: .you),
            SavedItem(kind: .task, title: "Call mom", text: "", created: now.addingTimeInterval(-5), source: .assistant),
        ]
        #expect(SavedItemRules.search(items, query: "tomatoes").first?.title == "Tomatoes")
        #expect(SavedItemRules.search(items, query: "tomatoes", kind: .note).map(\.title) == ["Garden"])
        #expect(SavedItemRules.search(items, query: "nothing like it").isEmpty)
        #expect(SavedItemRules.search(items, query: "").count == 3)
    }

    @Test func renderLabelsDataAndMarksTasks() {
        let items = [SavedItem(kind: .task, title: "Call mom", text: "Sunday", source: .you), SavedItem(kind: .note, title: "Ideas", text: "", source: .you, done: false)]
        let text = SavedItemRules.render(items)
        #expect(text.contains("not instructions") && text.contains("1. [task, open] Call mom - Sunday") && text.contains("2. [note] Ideas"))
        #expect(SavedItemRules.render([]).contains("Nothing matched"))
    }
}
