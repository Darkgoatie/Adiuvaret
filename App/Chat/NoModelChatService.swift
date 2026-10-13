import Foundation
import Observation
import ModelLibrary

/// The chat of a person who has no usable model yet: no Apple Intelligence, nothing downloaded and no online model connected.
/// It keeps the thread so nothing is lost, and tells the person how to get a model.
@MainActor @Observable
final class NoModelChatService: ChatService {
    private(set) var items: [ThreadItem]
    let isGenerating = false
    var banner: ChatBanner? { .noModel }
    private(set) var title = String(localized: "New chat")
    let modelID = ModelCatalog.noModelID
    var modelName: String { String(localized: "No model") }

    init(restoring items: [ThreadItem] = [], title: String? = nil) {
        self.items = items
        if let title { self.title = title }
    }

    func send(_ text: String, attachments: [ChatFile]) async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        items.append(.user(id: UUID(), text: t))
        if title == String(localized: "New chat") { title = String(t.prefix(40)) }
        items.append(.error(id: UUID(), text: String(localized: "There is no model to answer with yet. Connect an online model in Settings, Providers, or download one in Models.")))
    }

    func stop() {}
    func approve(_ id: UUID) {}
    func deny(_ id: UUID) {}
    func undo(_ id: UUID) {}

    func retry() async {
        if case .error? = items.last { items.removeLast() }
        if case .user(_, let t)? = items.last { items.removeLast(); await send(t, attachments: []) }
    }

    func setTitle(_ t: String) {
        let c = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if !c.isEmpty { title = String(c.prefix(60)) }
    }

    func edit(_ id: UUID, text: String) async {}
    func regenerate(_ id: UUID) async {}
    func deleteMessage(_ id: UUID) {}
}
