import Foundation
import Observation

/// Keeps every chat of this session alive so the drawer can reopen them. Chats are not saved across launches yet.
@MainActor @Observable
final class ChatStore {
    struct Entry: Identifiable {
        let id: UUID
        let service: any ChatService
        let created: Date
        var pinned = false
    }

    private(set) var entries: [Entry]
    private(set) var currentID: UUID
    @ObservationIgnored private let make: () -> any ChatService

    init(first: any ChatService, make: @escaping () -> any ChatService) {
        let e = Entry(id: UUID(), service: first, created: Date())
        entries = [e]; currentID = e.id; self.make = make
    }

    var current: any ChatService { entries.first { $0.id == currentID }?.service ?? entries[0].service }

    func replaceCurrent(with service: any ChatService) {
        guard let i = entries.firstIndex(where: { $0.id == currentID }) else { return }
        entries[i] = Entry(id: currentID, service: service, created: entries[i].created, pinned: entries[i].pinned)
    }

    /// Reuses the open chat when it is still empty so blank chats do not pile up.
    func newChat() {
        if current.items.isEmpty { return }
        let e = Entry(id: UUID(), service: make(), created: Date())
        entries.append(e); currentID = e.id
    }

    func select(_ id: UUID) { if entries.contains(where: { $0.id == id }) { currentID = id } }

    func togglePin(_ id: UUID) {
        if let i = entries.firstIndex(where: { $0.id == id }) { entries[i].pinned.toggle() }
    }

    func delete(_ id: UUID) {
        current.stop()
        entries.removeAll { $0.id == id }
        if entries.isEmpty {
            let e = Entry(id: UUID(), service: make(), created: Date()); entries = [e]; currentID = e.id
        } else if !entries.contains(where: { $0.id == currentID }) {
            currentID = entries[entries.count - 1].id
        }
    }

    /// Chats that have at least one message, newest first.
    var summaries: [ChatSummary] {
        let cal = Calendar.current
        return entries.filter { !$0.service.items.isEmpty }.sorted { $0.created > $1.created }.map { e in
            let group: ChatSummary.Group
            if e.pinned { group = .pinned }
            else if cal.isDateInToday(e.created) { group = .today }
            else if cal.isDateInYesterday(e.created) { group = .yesterday }
            else if let d = cal.dateComponents([.day], from: e.created, to: Date()).day, d < 7 { group = .week }
            else { group = .older }
            return ChatSummary(id: e.id, title: e.service.title, group: group)
        }
    }
}
