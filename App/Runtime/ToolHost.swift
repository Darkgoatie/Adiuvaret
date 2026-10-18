import Foundation
import DesignSystem
import AdiuvaretCore
import PolicyEngine
import ToolKit
import Diagnostics
import SkillKit

/// What a chat shows the tool host needs: read the thread and change it.
@MainActor
protocol ToolSurface: AnyObject {
    var items: [ThreadItem] { get }
    func surfaceAppend(_ item: ThreadItem)
    func surfaceReplace(_ id: UUID, with item: ThreadItem)
    func surfaceRemove(_ id: UUID)
}

/// The tools, their approvals, Undo and the skill offer, shared by the on-device chat and the online-model chat.
/// A chat owns one host and gives it its thread to show tool rows and approval cards in.
@MainActor
final class ToolHost {
    let ctx = TaskContext()
    let handles = EventHandles()
    private let engine = LiveEngine.shared
    private weak var surface: (any ToolSurface)?
    private var pending: [UUID: CheckedContinuation<ApprovalResponse, Never>] = [:]
    private var undos: [UUID: UndoAction] = [:]
    private var memoryUndos: [UUID: UUID] = [:]
    private var skillOffers: [UUID: SkillHub.Offer] = [:]
    private var built: [String: any AppTool]?

    func attach(_ surface: any ToolSurface) { self.surface = surface }

    // MARK: tools

