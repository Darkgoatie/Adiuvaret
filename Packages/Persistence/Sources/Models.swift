import Foundation
import SwiftData

/// One saved chat. Items are stored in order and deleted with the chat.
@Model
public final class ChatRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var created: Date
    public var updated: Date
    public var pinned: Bool
    @Relationship(deleteRule: .cascade, inverse: \ItemRecord.chat) public var items: [ItemRecord] = []

    public init(id: UUID, title: String, created: Date, updated: Date, pinned: Bool) {
        self.id = id; self.title = title; self.created = created; self.updated = updated; self.pinned = pinned
    }
}

/// One thread entry (message, tool row, card). The app encodes its own fields into `payload`.
@Model
public final class ItemRecord {
    @Attribute(.unique) public var id: UUID
    public var order: Int
    public var kind: String
    public var payload: Data
    public var chat: ChatRecord?

    public init(id: UUID, order: Int, kind: String, payload: Data) {
        self.id = id; self.order = order; self.kind = kind; self.payload = payload
    }
}
