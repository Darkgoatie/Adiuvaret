import Foundation
import Observation
import ModelLibrary

/// Where notification taps, Siri and links leave a request until the chat screen is ready to act on it.
@MainActor @Observable
final class LaunchRouter {
    static let shared = LaunchRouter()
    var pendingBriefing: UUID?
    var pendingQuestion: String?
    /// Files sent to Adiuvaret from the share sheet or the Files app, waiting for a chat to hold them.
    var incomingFiles: [ChatFile] = []
    var incomingError: String?

    /// Copies the file into the app and queues it. A failure is kept as a sentence for the composer.
    func receive(file url: URL) {
        do {
            let file = try AttachmentStore.importFile(url)
            incomingFiles.append(file)
            incomingError = nil
        } catch {
            incomingError = (error as? AttachmentError)?.message ?? AttachmentError.unreadable.message
        }
    }

    func open(briefing id: UUID) { pendingBriefing = id }
    func ask(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { pendingQuestion = t }
    }
}
