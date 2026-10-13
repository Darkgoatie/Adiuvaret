import Foundation
import Observation
import FoundationModels
import DesignSystem
import AdiuvaretCore
import PolicyEngine
import ToolKit
import Diagnostics
import ModelLibrary
import SkillKit

/// Chat on Apple's on-device model. FoundationModels exists from iOS 26, so everything here is gated; ModelSettings only builds it
/// when `AppleModel.isAvailable`.
@available(iOS 26.0, *)
@MainActor @Observable
final class LiveChatService: ChatService, FixedToolsChat {
    private(set) var items: [ThreadItem] = []
    private(set) var isGenerating = false
    private var availabilityBanner: ChatBanner?
    var banner: ChatBanner? { availabilityBanner ?? (AppSettings.shared.actionsOff ? .killSwitch : nil) }
    private(set) var title = String(localized: "New chat")
    let modelID = "apple"
    let modelName = "Apple"

    @ObservationIgnored private let host = ToolHost()
    private var ctx: TaskContext { host.ctx }
    @ObservationIgnored private var session: LanguageModelSession?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var memoryBlock = ""
    @ObservationIgnored private var useReasoning = !UserDefaults.standard.bool(forKey: "reasoning.unsupported")
    /// The user's switch and the chat's own fallback flag together.
    private var wantReasoning: Bool { useReasoning && AppSettings.shared.deepReasoning }
    @ObservationIgnored private var toolIDs: [String] = []
    @ObservationIgnored private var lastPrompt = ""
    /// The reply being written, so action rows that arrive meanwhile are placed above it.
    @ObservationIgnored private var activeReplyID: UUID?

    @ObservationIgnored var onChange: (() -> Void)?
    /// When set, the chat uses exactly these tools and skips the router. Briefings use it so only reading tools exist.
    @ObservationIgnored var fixedTools: [String]?

    init(restoring items: [ThreadItem] = [], title: String? = nil) {
        self.items = items
        if let title { self.title = title }
        host.attach(self)
        refreshAvailability()
    }

    func refreshAvailability() {
        switch SystemLanguageModel.default.availability {
        case .available: availabilityBanner = nil
        case .unavailable: availabilityBanner = .appleIntelligenceUnavailable
        }
    }

    private func makeSession(history: [ThreadItem] = [], toolIDs: [String]) -> LanguageModelSession {
        let tools = host.appleTools(for: toolIDs)
        let instructions = AssistantPrompt.instructions(ids: toolIDs, memory: memoryBlock, online: false)
        guard let transcript = Self.transcript(instructions: instructions, history: history) else {
            return LanguageModelSession(tools: tools, instructions: instructions)
        }
        return LanguageModelSession(tools: tools, transcript: transcript)
    }

    /// Seeds a new session from saved messages. Only the last 12 user and assistant messages are kept so the 8192-token window has room.
    static func transcript(instructions: String, history: [ThreadItem]) -> Transcript? {
        var turns: [Transcript.Entry] = []
        for item in history {
            switch item {
            case .user(_, let t) where !t.isEmpty:
                turns.append(.prompt(.init(segments: [.text(.init(content: t))])))
            case .assistant(_, let t, false) where !t.isEmpty:
                turns.append(.response(.init(assetIDs: [], segments: [.text(.init(content: t))])))
            default: break
            }
        }
        while case .response? = turns.first { turns.removeFirst() }
        guard !turns.isEmpty else { return nil }
        let head = Transcript.Entry.instructions(.init(segments: [.text(.init(content: instructions))], toolDefinitions: []))
        return Transcript(entries: [head] + turns.suffix(12))
    }

    func setTitle(_ t: String) {
        let c = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if !c.isEmpty { title = String(c.prefix(60)) }
    }

    func send(_ text: String, attachments: [ChatFile]) async {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, !attachments.isEmpty { trimmed = String(localized: "Please read the attached file and tell me what it says.") }
        guard !isGenerating, !trimmed.isEmpty else { return }
        refreshAvailability()
        if !attachments.isEmpty { items.append(.userFiles(id: UUID(), files: attachments)) }
        items.append(.user(id: UUID(), text: trimmed))
        host.learn(from: trimmed)
        if title == String(localized: "New chat") { title = String(trimmed.prefix(40)) }
        guard availabilityBanner != .appleIntelligenceUnavailable else {
            items.append(.error(id: UUID(), text: String(localized: "Apple Intelligence isn't available, so I can't answer yet. Pick another model from the menu at the top.")))
            return
        }
        lastPrompt = trimmed
        await run(trimmed)
    }

