import Foundation

/// Gemma and several other chat templates refuse a conversation unless it goes user, assistant, user, assistant.
/// A failed reply leaves a user message with no answer, so saved chats can break that rule.
public enum ChatAlternation {
    public struct Turn: Equatable, Sendable {
        public let isUser: Bool
        public let text: String
        public init(isUser: Bool, text: String) { self.isUser = isUser; self.text = text }
    }

    /// Turns that start with a user message, strictly alternate, and end with an assistant message, so one new user message can follow.
    /// Neighbouring messages from the same side are merged: users keep both questions, assistants keep the last answer.
    public static func normalize(_ turns: [Turn]) -> [Turn] {
        var out: [Turn] = []
        for turn in turns where !turn.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if out.isEmpty && !turn.isUser { continue }
            if let last = out.last, last.isUser == turn.isUser {
                out[out.count - 1] = Turn(isUser: turn.isUser, text: turn.isUser ? last.text + "\n" + turn.text : turn.text)
            } else {
                out.append(turn)
            }
        }
        if out.last?.isUser == true { out.removeLast() }
        return out
    }

    /// True when the list alternates from a user message.
    public static func alternates(_ turns: [Turn]) -> Bool {
        for (i, t) in turns.enumerated() where t.isUser != (i % 2 == 0) { return false }
        return true
    }
}