    /// Every tool the app has, built once for this chat. The model chooses from the ones it is given.
    private func allTools() -> [String: any AppTool] {
        if let built { return built }
        let bridge = Bridge(host: self)
        let handles = self.handles
        let ctx = self.ctx
        var rawExecutors: [String: any ToolExecutor] = ["readCalendar": LiveCalendarExecutor(handles: handles),
                                         "findFreeTime": FreeTimeExecutor(),
                                         "callAPI": CallAPIExecutor(), "callAPIWrite": CallAPIExecutor(), "approveAPIHost": ApproveAPIHostExecutor(),
                                         "saveSkill": SaveSkillExecutor(reporter: bridge), "runScript": RunScriptExecutor(),
                                         "runShell": RunShellExecutor(), "runShellWrite": RunShellExecutor(), "runShellNetwork": RunShellExecutor(), "runShellDelete": RunShellExecutor(),
                                         "createEvent": CreateEventExecutor(reporter: bridge),
                                         "moveEvent": MoveEventExecutor(reporter: bridge, handles: handles),
                                         "deleteEvent": DeleteEventExecutor(reporter: bridge, handles: handles),
                                         "createReminder": LiveReminderExecutor(reporter: bridge),
                                         "listReminders": ListRemindersExecutor(),
                                         "searchWeb": SearchWebExecutor(),
                                         "openWebsite": OpenWebsiteExecutor(), "openOtherSite": OpenWebsiteExecutor(),
                                         "lookAtPage": LookAtPageExecutor(),
                                         "actOnPage": ActOnPageExecutor(), "actOnPageRisky": ActOnPageExecutor(),
                                         "searchNotes": SearchNotesExecutor(), "readNote": ReadNoteExecutor(), "writeNote": WriteNoteExecutor(reporter: bridge),
                                         "saveItem": SaveItemExecutor(reporter: bridge), "findSavedItems": FindSavedItemsExecutor(),
                                         "findContact": FindContactExecutor(), "runShortcut": RunShortcutExecutor(reporter: bridge),
                                         "draftEmail": DraftEmailExecutor(reporter: bridge),
                                         "listGitHubIssues": ListGitHubExecutor(), "listGitHubRepos": ListGitHubReposExecutor(), "listGitHubCommits": ListGitHubCommitsExecutor(), "searchNotion": SearchNotionExecutor(), "searchPastChats": SearchPastChatsExecutor(), "skill_use": SkillUseExecutor()]
        rawExecutors.merge(ManifestExecutors.make(reporter: bridge)) { a, _ in a }
        let gate = PolicyGate(engine: engine, approvals: bridge, executors: rawExecutors.mapValues { RecordingExecutor(inner: $0, ctx: ctx) as any ToolExecutor },
                              observer: { call, outcome, asked, ms in ActivityStore.shared.record(ActivityEntry.make(call, outcome, asked: asked, milliseconds: ms)) })
        var all: [String: any AppTool] = [
            "readCalendar": LiveReadCalendarTool(gate: gate, ctx: ctx, reporter: bridge),
            "findFreeTime": LiveFreeTimeTool(gate: gate, ctx: ctx),
            "createEvent": LiveCreateEventTool(gate: gate, ctx: ctx),
            "moveEvent": LiveMoveEventTool(gate: gate, ctx: ctx),
            "deleteEvent": LiveDeleteEventTool(gate: gate, ctx: ctx),
            "createReminder": LiveCreateReminderTool(gate: gate, ctx: ctx, reporter: bridge),
            "listReminders": LiveListRemindersTool(gate: gate, ctx: ctx, reporter: bridge),
            "searchWeb": LiveSearchWebTool(gate: gate, ctx: ctx, reporter: bridge),
            "openWebsite": LiveOpenWebsiteTool(gate: gate, ctx: ctx, reporter: bridge),
            "lookAtPage": LiveLookAtPageTool(gate: gate, ctx: ctx, reporter: bridge),
            "actOnPage": LiveActOnPageTool(gate: gate, ctx: ctx, reporter: bridge),
            "searchNotes": LiveSearchNotesTool(gate: gate, ctx: ctx, reporter: bridge),
            "readNote": LiveReadNoteTool(gate: gate, ctx: ctx, reporter: bridge),
            "writeNote": LiveWriteNoteTool(gate: gate, ctx: ctx),
            "saveItem": LiveSaveItemTool(gate: gate, ctx: ctx),
            "findSavedItems": LiveFindSavedItemsTool(gate: gate, ctx: ctx, reporter: bridge),
            "findContact": LiveFindContactTool(gate: gate, ctx: ctx, reporter: bridge),
            "runShortcut": LiveRunShortcutTool(gate: gate, ctx: ctx),
            "draftEmail": LiveDraftEmailTool(gate: gate, ctx: ctx),
            "listGitHubIssues": LiveListGitHubTool(gate: gate, ctx: ctx, reporter: bridge),
            "listGitHubRepos": LiveListGitHubReposTool(gate: gate, ctx: ctx, reporter: bridge),
            "listGitHubCommits": LiveListGitHubCommitsTool(gate: gate, ctx: ctx, reporter: bridge),
            "searchNotion": LiveSearchNotionTool(gate: gate, ctx: ctx, reporter: bridge),
            "searchPastChats": LiveSearchPastChatsTool(gate: gate, ctx: ctx, reporter: bridge),
            "callAPI": LiveCallAPITool(gate: gate, ctx: ctx, reporter: bridge),
            "saveSkill": LiveSaveSkillTool(gate: gate, ctx: ctx, reporter: bridge),
            "runScript": LiveRunScriptTool(gate: gate, ctx: ctx, reporter: bridge),
            "runShell": LiveRunShellTool(gate: gate, ctx: ctx, reporter: bridge),
            "skill_use": LiveSkillUseTool(gate: gate, ctx: ctx, reporter: bridge)]
        all.merge(makeConnectorTools(gate: gate, ctx: ctx, reporter: bridge)) { a, _ in a }
        built = all
        return all
    }

    func tools(for ids: [String]) -> [any AppTool] {
        let all = allTools()
        return ids.compactMap { all[$0] }
    }

    /// Ids of every tool that exists and is switched on right now.
    func visibleToolIDs() -> [String] {
        let known = Set(allTools().keys)
        return ConnectorCatalog.visible(.standard).entries.map(\.id).filter(known.contains)
    }

    // MARK: approvals, rows, Undo

