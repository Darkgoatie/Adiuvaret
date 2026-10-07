import Testing
import Foundation
import SwiftData
@testable import Persistence

@MainActor @Suite struct MigrationTests {
    /// A store written by today's schema must reopen and keep its data. When a v2 schema is added,
    /// extend this with a VersionedSchema pair and a migration plan, as Apple describes for ModelContainer.
    @Test func storeSurvivesReopen() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "adiuvaret-\(UUID().uuidString).store")
        defer { for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) } }
        let id = UUID()
        do {
            let s = try PersistenceStore(url: url)
            s.save(ChatSnapshot(id: id, title: "Kept", created: Date(timeIntervalSince1970: 5), pinned: true,
                                items: [ItemSnapshot(id: UUID(), kind: "user", payload: Data("hi".utf8))]))
        }
        let reopened = try PersistenceStore(url: url)
        let chats = reopened.loadChats()
        #expect(chats.count == 1 && chats[0].id == id && chats[0].title == "Kept" && chats[0].pinned)
        #expect(chats[0].items.count == 1)
    }
}
