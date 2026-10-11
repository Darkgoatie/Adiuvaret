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
        case .user(let i, _), .assistant(let i, _, _), .tool(let i, _, _, _), .action(let i, _, _, _, _),
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
    func send(_ text: String) async
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

extension ThreadItem {
    var editingRole: ThreadEditing.Role {
        switch self {
        case .user: .user
        case .assistant: .assistant
        default: .other
        }
    }

    var messageText: String? {
        switch self {
        case .user(_, let t), .assistant(_, let t, _): t
        default: nil
        }
    }
}