    func deleteMessage(_ id: UUID) {
        let roles = items.map(\.editingRole)
        guard let i = items.firstIndex(where: { $0.id == id }), ThreadEditing.canDelete(roles, at: i, generating: isGenerating) else { return }
        items.removeMessage(at: i)
        session = nil
    }

    func edit(_ id: UUID, text: String) async {
        let roles = items.map(\.editingRole)
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let i = items.firstIndex(where: { $0.id == id }), ThreadEditing.canEdit(roles, at: i, generating: isGenerating) else { return }
        let files = items.truncate(beforeUser: i)
        session = nil
        await send(t, attachments: files)
    }

    func regenerate(_ id: UUID) async {
        let roles = items.map(\.editingRole)
        guard let i = items.firstIndex(where: { $0.id == id }), ThreadEditing.canRegenerate(roles, at: i, generating: isGenerating),
              let point = ThreadEditing.regenerationPoint(roles, at: i), case .user(_, let prompt) = items[point.prompt] else { return }
        items.removeSubrange(point.keep...)
        session = nil
        lastPrompt = prompt
        await run(prompt)
    }

    func retry() async {
        guard !isGenerating, !lastPrompt.isEmpty else { return }
        if case .error? = items.last { items.removeLast() }
        await run(lastPrompt)
    }

    private func run(_ prompt: String) async {
        isGenerating = true
        ctx.beginTask(message: prompt)
        let support = fileSupport
        let prepared = AttachmentStore.prepare(items.currentTurnFiles(), support: support)
        let modelPrompt = AttachmentText.compose(prompt: prompt, documents: prepared.documents, imageNames: prepared.skippedImageNames, limit: support.documentChars)
        ctx.notePrivate(prepared.documents.map(\.text).joined(separator: " "))
        let skill = AppSettings.shared.actionsOff ? nil : SkillHub.match(for: prompt)
        if skill?.untrusted == true { ctx.markUntrusted(personal: false) }
        let taught = AppSettings.shared.actionsOff ? nil : TaughtSkillHub.match(for: prompt)
        if taught?.untrusted == true { ctx.markUntrusted(personal: false) }
        let block = [MemoryHub.block(for: prompt), SkillHub.block(from: skill), TaughtSkillHub.block(from: taught)].filter { !$0.isEmpty }.joined(separator: "\n")
        ctx.notePrivate(block)
        if block != memoryBlock { memoryBlock = block; session = nil }
        var prior = items
        if case .user? = prior.last { prior.removeLast() }
        let routeID = UUID()
        let previousPrompt = prior.reversed().compactMap { item -> String? in if case .user(_, let t) = item { return t } else { return nil } }.first
        items.append(.tool(id: routeID, phase: .running, title: String(localized: "Choosing the right tool…"), details: []))
        let clock = ContinuousClock()
        let turnStart = clock.now
        var chosen: [CatalogEntry]
        var routeNote = "fixed tools"
        if let fixed = fixedTools {
            chosen = ToolCatalog.standard.entries.filter { fixed.contains($0.id) }
        } else {
            let routed = await ToolRouter.chooseWithNote(prompt: prompt, previous: previousPrompt)
            chosen = routed.0; routeNote = routed.1
        }
        if let skill, fixedTools == nil {
            // A matched skill brings the tools of its playbook, so the steps it names can actually run.
            let wanted = skill.tools.compactMap { ToolCatalog.standard.entry($0) }
            chosen = ToolCatalog.standard.withRequirements(chosen + wanted, cap: 6)
            routeNote += " skill=\(skill.id)"
        }
        if let taught, fixedTools == nil {
            let wanted = taught.tools.compactMap { ToolCatalog.standard.entry($0) }
            chosen = ToolCatalog.standard.withRequirements(chosen + wanted, cap: 7)
            routeNote += " taught=\(taught.id)"
        }
        DiagnosticsLog.shared.record("route", "tools=[\(chosen.map(\.id).joined(separator: ","))] \(routeNote) \((clock.now - turnStart).milliseconds) ms")
        let ids = chosen.map(\.id)
        if let i = items.firstIndex(where: { $0.id == routeID }) {
            if chosen.isEmpty { items.remove(at: i) }
            else { items[i] = .tool(id: routeID, phase: .finished, title: String(localized: "Using \(chosen.map(\.title).joined(separator: ", "))"), details: []) }
        }
        if session == nil || toolIDs != ids {
            toolIDs = ids
            session = makeSession(history: prior, toolIDs: ids)
        }
        let replyID = UUID()
        activeReplyID = replyID
        let work = Task { @MainActor in
            while let session {
                var started = false
                var firstAt: ContinuousClock.Instant?
                do {
                    for try await partial in Self.stream(session, modelPrompt, reasoning: wantReasoning) {
                        if !started {
                            firstAt = clock.now
                            DiagnosticsLog.shared.record("first token", "\((clock.now - turnStart).milliseconds) ms since send, reasoning=\(wantReasoning && Self.reasoningCompiled)")
                            items.append(.assistant(id: replyID, text: partial.content, streaming: true)); started = true
                        }
                        else { replace(replyID, with: .assistant(id: replyID, text: partial.content, streaming: true)) }
                    }
                    DiagnosticsLog.shared.record("reply done", "\((clock.now - turnStart).milliseconds) ms total")
                    if case .assistant(_, let t, _)? = items.first(where: { $0.id == replyID }) { ReplyStats.shared.record(replyID, text: t, since: firstAt) }
                    finishStreaming(replyID)
                    return
                } catch is CancellationError {
                    DiagnosticsLog.shared.record("cancelled")
                    finishStreaming(replyID)
                    return
                } catch {
                    DiagnosticsLog.shared.record("model error", "\(type(of: error)): \(String(describing: error)) started=\(started) reasoning=\(wantReasoning && Self.reasoningCompiled)")
                    // If the request with a reasoning level fails before any text, retry once on a fresh session without it.
                    if wantReasoning, Self.reasoningCompiled, !started, !Self.isLimit(error) {
                        useReasoning = false
                        if String(describing: error).contains("does not support reasoning") { UserDefaults.standard.set(true, forKey: Self.reasoningUnsupportedKey) }
                        DiagnosticsLog.shared.record("fallback", "reasoning off for this chat, retrying")
                        self.session = makeSession(history: prior, toolIDs: toolIDs)
                        continue
                    }
                    finishStreaming(replyID)
                    if case LanguageModelSession.GenerationError.exceededContextWindowSize = error { self.session = nil }
                    items.append(.error(id: UUID(), text: Self.message(for: error)))
                    return
                }
            }
        }
        task = work
        await work.value
        activeReplyID = nil
        host.offerSkill(for: prompt)
        isGenerating = false
    }

