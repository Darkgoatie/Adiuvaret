import Foundation
import DesignSystem
import Persistence

/// Converts thread items to and from stored form. Transient states are settled on save:
/// a running tool row becomes failed and a pending approval times out, because nothing is running after a relaunch.
enum ThreadItemCoding {
    private struct Row: Codable { var label: String; var value: String }
    private struct Fields: Codable {
        var text: String?
        var title: String?
        var detail: String?
        var open: String?
        var phase: String?
        var details: [String]?
        var rows: [Row]?
        var draftKind: String?
        var to: String?
    }

    static func snapshot(_ item: ThreadItem) -> ItemSnapshot? {
        var f = Fields(); let kind: String
        switch item {
        case .user(_, let t): kind = "user"; f.text = t
        case .assistant(_, let t, _): kind = "assistant"; f.text = t
        case .tool(_, let p, let t, let d):
            kind = "tool"; f.title = t; f.details = d
            f.phase = p == .finished ? "finished" : "failed"
        case .action(_, let p, let t, let d, let o):
            kind = "action"; f.title = t; f.detail = d; f.open = o
            f.phase = p == .undone ? "undone" : (p == .undoExpired ? "expired" : "done")
        case .approval(_, let p, let t, let rows):
            kind = "approval"; f.title = t; f.rows = rows.map { Row(label: $0.label, value: $0.value) }
            switch p { case .approved: f.phase = "approved"; case .denied: f.phase = "denied"; default: f.phase = "timedOut" }
        case .draft(_, let k, let to, let t): kind = "draft"; f.text = t; f.to = to; f.draftKind = k == .mail ? "mail" : "message"
        case .memory(_, let t): kind = "memory"; f.text = t
        case .error(_, let t): kind = "error"; f.text = t
        }
        guard let data = try? JSONEncoder().encode(f) else { return nil }
        return ItemSnapshot(id: item.id, kind: kind, payload: data)
    }

    static func item(_ s: ItemSnapshot) -> ThreadItem? {
        guard let f = try? JSONDecoder().decode(Fields.self, from: s.payload) else { return nil }
        switch s.kind {
        case "user": return .user(id: s.id, text: f.text ?? "")
        case "assistant": return .assistant(id: s.id, text: f.text ?? "", streaming: false)
        case "tool": return .tool(id: s.id, phase: f.phase == "finished" ? .finished : .failed, title: f.title ?? "", details: f.details ?? [])
        case "action":
            let p: ActionCard.Phase = f.phase == "undone" ? .undone : .undoExpired
            return .action(id: s.id, phase: f.phase == "undone" ? p : .undoExpired, title: f.title ?? "", detail: f.detail ?? "", open: nil)
        case "approval":
            let p: ApprovalCard.Phase = f.phase == "approved" ? .approved : (f.phase == "denied" ? .denied : .timedOut)
            return .approval(id: s.id, phase: p, title: f.title ?? "", rows: (f.rows ?? []).map { DetailRow($0.label, $0.value) })
        case "draft": return .draft(id: s.id, kind: f.draftKind == "mail" ? .mail : .message, to: f.to ?? "", text: f.text ?? "")
        case "memory": return .memory(id: s.id, text: f.text ?? "")
        case "error": return .error(id: s.id, text: f.text ?? "")
        default: return nil
        }
    }
}