    func askApproval(for call: ToolCall, tool: ToolDescriptor) async -> ApprovalResponse {
        let args = CalendarStore.args(call)
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        func when(_ key: String) -> String { CalendarMath.dateTime((args[key] as? String) ?? "").map { f.string(from: $0) } ?? ((args[key] as? String) ?? "") }
        if let owner = ConnectorRegistry.owner(ofTool: call.toolName), owner.tool.isWrite {
            let raw = ManifestExecutor.strings(args)
            let rows = ConnectorEngine.approvalRows(owner.manifest, owner.tool, raw).map { DetailRow($0.label, String($0.value.prefix(300))) }
            return await present(title: owner.tool.approvalTitle ?? "Allow this?", rows: rows)
        }
        let title: String; var rows: [DetailRow]
        switch call.toolName {
        case "createEvent":
            title = String(localized: "Add this event?")
            let mins = (args["durationMinutes"] as? Int) ?? 60
            rows = [DetailRow(String(localized: "Title"), (args["title"] as? String) ?? ""), DetailRow(String(localized: "Starts"), when("start")),
                    DetailRow(String(localized: "Length"), String(localized: "\(mins) minutes")),
                    DetailRow(String(localized: "Calendar"), CalendarChoice.targetName())]
        case "moveEvent":
            title = String(localized: "Move this event?")
            rows = [DetailRow(String(localized: "Event"), eventName(args["event"])), DetailRow(String(localized: "New start"), when("newStart"))]
        case "deleteEvent":
            title = String(localized: "Delete this event?")
            rows = [DetailRow(String(localized: "Event"), eventName(args["event"])), DetailRow(String(localized: "Note"), String(localized: "This can't be undone."))]
        case "saveSkill":
            title = String(localized: "Save this as a skill?")
            let skill = SaveSkillExecutor.skill(from: ManifestExecutor.strings(args))
            rows = [DetailRow(String(localized: "Name"), skill.name),
                    DetailRow(String(localized: "What it does"), skill.description),
                    DetailRow(String(localized: "Hosts"), skill.hosts.isEmpty ? String(localized: "None") : skill.hosts.joined(separator: ", ")),
                    DetailRow(String(localized: "Tools"), skill.tools.isEmpty ? String(localized: "None") : skill.tools.joined(separator: ", ")),
                    DetailRow(String(localized: "Instructions"), String(skill.instructions.prefix(500))),
                    DetailRow(String(localized: "Note"), String(localized: "Tokens are not stored in a skill. Delete it any time in Advanced, Skills."))]
        case "runShellWrite", "runShellNetwork", "runShellDelete":
            let line = (args["command"] as? String) ?? ""
            let plan = ShellPolicy.plan(line, workspace: ShellRunner.workspacePath)
            title = String(localized: String.LocalizationValue(ShellCommandBuilder.cardTitle(for: plan.cls)))
            rows = ShellCommandBuilder.cardRows(command: line, plan: plan).map { DetailRow(String(localized: String.LocalizationValue($0.label)), $0.value) }
        case "approveAPIHost":
            title = String(localized: "Allow calls to this host?")
            rows = [DetailRow(String(localized: "Host"), (args["host"] as? String) ?? ""),
                    DetailRow(String(localized: "Note"), String(localized: "Reading from it then runs without asking. Sending or changing data still asks every time. Add a token in Advanced, API access."))]
        case "callAPIWrite":
            title = String(localized: "Send this to the service?")
            rows = [DetailRow(String(localized: "Host"), (args["host"] as? String) ?? ""),
                    DetailRow(String(localized: "Request"), ((args["method"] as? String) ?? "") + " " + String(((args["path"] as? String) ?? "").prefix(120))),
                    DetailRow(String(localized: "Data"), String((((args["body"] as? String) ?? "").isEmpty ? ((args["query"] as? String) ?? "") : ((args["body"] as? String) ?? "")).prefix(300))),
                    DetailRow(String(localized: "Note"), String(localized: "This may not be undoable."))]
        case "openOtherSite":
            title = String(localized: "Open another website?")
            rows = [DetailRow(String(localized: "Site"), WebPolicy.normalize((args["url"] as? String) ?? "").hostText),
                    DetailRow(String(localized: "Why I'm asking"), String(localized: "You asked to confirm new sites."))]
        case "writeNote":
            let target = (args["appendTo"] as? String) ?? ""
            title = target.isEmpty ? String(localized: "Save this note?") : String(localized: "Add to this note?")
            rows = [DetailRow(String(localized: "Note"), target.isEmpty ? ((args["title"] as? String) ?? "") : NoteName.title(of: target)),
                    DetailRow(String(localized: "Text"), String(((args["text"] as? String) ?? "").prefix(200))),
                    DetailRow(String(localized: "Where"), String(localized: "Your notes folder"))]
        case "saveItem":
            let isTask = SavedItemRules.kind(from: (args["kind"] as? String) ?? "") == .task
            title = isTask ? String(localized: "Keep this task?") : String(localized: "Keep this note?")
            let kept = SavedItemRules.clean(title: (args["title"] as? String) ?? "", text: (args["text"] as? String) ?? "")
            rows = [DetailRow(String(localized: "Title"), kept?.title ?? ""),
                    DetailRow(String(localized: "Text"), String((kept?.text ?? "").prefix(200))),
                    DetailRow(String(localized: "Where"), String(localized: "Notes and Tasks in this app"))]
        case "runShortcut":
            title = String(localized: "Run this shortcut?")
            rows = [DetailRow(String(localized: "Shortcut"), (args["name"] as? String) ?? ""),
                    DetailRow(String(localized: "Note"), String(localized: "What it does depends on the shortcut. I can't see the result."))]
        case "draftEmail":
            title = String(localized: "Open a draft in Mail?")
            rows = [DetailRow(String(localized: "To"), ((args["to"] as? String) ?? "").isEmpty ? String(localized: "Not set") : (args["to"] as? String) ?? ""),
                    DetailRow(String(localized: "Subject"), (args["subject"] as? String) ?? ""),
                    DetailRow(String(localized: "Text"), String(((args["body"] as? String) ?? "").prefix(200))),
                    DetailRow(String(localized: "Note"), String(localized: "Nothing is sent until you press send in Mail."))]
        case "actOnPageRisky":
            title = String(localized: "Do this on the page?")
            let element = WebSession.shared.element((args["element"] as? Int) ?? 0)
            let value = (args["value"] as? String) ?? ""
            rows = [DetailRow(String(localized: "Page"), WebSession.shared.host),
                    DetailRow(String(localized: "Action"), ((args["action"] as? String) ?? "click") + " " + (element.map { "“\($0.label)”" } ?? "")),
                    DetailRow(String(localized: "Note"), String(localized: "This can send, buy or sign in and may not be undoable."))]
            if !value.isEmpty { rows.insert(DetailRow(String(localized: "Typing"), String(value.prefix(60))), at: 2) }
        default:
            let minutes = (args["dueInMinutes"] as? Int) ?? 60
            title = String(localized: "Create this reminder?")
            rows = [DetailRow(String(localized: "Title"), (args["title"] as? String) ?? ""),
                    DetailRow(String(localized: "Due"), f.string(from: Date().addingTimeInterval(Double(minutes) * 60))),
                    DetailRow(String(localized: "List"), String(localized: "Reminders"))]
        }
        return await present(title: title, rows: rows)
    }

