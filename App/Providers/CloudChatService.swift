import Foundation
import Observation
import ModelLibrary
import ToolKit
import SkillKit
import AdiuvaretCore
import PolicyEngine
import Diagnostics

/// Chat with an online model through the user's own API key. The model has the same tools, memory and skills as the on-device one.
/// What a tool returns is sent to the provider the user picked, so the Providers screen says so.
@MainActor @Observable
final class CloudChatService: ChatService, FixedToolsChat {
    private(set) var items: [ThreadItem]
    private(set) var isGenerating = false
    private(set) var banner: ChatBanner?
    private(set) var title = String(localized: "New chat")
    let modelID: String

    @ObservationIgnored private let host = ToolHost()
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var lastPrompt = ""
    @ObservationIgnored private var memoryBlock = ""
    /// The reply being written, so action rows that arrive meanwhile are placed above it.
    @ObservationIgnored private var activeReplyID: UUID?
    /// Models that refused tool definitions, remembered for this chat so every turn does not pay for a failed request.
    @ObservationIgnored private var toolsRefused = false
    /// When set, the chat uses exactly these tools and skips the router. Briefings use it so only reading tools exist.
    @ObservationIgnored var fixedTools: [String]?
    /// Most steps one reply may take: model turns that ask for tools, then the final answer.
    private static let maxRounds = 8

    private var parsed: (provider: Provider, model: String)? { Providers.parseModelID(modelID) }
    var modelName: String { parsed.map { "\($0.model) · \($0.provider.name)" } ?? modelID }
    var providerName: String { parsed?.provider.name ?? "" }

    init(restoring items: [ThreadItem] = [], title: String? = nil, modelID: String) {
        self.items = items
        self.modelID = modelID
        if let title { self.title = title }
        host.attach(self)
    }

    func setTitle(_ t: String) {
        let c = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if !c.isEmpty { title = String(c.prefix(60)) }
    }

    func send(_ text: String, attachments: [ChatFile]) async {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, !attachments.isEmpty { trimmed = String(localized: "Please read the attached file and tell me what it says.") }
        guard !isGenerating, !trimmed.isEmpty else { return }
        if !attachments.isEmpty { items.append(.userFiles(id: UUID(), files: attachments)) }
        items.append(.user(id: UUID(), text: trimmed))
        host.learn(from: trimmed)
        if title == String(localized: "New chat") { title = String(trimmed.prefix(40)) }
        lastPrompt = trimmed
        await run(trimmed)
    }

    func retry() async {
        guard !isGenerating, !lastPrompt.isEmpty else { return }
        if case .error? = items.last { items.removeLast() }
        await run(lastPrompt)
    }

    func stop() {
        task?.cancel()
        host.stop()
    }

    func approve(_ id: UUID) { _ = host.approve(id) }
    func deny(_ id: UUID) { _ = host.deny(id) }

    func undo(_ id: UUID) {
        if host.undoMemory(id) { memoryBlock = ""; return }
        host.undoAction(id)
    }

    func deleteMessage(_ id: UUID) {
        let roles = items.map(\.editingRole)
        guard let i = items.firstIndex(where: { $0.id == id }), ThreadEditing.canDelete(roles, at: i, generating: isGenerating) else { return }
        items.removeMessage(at: i)
    }

    func edit(_ id: UUID, text: String) async {
        let roles = items.map(\.editingRole)
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let i = items.firstIndex(where: { $0.id == id }), ThreadEditing.canEdit(roles, at: i, generating: isGenerating) else { return }
        let files = items.truncate(beforeUser: i)
        await send(t, attachments: files)
    }

    func regenerate(_ id: UUID) async {
        let roles = items.map(\.editingRole)
        guard let i = items.firstIndex(where: { $0.id == id }), ThreadEditing.canRegenerate(roles, at: i, generating: isGenerating),
              let point = ThreadEditing.regenerationPoint(roles, at: i), case .user(_, let prompt) = items[point.prompt] else { return }
        items.removeSubrange(point.keep...)
        lastPrompt = prompt
        await run(prompt)
    }

    // MARK: one reply

