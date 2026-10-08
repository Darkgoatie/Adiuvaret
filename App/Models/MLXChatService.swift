import Foundation

#if canImport(MLXLLM)
import Observation
import MLXLMCommon
import ModelLibrary
import Diagnostics

/// Chat with a downloaded MLX model. Chat only for now: calendar and reminder tools stay on the Apple model.
@MainActor @Observable
final class MLXChatService: ChatService {
    private(set) var items: [ThreadItem]
    private(set) var isGenerating = false
    private(set) var banner: ChatBanner?
    private(set) var title = String(localized: "New chat")
    let modelID: String

    @ObservationIgnored private var session: ChatSession?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var lastPrompt = ""

    var modelName: String { ModelCatalog.model(modelID)?.name ?? modelID }

    init(restoring items: [ThreadItem] = [], title: String? = nil, modelID: String) {
        self.items = items
        self.modelID = modelID
        if let title { self.title = title }
    }

    func setTitle(_ t: String) {
        let c = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if !c.isEmpty { title = String(c.prefix(60)) }
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isGenerating, !trimmed.isEmpty else { return }
        items.append(.user(id: UUID(), text: trimmed))
        if title == String(localized: "New chat") { title = String(trimmed.prefix(40)) }
        lastPrompt = trimmed
        await run(trimmed)
    }

    func retry() async {
        guard !isGenerating, !lastPrompt.isEmpty else { return }
        if case .error? = items.last { items.removeLast() }
        await run(lastPrompt)
    }

    func stop() { task?.cancel() }
    func approve(_ id: UUID) {}
    func deny(_ id: UUID) {}
    func undo(_ id: UUID) {}

    private func run(_ prompt: String) async {
        isGenerating = true
        let replyID = UUID()
        let work = Task { @MainActor in
            guard ModelSettings.shared.installed.contains(modelID) else {
                items.append(.error(id: UUID(), text: String(localized: "This model was deleted. Pick another one from the model menu at the top.")))
                return
            }
            let clock = ContinuousClock()
            let start = clock.now
            do {
                let chat = try await ensureSession()
                var raw = ""
                var started = false
                for try await chunk in chat.streamResponse(to: prompt) {
                    raw += chunk
                    let shown = ThinkFilter.visible(raw)
                    guard !shown.isEmpty else { continue }
                    if !started {
                        started = true
                        DiagnosticsLog.shared.record("first token", "\((clock.now - start).milliseconds) ms, model=\(modelID)")
                        items.append(.assistant(id: replyID, text: shown, streaming: true))
                    } else {
                        replace(replyID, shown, streaming: true)
                    }
                }
                if started {
                    replace(replyID, ThinkFilter.visible(raw), streaming: false)
                    DiagnosticsLog.shared.record("reply done", "\((clock.now - start).milliseconds) ms, model=\(modelID)")
                } else {
                    items.append(.error(id: UUID(), text: String(localized: "The model didn't write anything. Try asking again.")))
                }
            } catch is CancellationError {
                replace(replyID, nil, streaming: false)
            } catch {
                replace(replyID, nil, streaming: false)
                DiagnosticsLog.shared.record("model error", "\(type(of: error)): \(String(describing: error)) model=\(modelID)")
                items.append(.error(id: UUID(), text: String(localized: "I couldn't use \(modelName).") + "\n" + String(String(describing: error).prefix(200))))
            }
        }
        task = work
        await work.value
        isGenerating = false
    }

    private func ensureSession() async throws -> ChatSession {
        if let session { return session }
        let loadID = UUID()
        items.append(.tool(id: loadID, phase: .running, title: String(localized: "Loading \(modelName)…"), details: []))
        defer { items.removeAll { $0.id == loadID } }
        let started = ContinuousClock.now
        let container = try await MLXRuntime.shared.container(for: modelID)
        DiagnosticsLog.shared.record("model load", "\((ContinuousClock.now - started).milliseconds) ms, model=\(modelID)")
        let chat = ChatSession(container, history: seedHistory(),
                               generateParameters: GenerateParameters(maxTokens: 1024, temperature: 0.6))
        session = chat
        return chat
    }

    /// The system prompt plus the last 12 earlier messages, so a chat started on another model carries on here.
    private func seedHistory() -> [Chat.Message] {
        var prior = items
        if case .user? = prior.last { prior.removeLast() }
        var turns: [(user: Bool, text: String)] = []
        for item in prior {
            switch item {
            case .user(_, let t) where !t.isEmpty: turns.append((true, t))
            case .assistant(_, let t, false) where !t.isEmpty: turns.append((false, t))
            default: break
            }
        }
        while turns.first?.user == false { turns.removeFirst() }
        let history = turns.suffix(12).map { $0.user ? Chat.Message.user($0.text) : Chat.Message.assistant($0.text) }
        return [.system(Self.instructions())] + history
    }

    private static func instructions() -> String {
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .short
        return "You are Adiuvaret, a warm, concise personal assistant on the user's iPhone. Now is \(f.string(from: Date())). In this mode you cannot read the calendar, create reminders or use any other tool, so say so plainly if asked and never pretend to. Write plain, short sentences. Use bold or bullet lists only for several items."
    }

    private func replace(_ id: UUID, _ text: String?, streaming: Bool) {
        guard let i = items.firstIndex(where: { $0.id == id }), case .assistant(_, let old, _) = items[i] else { return }
        items[i] = .assistant(id: id, text: text ?? old, streaming: streaming)
    }
}
#endif
