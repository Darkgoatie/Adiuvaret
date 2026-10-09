import Foundation
import FoundationModels
import AdiuvaretCore
import PolicyEngine
import ToolKit
import Diagnostics

// MARK: executors (run after the policy gate has allowed or the user has approved)

struct SearchWebExecutor: ToolExecutor {
    /// Live forecast for a place, or nil when the place or the service fails, so the normal search can still answer.
    static func weather(for name: String) async -> String? {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.httpCookieStorage = nil
        config.urlCache = nil
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        do {
            guard let geoURL = Weather.geocodingURL(name) else { return nil }
            let (geoData, geoResponse) = try await session.data(from: geoURL)
            guard (geoResponse as? HTTPURLResponse)?.statusCode == 200, let place = Weather.parsePlace(geoData) else {
                DiagnosticsLog.shared.record("weather", "place not found")
                return nil
            }
            let fahrenheit = Locale.current.measurementSystem == .us
            guard let url = Weather.forecastURL(place, fahrenheit: fahrenheit) else { return nil }
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200, let text = Weather.render(data, place: place) else {
                DiagnosticsLog.shared.record("weather", "forecast unavailable")
                return nil
            }
            DiagnosticsLog.shared.record("weather", "ok")
            return text
        } catch {
            DiagnosticsLog.shared.record("weather", "failed: \(String(String(describing: error).prefix(80)))")
            return nil
        }
    }

    func execute(_ call: ToolCall) async throws -> String {
        let query = WebSearch.cleanQuery((CalendarStore.args(call)["query"] as? String) ?? "")
        guard let url = WebSearch.url(for: query) else { return "Not done: no search words were given." }
        if let name = Weather.place(in: query), let report = await Self.weather(for: name) { return report }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(WebSearch.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue(Locale.preferredLanguages.first ?? "en", forHTTPHeaderField: "Accept-Language")
        // No cookies and no cache: the search is not tied to anything else the browser holds.
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.httpCookieStorage = nil
        config.urlCache = nil
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return "Not done: the search service did not answer. Tell the user." }
            guard http.statusCode == 200 else {
                DiagnosticsLog.shared.record("web search", "status \(http.statusCode)")
                return "Not done: the search service answered \(http.statusCode). Tell the user the search is not available right now."
            }
            guard data.count < 800_000, let html = String(data: data, encoding: .utf8) else { return "Not done: the search answer could not be read." }
            let results = WebSearch.parse(html: html)
            DiagnosticsLog.shared.record("web search", "\(results.count) results")
            if results.isEmpty, html.contains("anomaly") || html.contains("bots use DuckDuckGo") {
                return "Not done: the search service is blocking requests right now. Tell the user."
            }
            return WebSearch.render(results, query: query)
        } catch {
            DiagnosticsLog.shared.record("web search", "failed: \(String(String(describing: error).prefix(80)))")
            return "Not done: could not reach the search service. Tell the user they may be offline."
        }
    }
}

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
        ctx.markUntrusted(personal: false)
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

struct LiveSearchWebTool: Tool {
    let name = "searchWeb"
    let description = "Searches the web and returns result titles, sites and short summaries. Use it first for news, scores, weather, prices, schedules and anything that may have changed. Never tell the user to search themselves."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    @Generable
    struct Arguments {
        @Guide(description: "Three to eight plain search words, for example: Real Betis next match")
        var query: String
    }

    func call(arguments a: Arguments) async throws -> String {
        let rowID = UUID()
        let query = WebSearch.cleanQuery(a.query)
        await reporter.toolStarted(rowID, title: String(localized: "Searching the web…"))
        guard !query.isEmpty else {
            await reporter.toolFinished(rowID, title: String(localized: "No search words"), details: [], failed: true)
            return "Not done: no search words were given."
        }
        let tool = ctx.sawPersonalData() ? "searchWebAfterPersonal" : "searchWeb"
        let data = (try? JSONSerialization.data(withJSONObject: ["query": query])) ?? Data()
        let outcome = await gate.run(ToolCall(id: rowID, toolName: tool, argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext())
        switch outcome {
        case .executed(let out):
            ctx.markUntrusted(personal: false)
            let items = out.split(separator: "\n").map(String.init)
                .filter { $0.first?.isNumber == true && $0.contains(". ") }
                .map { String($0.drop(while: { $0.isNumber || $0 == "." || $0 == " " })) }
            let failed = out.hasPrefix("Not done")
            let title = failed ? String(localized: "Couldn't search the web")
                : items.isEmpty ? String(localized: "Searched the web · nothing found") : String(localized: "Searched the web · \(items.count) results")
            await reporter.toolFinished(rowID, title: title, details: ["“\(query)”"] + items, failed: failed)
            return out
        case .blocked(let reason):
            let (shown, told) = Self_.text(reason)
            await reporter.toolFinished(rowID, title: shown, details: [], failed: true)
            return told
        case .failed(let message):
            await reporter.toolFinished(rowID, title: String(localized: "Couldn't search the web"), details: [], failed: true)
            return "Failed: \(message)"
        }
    }
}

struct LiveOpenWebsiteTool: Tool {
    let name = "openWebsite"
    let description = "Opens a website the user named, or a search result, in the in-app browser. Returns the numbered buttons, links and fields on the page."
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
