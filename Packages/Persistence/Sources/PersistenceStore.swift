import Foundation
import SwiftData

public struct ItemSnapshot: Sendable, Equatable {
    public let id: UUID
    public let kind: String
    public let payload: Data
    public init(id: UUID, kind: String, payload: Data) { self.id = id; self.kind = kind; self.payload = payload }
}

public struct ChatSnapshot: Sendable, Equatable {
    public let id: UUID
    public var title: String
    public let created: Date
    public var pinned: Bool
    public var items: [ItemSnapshot]
    public var modelID: String
    public init(id: UUID, title: String, created: Date, pinned: Bool, items: [ItemSnapshot], modelID: String = "apple") {
        self.id = id; self.title = title; self.created = created; self.pinned = pinned; self.items = items; self.modelID = modelID
    }
}

/// On-device storage for chats, built on SwiftData. Nothing here leaves the phone.
@MainActor
public final class PersistenceStore {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// Opens (or creates) a store at a specific file. Used by tests; the app uses the default location.
    public init(url: URL) throws {
        container = try ModelContainer(for: ChatRecord.self, ItemRecord.self, configurations: ModelConfiguration(url: url))
    }

    public init(inMemory: Bool = false) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: ChatRecord.self, ItemRecord.self, configurations: config)
    }

    /// Oldest first.
    public func loadChats() -> [ChatSnapshot] {
        let all = (try? context.fetch(FetchDescriptor<ChatRecord>(sortBy: [SortDescriptor(\.created)]))) ?? []
        return all.map { c in
            ChatSnapshot(id: c.id, title: c.title, created: c.created, pinned: c.pinned,
                         items: c.items.sorted { $0.order < $1.order }.map { ItemSnapshot(id: $0.id, kind: $0.kind, payload: $0.payload) },
                         modelID: c.modelID)
        }
    }

    public func save(_ chat: ChatSnapshot) {
        let id = chat.id
        let found = try? context.fetch(FetchDescriptor<ChatRecord>(predicate: #Predicate { $0.id == id })).first
        let record = found ?? ChatRecord(id: chat.id, title: chat.title, created: chat.created, updated: Date(), pinned: chat.pinned, modelID: chat.modelID)
        if found == nil { context.insert(record) }
        record.title = chat.title; record.pinned = chat.pinned; record.modelID = chat.modelID; record.updated = Date()
        for old in record.items { context.delete(old) }
        record.items = []
        for (i, item) in chat.items.enumerated() {
            let r = ItemRecord(id: item.id, order: i, kind: item.kind, payload: item.payload)
            context.insert(r)
            r.chat = record
        }
        try? context.save()
    }

    public func delete(id: UUID) {
        if let rec = try? context.fetch(FetchDescriptor<ChatRecord>(predicate: #Predicate { $0.id == id })).first {
            context.delete(rec)
            try? context.save()
        }
    }

    public func itemCount() -> Int { (try? context.fetchCount(FetchDescriptor<ItemRecord>())) ?? 0 }
}