    private func present(title: String, rows: [DetailRow]) async -> ApprovalResponse {
        let id = UUID()
        surface?.surfaceAppend(.approval(id: id, phase: .pending, title: title, rows: rows))
        return await withCheckedContinuation { pending[id] = $0 }
    }
    private func eventName(_ handle: Any?) -> String {
        let h = (handle as? String) ?? ""
        for case .tool(_, _, _, let details) in (surface?.items ?? []).reversed() {
            if let line = details.first(where: { $0.hasPrefix(h + " ") }) { return String(line.dropFirst(h.count + 1)) }
        }
        return h
    }

    fileprivate func started(_ id: UUID, _ title: String) { surface?.surfaceAppend(.tool(id: id, phase: .running, title: title, details: [])) }

    fileprivate func finished(_ id: UUID, _ title: String, _ details: [String], _ failed: Bool) {
        surface?.surfaceReplace(id, with: .tool(id: id, phase: failed ? .failed : .finished, title: title, details: details))
    }

    fileprivate func actionDone(_ title: String, _ detail: String, _ undo: UndoAction?) {
        let id = UUID()
        if let undo { undos[id] = undo }
        let open: String? = { if case .removeReminder? = undo { return String(localized: "Open in Reminders") } else { return nil } }()
        surface?.surfaceAppend(.action(id: id, phase: undo == nil ? .undoExpired : .done, title: title, detail: detail, open: open))
    }

