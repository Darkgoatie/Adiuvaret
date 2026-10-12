import Foundation
import Observation
import DesignSystem
import ModelLibrary

struct ChatSummary: Identifiable, Hashable {
    enum Group: Int, CaseIterable { case pinned, today, yesterday, week, older }
    let id: UUID
    var title: String
    var group: Group
}

enum ThreadItem: Identifiable {
    case user(id: UUID, text: String)
    /// Files that went with the user message right after this row.
    case userFiles(id: UUID, files: [ChatFile])
    case assistant(id: UUID, text: String, streaming: Bool)
    case tool(id: UUID, phase: ToolProgressRow.Phase, title: String, details: [String])
    case action(id: UUID, phase: ActionCard.Phase, title: String, detail: String, open: String?)
    case approval(id: UUID, phase: ApprovalCard.Phase, title: String, rows: [DetailRow])
    case draft(id: UUID, kind: DraftCard.Kind, to: String, text: String)
    case memory(id: UUID, text: String)
    case skillOffer(id: UUID, phase: SkillOfferCard.Phase, title: String)
    case error(id: UUID, text: String)

    var id: UUID {
        switch self {
        case .user(let i, _), .userFiles(let i, _), .assistant(let i, _, _), .tool(let i, _, _, _), .action(let i, _, _, _, _),
             .approval(let i, _, _, _), .draft(let i, _, _, _), .memory(let i, _), .skillOffer(let i, _, _), .error(let i, _): i
        }
    }
}

enum ChatBanner: Equatable {
    case appleIntelligenceUnavailable, offline, thermal, killSwitch
}

/// Everything the chat screen needs. The demo implementation and the real runtime both conform.
@MainActor protocol ChatService: AnyObject, Observable {
    var items: [ThreadItem] { get }
    var isGenerating: Bool { get }
    var banner: ChatBanner? { get }
    var title: String { get }
    var modelID: String { get }
    var modelName: String { get }
    func send(_ text: String, attachments: [ChatFile]) async
    func stop()
    func approve(_ id: UUID)
    func deny(_ id: UUID)
    func undo(_ id: UUID)
    func retry() async
    func setTitle(_ t: String)
    /// Replaces one of the user's messages, drops everything after it, and answers again.
    func edit(_ id: UUID, text: String) async
    /// Replaces the newest assistant reply with a fresh one.
    func regenerate(_ id: UUID) async
    /// Removes one message. Tool rows and cards go with the chat, not one by one.
    func deleteMessage(_ id: UUID)
}

extension ChatService {
    func send(_ text: String) async { await send(text, attachments: []) }

    /// What the open model can take as attachments.
    var fileSupport: AttachmentSupport { ModelCapabilities.support(for: modelID) }

    /// The provider's name when attached files would leave the phone, nil for models that run on it.
    var fileDestination: String? { Providers.parseModelID(modelID)?.provider.name }
}

extension Array where Element == ThreadItem {
    /// The files of the newest user message, which the model is about to answer.
    func currentTurnFiles() -> [ChatFile] {
        guard let i = lastIndex(where: { if case .user = $0 { true } else { false } }) else { return [] }
        return attachments(beforeUser: i)
    }

    /// Removes one message and the row of files that went with it. The stored copies are deleted too.
    mutating func removeMessage(at i: Int) {
        guard indices.contains(i) else { return }
        if i > 0, case .userFiles(_, let files) = self[i - 1], case .user = self[i] {
            AttachmentStore.remove(files)
            removeSubrange((i - 1)...i)
        } else {
            remove(at: i)
        }
    }

    /// Cuts the thread back to just before the user message at `i`, files row included, and returns the files so an edit can send them again.
    mutating func truncate(beforeUser i: Int) -> [ChatFile] {
        let files = attachments(beforeUser: i)
        let start = files.isEmpty ? i : i - 1
        let keep = Set(files.map(\.id))
        for case .userFiles(_, let later) in self[start...] { AttachmentStore.remove(later.filter { !keep.contains($0.id) }) }
        removeSubrange(start...)
        return files
    }

    /// The files attached to the user message at `index`; they sit in the row just before it.
    func attachments(beforeUser index: Int) -> [ChatFile] {
        guard index > 0, indices.contains(index), case .userFiles(_, let files) = self[index - 1] else { return [] }
        return files
    }
}

extension ThreadItem {
    var editingRole: ThreadEditing.Role {
        switch self {
        case .user: .user
        case .assistant: .assistant
        default: .other
        }
    }

    /// Changes whenever what a row shows changes. Used to skip redrawing rows that did not change.
    var renderKey: String {
        switch self {
        case .user(let i, let t): "u\(i)\(t.count)\(t.hashValue)"
        case .userFiles(let i, let f): "f\(i)\(f.map(\.id))"
        case .assistant(let i, let t, let s): "a\(i)\(s)\(t.count)\(t.hashValue)"
        case .tool(let i, let p, let t, let d): "t\(i)\(p)\(t)\(d)"
        case .action(let i, let p, let t, let d, let o): "x\(i)\(p)\(t)\(d)\(o ?? "")"
        case .approval(let i, let p, let t, let r): "p\(i)\(p)\(t)\(r.map { $0.label + $0.value })"
        case .draft(let i, let k, let to, let t): "d\(i)\(k)\(to)\(t.hashValue)"
        case .memory(let i, let t): "m\(i)\(t)"
        case .skillOffer(let i, let p, let t): "s\(i)\(p)\(t)"
        case .error(let i, let t): "e\(i)\(t)"
        }
    }

    var messageText: String? {
        switch self {
        case .user(_, let t), .assistant(_, let t, _): t
        default: nil
        }
    }
}
