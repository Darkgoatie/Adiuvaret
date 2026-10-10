import Foundation
import MemoryKit
import Diagnostics

/// The app's one memory store, and the step both chat services run after a user message.
@MainActor
enum MemoryHub {
    static let store = MemoryStore.standard()

    enum Outcome {
        case none
        case saved(MemoryFact)
        case full
    }

    /// Looks for a stated fact in what the user typed and saves it. Logs counts only, never the text.
    static func learn(from message: String) -> Outcome {
        guard let text = FactExtractor.fact(in: message) else { return .none }
        switch store.add(text) {
        case .added(let fact):
            DiagnosticsLog.shared.record("memory", "saved a fact, \(store.all().count) stored")
            return .saved(fact)
        case .duplicate:
            return .none
        case .full:
            DiagnosticsLog.shared.record("memory", "full, not saved")
            return .full
        }
    }

    /// Facts for the instructions of a reply, already labelled as data.
    static func block(for message: String) -> String {
        let text = store.promptBlock(for: message)
        if !text.isEmpty { DiagnosticsLog.shared.record("memory", "added \(text.split(separator: "\n").count - 1) facts to the prompt") }
        return text
    }
}