    private static func isLimit(_ error: Error) -> Bool {
        switch error {
        case LanguageModelSession.GenerationError.exceededContextWindowSize, LanguageModelSession.GenerationError.guardrailViolation,
             LanguageModelSession.GenerationError.refusal, LanguageModelSession.GenerationError.rateLimited: true
        default: false
        }
    }

    private static let reasoningUnsupportedKey = "reasoning.unsupported"

    static var reasoningCompiled: Bool { AppleModel.reasoningCompiled }

    /// Asks for the deepest reasoning the on-device model offers. The API exists from iOS 27, so it is
    /// compiled only when the build sets REASONING_API (the Xcode 27 pipeline) and used only on iOS 27 or later.
    private static func stream(_ session: LanguageModelSession, _ prompt: String, reasoning: Bool) -> LanguageModelSession.ResponseStream<String> {
        #if REASONING_API
        if reasoning, #available(iOS 27, *) {
            return session.streamResponse(to: prompt, contextOptions: ContextOptions(reasoningLevel: .deep))
        }
        #endif
        return session.streamResponse(to: prompt)
    }

    private func finishStreaming(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }), case .assistant(_, let t, _) = items[i] else { return }
        items[i] = .assistant(id: id, text: t, streaming: false)
    }

    private static func message(for error: Error) -> String {
        switch error {
        case LanguageModelSession.GenerationError.exceededContextWindowSize:
            String(localized: "This chat got too long for me. Start a new chat and I'll pick up fresh.")
        case LanguageModelSession.GenerationError.guardrailViolation, LanguageModelSession.GenerationError.refusal:
            String(localized: "I can't help with that one.")
        case LanguageModelSession.GenerationError.rateLimited:
            String(localized: "I'm being asked too often right now. Try again in a moment.")
        default:
            String(localized: "I couldn't finish that.") + "\n" + String(String(describing: error).prefix(200))
        }
    }

    func stop() {
        task?.cancel()
        host.stop()
    }

    func approve(_ id: UUID) { _ = host.approve(id) }
    func deny(_ id: UUID) { _ = host.deny(id) }

    func undo(_ id: UUID) {
        if host.undoMemory(id) {
            memoryBlock = ""
            session = nil
            return
        }
        host.undoAction(id)
    }

    private func replace(_ id: UUID, with item: ThreadItem) {
        if let i = items.firstIndex(where: { $0.id == id }) { items[i] = item }
    }
}

@available(iOS 26.0, *)
extension LiveChatService: ToolSurface {
    func surfaceAppend(_ item: ThreadItem) { items.appendAboveReply(item, reply: activeReplyID) }
    func surfaceReplace(_ id: UUID, with item: ThreadItem) { replace(id, with: item) }
    func surfaceRemove(_ id: UUID) { items.removeAll { $0.id == id } }
}
