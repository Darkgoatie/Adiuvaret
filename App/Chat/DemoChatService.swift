import Foundation
import Observation
import DesignSystem
import ModelLibrary

@MainActor @Observable
final class DemoChatService: ChatService {
    private(set) var items: [ThreadItem] = []
    private(set) var isGenerating = false
    private(set) var banner: ChatBanner?
    private(set) var title = String(localized: "New chat")
    private var task: Task<Void, Never>?
    let modelID = "apple"
    let modelName = "Apple"

    init(scenario: Scenario = .empty) {
        switch scenario {
        case .empty: break
        case .conversation: items = Self.sample
        case .killSwitch: banner = .killSwitch; items = Self.sample
        case .unavailable: banner = .appleIntelligenceUnavailable
        }
        if scenario != .empty { title = String(localized: "Dentist planning") }
    }

    enum Scenario { case empty, conversation, killSwitch, unavailable }

    static let sample: [ThreadItem] = [
        .user(id: UUID(), text: String(localized: "Book me a dentist slot Tuesday")),
        .tool(id: UUID(), phase: .finished, title: String(localized: "Looked at calendar · 3 events"),
              details: ["9:00 Standup", "13:00 Lunch with Ana", "17:30 Gym"]),
        .assistant(id: UUID(), text: String(localized: "Tuesday 3:00 PM is free. Want me to put it there?"), streaming: false),
        .approval(id: UUID(), phase: .pending, title: String(localized: "Create this event?"),
                  rows: [DetailRow(String(localized: "Title"), "Dentist"), DetailRow(String(localized: "When"), String(localized: "Tue 3:00-4:00 PM")), DetailRow(String(localized: "Calendar"), String(localized: "Personal"))]),
    ]

    func send(_ text: String, attachments: [ChatFile]) async {
        guard !isGenerating, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if !attachments.isEmpty { items.append(.userFiles(id: UUID(), files: attachments)) }
        items.append(.user(id: UUID(), text: text))
        isGenerating = true
        let toolID = UUID(), replyID = UUID()
        items.append(.tool(id: toolID, phase: .running, title: String(localized: "Checking your calendar…"), details: []))
        let work = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            replace(toolID, with: .tool(id: toolID, phase: .finished, title: String(localized: "Looked at calendar · 2 events"), details: ["9:00 Standup", "13:00 Lunch with Ana"]))
            items.append(.assistant(id: replyID, text: "", streaming: true))
            let words = String(localized: "You have a standup at 9 and lunch with Ana at 1. The rest of the day is open.").split(separator: " ")
            var acc = ""
            for w in words {
                guard !Task.isCancelled else { break }
                acc += (acc.isEmpty ? "" : " ") + w
                replace(replyID, with: .assistant(id: replyID, text: acc, streaming: true))
                try? await Task.sleep(for: .milliseconds(90))
            }
            replace(replyID, with: .assistant(id: replyID, text: acc, streaming: false))
            if title == String(localized: "New chat") { title = String(localized: "Today's plan") }
        }
        task = work
        await work.value
        isGenerating = false
    }

    func setTitle(_ t: String) {}

    func deleteMessage(_ id: UUID) { if !isGenerating { items.removeAll { $0.id == id } } }

    func edit(_ id: UUID, text: String) async {
        guard !isGenerating, let i = items.firstIndex(where: { $0.id == id }), case .user = items[i] else { return }
        let files = items.truncate(beforeUser: i)
        await send(text, attachments: files)
    }

    func regenerate(_ id: UUID) async {
        guard !isGenerating, let i = items.firstIndex(where: { $0.id == id }), case .assistant = items[i],
              let p = items[..<i].lastIndex(where: { if case .user = $0 { true } else { false } }), case .user(_, let t) = items[p] else { return }
        items.removeSubrange(p...)
        await send(t)
    }

    func stop() { task?.cancel() }

    func approve(_ id: UUID) {
        guard case .approval(_, .pending, let t, let rows)? = items.first(where: { $0.id == id }) else { return }
        replace(id, with: .approval(id: id, phase: .approved, title: t, rows: rows))
        items.append(.action(id: UUID(), phase: .done, title: String(localized: "Added Dentist to Calendar"), detail: String(localized: "Tue 3:00-4:00 PM"), open: String(localized: "Open in Calendar")))
    }

    func deny(_ id: UUID) {
        guard case .approval(_, .pending, let t, let rows)? = items.first(where: { $0.id == id }) else { return }
        replace(id, with: .approval(id: id, phase: .denied, title: t, rows: rows))
    }

    func undo(_ id: UUID) {
        guard case .action(_, .done, let t, let d, _)? = items.first(where: { $0.id == id }) else { return }
        replace(id, with: .action(id: id, phase: .undone, title: t, detail: d, open: nil))
    }

    func retry() async {}

    private func replace(_ id: UUID, with item: ThreadItem) {
        if let i = items.firstIndex(where: { $0.id == id }) { items[i] = item }
    }
}
