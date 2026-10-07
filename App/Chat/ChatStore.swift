import Foundation
import Observation
import Persistence

/// All chats of the app. Live chats are saved on device with SwiftData and restored at launch.
@MainActor @Observable
final class ChatStore {
    struct Entry: Identifiable {
        let id: UUID
        let service: any ChatService
        let created: Date
        var pinned = false
    }

    private(set) var entries: [Entry] = []
    private(set) var currentID = UUID()
    @ObservationIgnored private let make: () -> any ChatService
    @ObservationIgnored private let persistence: PersistenceStore?

    /// `persistence` is nil in demo launches so sample data never overwrites real chats.
    init(persistence: PersistenceStore?, make: @escaping () -> any ChatService) {
        self.persistence = persistence; self.make = make
        for snap in persistence?.loadChats() ?? [] {
            let items = snap.items.compactMap(ThreadItemCoding.item)
            entries.append(Entry(id: snap.id, service: LiveChatService(restoring: items, title: snap.title), created: snap.created, pinned: snap.pinned))
        }
        let blank = Entry(id: UUID(), service: make(), created: Date())
        entries.append(blank)
        currentID = blank.id
    }

    var current: any ChatService { entries.first { $0.id == currentID }?.service ?? entries[0].service }

    func replaceCurrent(with service: any ChatService) {
        guard let i = entries.firstIndex(where: { $0.id == currentID }) else { return }
        entries[i] = Entry(id: currentID, service: service, created: entries[i].created, pinned: entries[i].pinned)
    }

    /// Reuses the open chat when it is still empty so blank chats do not pile up.
    func newChat() {
        persistCurrent()
        if current.items.isEmpty { return }
        let e = Entry(id: UUID(), service: make(), created: Date())
        entries.append(e); currentID = e.id
    }

    func select(_ id: UUID) {
        persistCurrent()
        if entries.contains(where: { $0.id == id }) { currentID = id }
    }

    func togglePin(_ id: UUID) {
        if let i = entries.firstIndex(where: { $0.id == id }) { entries[i].pinned.toggle(); persist(entries[i]) }
    }

    func rename(_ id: UUID, to title: String) {
        guard let e = entries.first(where: { $0.id == id }) else { return }
        e.service.setTitle(title)
        persist(e)
    }

    func delete(_ id: UUID) {
        entries.first { $0.id == id }?.service.stop()
        entries.removeAll { $0.id == id }
        persistence?.delete(id: id)
        if entries.isEmpty {
            let e = Entry(id: UUID(), service: make(), created: Date()); entries = [e]; currentID = e.id
        } else if !entries.contains(where: { $0.id == currentID }) {
            currentID = entries[entries.count - 1].id
        }
    }

    func persistCurrent() { if let e = entries.first(where: { $0.id == currentID }) { persist(e) } }
    func persistAll() { entries.forEach(persist) }

    private func persist(_ e: Entry) {
        guard let persistence, e.service is LiveChatService, !e.service.items.isEmpty else { return }
        persistence.save(ChatSnapshot(id: e.id, title: e.service.title, created: e.created, pinned: e.pinned,
                                      items: e.service.items.compactMap(ThreadItemCoding.snapshot)))
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