    /// Answers a pending approval or a skill offer. False when the id is neither.
    func approve(_ id: UUID) -> Bool {
        if let offer = skillOffers.removeValue(forKey: id) {
            let saved = SkillHub.save(offer)
            setOffer(id, saved ? .saved : .dismissed, offer.title)
            return true
        }
        return resolve(id, .approved)
    }

    func deny(_ id: UUID) -> Bool {
        if let offer = skillOffers.removeValue(forKey: id) { setOffer(id, .dismissed, offer.title); return true }
        return resolve(id, .denied)
    }

    /// Denies everything still waiting, when the user stops the reply.
    func stop() {
        for (id, cont) in pending { cont.resume(returning: .denied); markApproval(id, .denied) }
        pending.removeAll()
    }

    private func resolve(_ id: UUID, _ r: ApprovalResponse) -> Bool {
        guard let cont = pending.removeValue(forKey: id) else { return false }
        markApproval(id, r == .approved ? .approved : .denied)
        cont.resume(returning: r)
        return true
    }

    private func markApproval(_ id: UUID, _ phase: ApprovalCard.Phase) {
        guard let i = surface?.items.firstIndex(where: { $0.id == id }), case .approval(_, _, let t, let rows)? = surface?.items[i] else { return }
        surface?.surfaceReplace(id, with: .approval(id: id, phase: phase, title: t, rows: rows))
    }

    private func setOffer(_ id: UUID, _ phase: SkillOfferCard.Phase, _ title: String) {
        surface?.surfaceReplace(id, with: .skillOffer(id: id, phase: phase, title: title))
    }

    /// After a task that used two or more different tools, asks whether to keep the steps. Nothing is saved until the user taps Save.
    func offerSkill(for prompt: String) {
        guard let offer = SkillHub.offer(message: prompt, tools: ctx.toolsRan()) else { return }
        let id = UUID()
        skillOffers[id] = offer
        surface?.surfaceAppend(.skillOffer(id: id, phase: .offered, title: offer.title))
    }

    /// Saves a fact the user stated and shows the Undo chip. The thread gets an error row when memory is full.
    func learn(from text: String) {
        switch MemoryHub.learn(from: text) {
        case .saved(let fact):
            let id = UUID()
            memoryUndos[id] = fact.id
            surface?.surfaceAppend(.memory(id: id, text: fact.text))
        case .full:
            surface?.surfaceAppend(.error(id: UUID(), text: String(localized: "My memory is full. Open What I know about you in Advanced and delete something so I can remember new things.")))
        case .none: break
        }
    }

    /// True when the id was a saved fact and it was removed; the chat then rebuilds its instructions.
    func undoMemory(_ id: UUID) -> Bool {
        guard let factID = memoryUndos[id] else { return false }
        MemoryHub.store.remove(factID)
        memoryUndos[id] = nil
        surface?.surfaceRemove(id)
        return true
    }

    func undoAction(_ id: UUID) {
        guard let action = undos[id], let i = surface?.items.firstIndex(where: { $0.id == id }),
              case .action(_, .done, let t, let d, _)? = surface?.items[i] else { return }
        Task {
            let ok = await EventUndo.run(action)
            await MainActor.run {
                surface?.surfaceReplace(id, with: .action(id: id, phase: ok ? .undone : .undoExpired, title: t, detail: d, open: nil))
            }
        }
    }

    private struct Bridge: ApprovalPresenter, ToolReporter {
        let host: ToolHost

        func requestApproval(for call: ToolCall, tool: ToolDescriptor, reason: ApprovalReason) async -> ApprovalResponse {
            await host.askApproval(for: call, tool: tool)
        }
        func toolStarted(_ id: UUID, title: String) async { await host.started(id, title) }
        func toolFinished(_ id: UUID, title: String, details: [String], failed: Bool) async { await host.finished(id, title, details, failed) }
        func actionDone(title: String, detail: String, undo: UndoAction?) async { await host.actionDone(title, detail, undo) }
    }
}
