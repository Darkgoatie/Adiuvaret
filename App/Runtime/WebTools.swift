import Foundation
import FoundationModels
import AdiuvaretCore
import PolicyEngine
import ToolKit

// MARK: executors (run after the policy gate has allowed or the user has approved)

struct OpenWebsiteExecutor: ToolExecutor {
    func execute(_ call: ToolCall) async throws -> String {
        let a = CalendarStore.args(call)
        guard let chat = (a["chat"] as? String).flatMap(UUID.init(uuidString:)) else { return "Not done: no chat." }
        switch WebPolicy.normalize((a["url"] as? String) ?? "") {
        case .rejected(let why): return "Not done: \(why)"
        case .allowed(let url): return await WebSession.shared.open(url, chat: chat, callID: call.id)
        }
    }
}

struct LookAtPageExecutor: ToolExecutor {
    func execute(_ call: ToolCall) async throws -> String {
        let a = CalendarStore.args(call)
        guard let chat = (a["chat"] as? String).flatMap(UUID.init(uuidString:)) else { return "Not done: no chat." }
        return await WebSession.shared.look(controls: !((a["readText"] as? Bool) ?? false), part: (a["part"] as? Int) ?? 1, chat: chat, callID: call.id)
    }
}

struct ActOnPageExecutor: ToolExecutor {
    func execute(_ call: ToolCall) async throws -> String {
        let a = CalendarStore.args(call)
        guard let chat = (a["chat"] as? String).flatMap(UUID.init(uuidString:)) else { return "Not done: no chat." }
        guard let action = Self.action(a["action"] as? String) else { return "Not done: unknown action." }
        return await WebSession.shared.act(action, element: (a["element"] as? Int) ?? 0, value: (a["value"] as? String) ?? "", chat: chat, callID: call.id)
    }

    static func action(_ name: String?) -> WebAction? {
        switch name {
        case "click": .click
        case "type": .type
        case "typeAndEnter": .typeAndEnter
        case "choose": .choose
        case "check": .check
        case "uncheck": .uncheck
        case "setSlider": .setSlider
        case "scrollDown": .scrollDown
        case "scrollUp": .scrollUp
        case "scrollTop": .scrollTop
        case "scrollBottom": .scrollBottom
        default: nil
        }
    }
}

// MARK: shared run helper

