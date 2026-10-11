import Foundation
import Observation

/// Where notification taps, Siri and links leave a request until the chat screen is ready to act on it.
@MainActor @Observable
final class LaunchRouter {
    static let shared = LaunchRouter()
    var pendingBriefing: UUID?
    var pendingQuestion: String?

    func open(briefing id: UUID) { pendingBriefing = id }
    func ask(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { pendingQuestion = t }
    }
}