    private func run(_ prompt: String) async {
        isGenerating = true
        let replyID = UUID()
        activeReplyID = replyID
        let ctx = host.ctx
        ctx.beginTask(message: prompt)
        let work = Task { @MainActor in
            guard let (provider, model) = parsed, let key = ProviderStore.shared.key(for: provider.id), ProviderStore.shared.isConnected(provider.id) else {
                items.append(.error(id: UUID(), text: String(localized: "This provider isn't connected any more. Add its key in Settings, Providers, or pick another model from the menu at the top.")))
                return
            }
            let clock = ContinuousClock(); let start = clock.now
            let support = fileSupport
            let prepared = AttachmentStore.prepare(items.currentTurnFiles(), support: support)
            let withFiles = AttachmentText.compose(prompt: prompt, documents: prepared.documents, imageNames: prepared.skippedImageNames, limit: support.documentChars)
            ctx.notePrivate(prepared.documents.map(\.text).joined(separator: " "))

            // Memory, skills and the tools for this message: the same steps as the on-device chat.
            let skill = AppSettings.shared.actionsOff ? nil : SkillHub.match(for: prompt)
            if skill?.untrusted == true { ctx.markUntrusted(personal: false) }
            memoryBlock = [MemoryHub.block(for: prompt), SkillHub.block(from: skill)].filter { !$0.isEmpty }.joined(separator: "\n")
            ctx.notePrivate(memoryBlock)
            var prior = items
            if case .user? = prior.last { prior.removeLast() }
            let toolIDs = await chooseTools(prompt: prompt, prior: prior, skill: skill)
            var system = AssistantPrompt.instructions(ids: toolIDs, memory: memoryBlock.isEmpty ? "" : " " + memoryBlock, online: true)
            let wireTools = host.tools(for: toolIDs).map { ToolBridge.wireTool($0) }
            var useTools = !wireTools.isEmpty && !toolsRefused && !AppSettings.shared.actionsOff

            var history: [ProviderWire.Message] = []
            for (n, item) in prior.enumerated().suffix(24) {
                switch item {
                case .user(_, let t):
                    // Earlier files are sent again as text so the model can still refer to them; earlier pictures are not resent.
                    let old = AttachmentStore.prepare(prior.attachments(beforeUser: n).filter { $0.kind == .document }, support: support)
                    history.append(.init(isUser: true, text: AttachmentText.compose(prompt: t, documents: old.documents, limit: support.documentChars / 2)))
                case .assistant(_, let t, false): history.append(.init(isUser: false, text: t))
                default: break
                }
            }
            history.append(.init(isUser: true, text: withFiles, images: prepared.wireImages))

            var turns = ProviderWire.turns(from: history)
            var shown = ""; var started = false
            var firstAt: ContinuousClock.Instant?
            do {
                let plainSystem = AssistantPrompt.instructions(ids: [], memory: memoryBlock.isEmpty ? "" : " " + memoryBlock, online: true)
                if !useTools { system = plainSystem }
                var rounds = 0
                while true {
                    rounds += 1
                    var calls: [WireCall] = []
                    var roundText = ""
                    do {
                        for try await event in CloudClient.streamTurn(provider, model: model, key: key, system: system, turns: turns, tools: useTools ? wireTools : []) {
                            switch event {
                            case .text(let piece):
                                roundText += piece
                                shown += piece
                                if !started {
                                    started = true
                                    firstAt = clock.now
                                    DiagnosticsLog.shared.record("first token", "\((clock.now - start).milliseconds) ms, cloud=\(provider.id)")
                                    items.append(.assistant(id: replyID, text: shown, streaming: true))
                                } else {
                                    replace(replyID, shown, streaming: true)
                                }
                            case .calls(let c): calls = c
                            }
                        }
                    } catch let e as ProviderError where useTools && !started && (e.status == 400 || e.status == 404 || e.status == 422) {
                        // This model does not take tool definitions. Answer this message plainly and keep doing so in this chat.
                        toolsRefused = true
                        useTools = false
                        system = plainSystem
                        turns = ProviderWire.turns(from: history)
                        DiagnosticsLog.shared.record("cloud tools", "\(provider.id) refused tools (status \(e.status ?? 0)), plain chat")
                        continue
                    }
                    if calls.isEmpty || Task.isCancelled || rounds >= Self.maxRounds { break }
                    // Run every tool the model asked for, then give it the results and let it continue.
                    DiagnosticsLog.shared.record("cloud tools", "\(provider.id) round \(rounds): \(calls.map(\.name).joined(separator: ","))")
                    turns.append(.assistant(text: roundText, calls: calls))
                    var results: [WireTurn.ToolResult] = []
                    for call in calls {
                        let output = await runCall(call, allowed: toolIDs)
                        results.append(.init(callID: call.id, name: call.name, output: String(output.prefix(6000))))
                    }
                    turns.append(.toolResults(results))
                    if started { shown += "\n\n" }
                }
                if !started, !shown.isEmpty { started = true; items.append(.assistant(id: replyID, text: shown, streaming: true)) }
                if started {
                    replace(replyID, shown.trimmingCharacters(in: .whitespacesAndNewlines), streaming: false)
                    ReplyStats.shared.record(replyID, text: shown, since: firstAt)
                    DiagnosticsLog.shared.record("reply done", "\((clock.now - start).milliseconds) ms, cloud=\(provider.id)")
                } else if !Task.isCancelled {
                    items.append(.error(id: UUID(), text: String(localized: "\(provider.name) didn't write anything. Try asking again.")))
                }
                host.offerSkill(for: prompt)
            } catch {
                if started { replace(replyID, shown, streaming: false) }
                DiagnosticsLog.shared.record("cloud error", provider.id)
                items.append(.error(id: UUID(), text: (error as? ProviderError)?.message ?? String(localized: "Could not reach \(provider.name).")))
            }
        }
        task = work
        await work.value
        activeReplyID = nil
        isGenerating = false
    }

