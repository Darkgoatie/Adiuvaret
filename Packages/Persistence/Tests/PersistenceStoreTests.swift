import Testing
import Foundation
@testable import Persistence

@MainActor @Suite struct PersistenceStoreTests {
    private func chat(_ id: UUID = UUID(), items: Int = 2) -> ChatSnapshot {
        ChatSnapshot(id: id, title: "Dentist", created: Date(timeIntervalSince1970: 1_000), pinned: false,
                     items: (0..<items).map { ItemSnapshot(id: UUID(), kind: "user", payload: Data("m\($0)".utf8)) })
    }

    @Test func roundTripKeepsOrderAndFields() throws {
        let s = try PersistenceStore(inMemory: true)
        let c = chat(items: 3)
        s.save(c)
        let loaded = s.loadChats()
        #expect(loaded == [c])
    }

    @Test func savingAgainReplacesItems() throws {
        let s = try PersistenceStore(inMemory: true)
        let id = UUID()
        s.save(chat(id, items: 3))
        var next = chat(id, items: 1)
        next.title = "Renamed"; next.pinned = true
        s.save(next)
        let loaded = s.loadChats()
        #expect(loaded.count == 1)
        #expect(loaded[0].title == "Renamed" && loaded[0].pinned)
        #expect(loaded[0].items.count == 1)
        #expect(s.itemCount() == 1)
    }

    @Test func deleteRemovesChatAndItems() throws {
        let s = try PersistenceStore(inMemory: true)
        let a = chat(), b = chat()
        s.save(a); s.save(b)
        s.delete(id: a.id)
        #expect(s.loadChats().map(\.id) == [b.id])
        #expect(s.itemCount() == 2)
    }

    @Test func chatsLoadOldestFirst() throws {
        let s = try PersistenceStore(inMemory: true)
        var late = chat(); late = ChatSnapshot(id: late.id, title: "late", created: Date(timeIntervalSince1970: 9_000), pinned: false, items: [])
        let early = ChatSnapshot(id: UUID(), title: "early", created: Date(timeIntervalSince1970: 1), pinned: false, items: [])
        s.save(late); s.save(early)
        #expect(s.loadChats().map(\.title) == ["early", "late"])
    }
}