/// Runs one web step through the policy gate and keeps the chat row in step with it.
private func runWebStep(_ gate: PolicyGate, _ ctx: TaskContext, _ reporter: any ToolReporter,
                        name: String, json: [String: Any], title: String, rowID: UUID, typed: String = "") async -> String {
    await reporter.toolStarted(rowID, title: title)
    var payload = json
    payload["chat"] = ctx.chatID.uuidString
    let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    let outcome = await gate.run(ToolCall(id: rowID, toolName: name, argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext())
    switch outcome {
    case .executed(let out):
        ctx.markUntrusted()
        let summary = await WebSession.shared.takeSummary(rowID)
        var details = summary.details
        if !typed.isEmpty, !summary.failed { details.insert("“\(String(typed.prefix(60)))”", at: 0) }
        await reporter.toolFinished(rowID, title: summary.title, details: details, failed: summary.failed)
        return out
    case .blocked(let reason):
        let (shown, told) = Self_.text(reason)
        await reporter.toolFinished(rowID, title: shown, details: [], failed: true)
        return told
    case .failed(let message):
        await reporter.toolFinished(rowID, title: String(localized: "The browser step failed"), details: [], failed: true)
        return "Failed: \(message)"
    }
}

private enum Self_ {
    static func text(_ reason: DenyReason) -> (String, String) {
        switch reason {
        case .userDenied: (String(localized: "You declined"), "Not done: the user declined. Do not retry. Ask what they want instead.")
        case .killSwitch: (String(localized: "Actions are switched off"), "Not done: actions are switched off by the user.")
        case .rateLimited: (String(localized: "Too many steps for one request"), "Not done: too many steps in one request. Tell the user what you did so far and stop.")
        case .unknownTool, .scheduledRunWrite: (String(localized: "Not allowed"), "Not done: this is not allowed.")
        }
    }
}

// MARK: tools the model sees

struct LiveOpenWebsiteTool: Tool {
    let name = "openWebsite"
    let description = "Opens a website in the in-app browser. To search the web, open https://duckduckgo.com/?q= followed by the words joined with +."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    @Generable
    struct Arguments {
        @Guide(description: "Web address or domain, for example apple.com or https://example.com/page. https only.")
        var url: String
    }

    func call(arguments a: Arguments) async throws -> String {
        let rowID = UUID()
        switch WebPolicy.normalize(a.url) {
        case .rejected(let why):
            await reporter.toolStarted(rowID, title: String(localized: "Opening a website…"))
            await reporter.toolFinished(rowID, title: String(localized: "Couldn't open that address"), details: [], failed: true)
            return "Not done: \(why)"
        case .allowed(let url):
            let host = WebPolicy.host(of: url)
            // After reading anything untrusted, a site this chat has not visited needs the user's approval.
            let known = await WebSession.shared.isAllowedHost(host, chat: ctx.chatID)
            let tool = (ctx.callContext().contextContainsUntrusted && !known) ? "openOtherSite" : "openWebsite"
            return await runWebStep(gate, ctx, reporter, name: tool, json: ["url": url.absoluteString],
                                    title: String(localized: "Opening \(host)…"), rowID: rowID)
        }
    }
}

struct LiveLookAtPageTool: Tool {
    let name = "lookAtPage"
    let description = "Looks at the open website. Lists the numbered buttons, links and fields in view, or reads the page text."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    @Generable
    struct Arguments {
        @Guide(description: "False lists the numbered buttons, links and fields in view. True reads the page text instead.")
        var readText: Bool
        @Guide(description: "Which part of the text to read, starting at 1. Only used when readText is true.")
        var part: Int
    }

    func call(arguments a: Arguments) async throws -> String {
        await runWebStep(gate, ctx, reporter, name: "lookAtPage", json: ["readText": a.readText, "part": a.part],
                         title: String(localized: "Looking at the page…"), rowID: UUID())
    }
}

struct LiveActOnPageTool: Tool {
    let name = "actOnPage"
    let description = "Clicks, types, chooses or scrolls on the open website. Use element numbers from lookAtPage. Never fills passwords, card numbers or codes."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    @Generable
    enum PageAction: String, CaseIterable {
        case click, type, typeAndEnter, choose, check, uncheck, setSlider, scrollDown, scrollUp, scrollTop, scrollBottom
    }

    @Generable
    struct Arguments {
        @Guide(description: "Element number from lookAtPage. Use 0 for scrolling.")
        var element: Int
        var action: PageAction
        @Guide(description: "Text to type, option to choose, or slider number. Empty for click, check, uncheck and scroll.")
        var value: String
    }

    func call(arguments a: Arguments) async throws -> String {
        let scrolling = [PageAction.scrollDown, .scrollUp, .scrollTop, .scrollBottom].contains(a.action)
        var risky = false
        if !scrolling {
            guard let e = await WebSession.shared.element(a.element) else {
                let rowID = UUID()
                await reporter.toolStarted(rowID, title: String(localized: "Using the page…"))
                await reporter.toolFinished(rowID, title: String(localized: "That item isn't on the page"), details: [], failed: true)
                return "Not done: element \(a.element) was not in the last list. Call lookAtPage again and use a number from it."
            }
            let onLoginPage = await WebSession.shared.pageHasPassword
            switch a.action {
            case .click: risky = WebPolicy.clickNeedsApproval(label: e.label) || (onLoginPage && e.type == "submit")
            case .typeAndEnter: risky = onLoginPage
            default: break
            }
        }
        let typed = (a.action == .type || a.action == .typeAndEnter) ? a.value : ""
        return await runWebStep(gate, ctx, reporter, name: risky ? "actOnPageRisky" : "actOnPage",
                                json: ["element": a.element, "action": a.action.rawValue, "value": a.value],
                                title: String(localized: "Using the page…"), rowID: UUID(), typed: typed)
    }
}