    /// Picks the tools for this message. An online model sees every visible tool the router and the code-side rules select,
    /// plus what a matched skill names, so a long catalog does not eat its context.
    private func chooseTools(prompt: String, prior: [ThreadItem], skill: SkillUse?) async -> [String] {
        guard !AppSettings.shared.actionsOff else { return [] }
        if let fixed = fixedTools {
            let visible = Set(host.visibleToolIDs())
            let ids = fixed.filter(visible.contains)
            DiagnosticsLog.shared.record("route", "cloud fixed tools=[\(ids.joined(separator: ","))]")
            return ids
        }
        let previous = prior.reversed().compactMap { item -> String? in if case .user(_, let t) = item { return t } else { return nil } }.first
        let routed = await ToolRouter.chooseWithNote(prompt: prompt, previous: previous)
        var chosen = routed.0
        if let skill {
            let wanted = skill.tools.compactMap { ToolCatalog.standard.entry($0) }
            chosen = ToolCatalog.standard.withRequirements(chosen + wanted, cap: 6)
        }
        let visible = Set(host.visibleToolIDs())
        let ids = chosen.map(\.id).filter(visible.contains)
        DiagnosticsLog.shared.record("route", "cloud tools=[\(ids.joined(separator: ","))] \(routed.1)")
        return ids
    }

    /// Runs one tool call from the model through the same tool objects and policy checks as the on-device chat.
    private func runCall(_ call: WireCall, allowed: [String]) async -> String {
        guard allowed.contains(call.name), let tool = host.tools(for: [call.name]).first else {
            return "Not done: there is no tool called \(call.name) available now."
        }
        return await ToolBridge.run(tool, argumentsJSON: call.argumentsJSON)
    }

    private func replace(_ id: UUID, _ text: String, streaming: Bool) {
        guard let i = items.firstIndex(where: { $0.id == id }), case .assistant = items[i] else { return }
        items[i] = .assistant(id: id, text: text, streaming: streaming)
    }
}

extension CloudChatService: ToolSurface {
    func surfaceAppend(_ item: ThreadItem) { items.appendAboveReply(item, reply: activeReplyID) }
    func surfaceReplace(_ id: UUID, with item: ThreadItem) {
        if let i = items.firstIndex(where: { $0.id == id }) { items[i] = item }
    }
    func surfaceRemove(_ id: UUID) { items.removeAll { $0.id == id } }
}
