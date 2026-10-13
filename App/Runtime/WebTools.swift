import Foundation
import AdiuvaretCore
import PolicyEngine
import ToolKit
import Diagnostics

// MARK: executors (run after the policy gate has allowed or the user has approved)

struct SearchWebExecutor: ToolExecutor {
    private static func quickSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.httpCookieStorage = nil
        config.urlCache = nil
        return URLSession(configuration: config)
    }

    private static func getData(_ url: URL, _ session: URLSession) async -> Data? {
        guard let result = try? await session.data(from: url), (result.1 as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return result.0
    }

    /// A full league table, or nil so the normal search can still answer.
    static func standings(_ request: Standings.Request) async -> String? {
        let session = quickSession()
        defer { session.finishTasksAndInvalidate() }
        guard let url = Standings.url(code: request.code), let data = await getData(url, session) else {
            DiagnosticsLog.shared.record("standings", "request failed")
            return nil
        }
        let text = Standings.render(data, name: request.name, wantsChart: request.wantsChart)
        DiagnosticsLog.shared.record("standings", text == nil ? "unreadable" : "ok")
        return text
    }

    /// An exchange rate or a football fixture straight from a data service, or nil so the normal search can still answer.
    static func direct(_ request: DirectSources.Request) async -> String? {
        let session = quickSession()
        defer { session.finishTasksAndInvalidate() }
        var text: String?
        switch request {
        case .currency(let amount, let from, let to):
            if let url = DirectSources.currencyURL(amount: amount, from: from, to: to), let data = await getData(url, session) {
                text = DirectSources.renderCurrency(data, amount: amount, from: from, to: to)
            }
        case .competition(let id, let name, let kind):
            if kind == .next, let espn = await InfoFetcher.footballNext(title: name) { return espn }
            let urls = DirectSources.competitionDayURLs(id: id, kind: kind)
            let days = await withTaskGroup(of: (Int, Data?).self) { group -> [Data] in
                for (i, url) in urls.enumerated() { group.addTask { (i, await Self.getData(url, session)) } }
                var found: [(Int, Data)] = []
                for await (i, data) in group { if let data { found.append((i, data)) } }
                return found.sorted { $0.0 < $1.0 }.map(\.1)
            }
            text = DirectSources.renderCompetition(days: days, name: name, kind: kind)
        case .team(let name, let kind):
            if let searchURL = DirectSources.teamSearchURL(name), let teamData = await getData(searchURL, session),
               let team = DirectSources.parseTeam(teamData), let url = DirectSources.eventsURL(teamID: team.id, kind: kind),
               let data = await getData(url, session) {
                text = DirectSources.renderEvents(data, team: team.name, kind: kind)
            }
        }
        DiagnosticsLog.shared.record("direct source", text == nil ? "failed" : "ok")
        return text
    }

    /// Opens the top three results at once and keeps the few sentences from each that answer the question.
    static func readPages(_ results: [SearchResult], query: String) async -> [Int: String] {
        let top = Array(results.prefix(5))
        return await withTaskGroup(of: (Int, String?).self) { group in
            for (i, r) in top.enumerated() {
                group.addTask { (i, await Self.passage(from: r.url, query: query)) }
            }
            var out: [Int: String] = [:]
            for await (i, text) in group { if let text, !text.isEmpty { out[i] = text } }
            return out
        }
    }

    private static func passage(from url: URL, query: String) async -> String? {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue(WebSearch.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 10
        config.httpCookieStorage = nil
        config.urlCache = nil
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        guard let result = try? await session.data(for: request), let http = result.1 as? HTTPURLResponse, http.statusCode == 200,
              (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased().contains("html"),
              result.0.count < 3_000_000, let final = http.url, case .allowed(_) = WebPolicy.normalize(final.absoluteString),
              let html = String(data: result.0, encoding: .utf8) ?? String(data: result.0, encoding: .isoLatin1) else { return nil }
        let text = PageExtract.excerpt(html: html, query: query)
        return text.isEmpty ? nil : text
    }

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
            guard let text = await InfoFetcher.weather(place: place) else {
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
        let asked = WebSearch.cleanQuery(QueryScrubber.scrub(query: (CalendarStore.args(call)["query"] as? String) ?? "", userMessage: (CalendarStore.args(call)["query"] as? String) ?? "").query)
        guard !asked.isEmpty else { return "Not done: no search words were given." }
        if let name = Weather.place(in: asked), let report = await Self.weather(for: name) { return report }
        if let request = Standings.request(for: asked), let text = await Self.standings(request) { return text }
        if let request = SportsScores.request(for: asked), let text = await InfoFetcher.sports(request) { return text }
        if let request = InfoFeeds.cryptoRequest(for: asked), let text = await InfoFetcher.crypto(request) { return text }
        if let request = InfoFeeds.stockRequest(for: asked), let text = await InfoFetcher.stock(request) { return text }
        if let request = InfoFeeds.holidayRequest(for: asked), let text = await InfoFetcher.holidays(request) { return text }
        if let topic = InfoFeeds.newsTopic(for: asked), let text = await InfoFetcher.news(topic: topic) { return text }
        if let request = DirectSources.request(for: asked) {
            if case .currency(let amount, let from, let to) = request, let text = await InfoFetcher.currency(amount: amount, from: from, to: to) { return text }
            if case .currency = request {} else if let text = await Self.direct(request) { return text }
            DiagnosticsLog.shared.record("direct source", "no answer, using search")
        }
        if let subject = InfoFeeds.referenceSubject(for: asked), let text = await InfoFetcher.reference(subject: subject) { return text }

        // Up to three rounds: search, read the top pages, and if they do not cover the question try better words.
        var query = WebSearch.queryFrom(asked)
        var best: (results: [SearchResult], pages: [Int: String])?
        var blocked = false
        var failure: String?
        let year = Calendar.current.component(.year, from: Date())
        for round in 1...SearchLoop.maxRounds {
            switch await Self.searchRound(query) {
            case .failed(let why):
                failure = why
            case .blocked:
                blocked = true
            case .found(let results, let pages):
                failure = nil
                let picked = WebSearch.select(results: results, excerpts: pages)
                let current = (results: picked.results, pages: picked.excerpts)
                if best == nil || current.pages.count > (best?.pages.count ?? 0) { best = current }
                DiagnosticsLog.shared.record("web search", "round \(round): \(results.count) results, \(pages.count) pages")
                if SearchLoop.isEnough(query: asked, excerpts: Array(current.pages.values)) { return WebSearch.render(current.results, query: asked, excerpts: current.pages) }
            }
            if blocked { break }
            guard let next = SearchLoop.refine(asked, round: round + 1, year: year), next != query else { break }
            query = next
        }
        if let best { return WebSearch.render(best.results, query: asked, excerpts: best.pages) }
        if blocked { return "Not done: the search service is blocking requests right now. Tell the user." }
        return failure ?? WebSearch.render([], query: asked)
    }

    private enum Round {
        case found([SearchResult], [Int: String])
        case failed(String)
        case blocked
    }

    private static func searchRound(_ query: String) async -> Round {
        guard let url = WebSearch.url(for: query) else { return .failed("Not done: no search words were given.") }
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
            guard let http = response as? HTTPURLResponse else { return .failed("Not done: the search service did not answer. Tell the user.") }
            guard http.statusCode == 200 else {
                DiagnosticsLog.shared.record("web search", "status \(http.statusCode)")
                return .failed("Not done: the search service answered \(http.statusCode). Tell the user the search is not available right now.")
            }
            guard data.count < 800_000, let html = String(data: data, encoding: .utf8) else { return .failed("Not done: the search answer could not be read.") }
            let results = WebSearch.parse(html: html)
            if results.isEmpty, html.contains("anomaly") || html.contains("bots use DuckDuckGo") { return .blocked }
            if results.isEmpty { return .failed(WebSearch.render([], query: query)) }
            let pages = await readPages(results, query: query)
            return .found(results, pages)
        } catch {
            DiagnosticsLog.shared.record("web search", "failed: \(String(String(describing: error).prefix(80)))")
            return .failed("Not done: could not reach the search service. Tell the user they may be offline.")
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
        return await WebSession.shared.look(controls: !((a["readText"] as? Bool) ?? false), part: (a["part"] as? Int) ?? 1, find: (a["find"] as? String) ?? "", chat: chat, callID: call.id)
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

struct LiveSearchWebTool: AppTool {
    let name = "searchWeb"
    let description = "Searches the web and returns result titles, sites and short summaries. Use it first for news, scores, weather, prices, schedules and anything that may have changed. Never tell the user to search themselves."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    struct Arguments {
        var query: String
    }

    let params: [ToolParam] = [
        .string("query", "Three to eight plain search words, for example: Real Betis next match"),
    ]

    func run(_ args: ToolArgs) async -> String {
        do { return try await perform(arguments: Arguments(query: args.string("query"))) }
        catch { return "Failed: \(name) could not finish." }
    }

    func perform(arguments a: Arguments) async throws -> String {
        let rowID = UUID()
        let scrubbed = ctx.scrub(WebSearch.cleanQuery(a.query))
        if scrubbed.changed { DiagnosticsLog.shared.record("web search", "removed \(scrubbed.removed.count) private words from the search") }
        let query = WebSearch.cleanQuery(scrubbed.query)
        await reporter.toolStarted(rowID, title: String(localized: "Searching the web…"))
        guard !query.isEmpty else {
            await reporter.toolFinished(rowID, title: String(localized: "No search words"), details: [], failed: true)
            return "Not done: no search words were given."
        }
        let data = (try? JSONSerialization.data(withJSONObject: ["query": query])) ?? Data()
        let outcome = await gate.run(ToolCall(id: rowID, toolName: "searchWeb", argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext())
        switch outcome {
        case .executed(let out):
            ctx.markUntrusted(personal: false)
            let items = out.split(separator: "\n").map(String.init)
                .filter { $0.first?.isNumber == true && $0.contains(". ") }
                .map { String($0.drop(while: { $0.isNumber || $0 == "." || $0 == " " })) }
            let failed = out.hasPrefix("Not done")
            let direct = !failed && !out.hasPrefix("Web search results") && !out.hasPrefix("The search found nothing")
            let title = failed ? String(localized: "Couldn't search the web")
                : direct ? String(localized: "Looked up live data")
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

struct LiveOpenWebsiteTool: AppTool {
    let name = "openWebsite"
    let description = "Opens a website the user named, or a search result, in the in-app browser. Returns the numbered buttons, links and fields on the page."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    struct Arguments {
        var url: String
    }

    let params: [ToolParam] = [
        .string("url", "Web address or domain, for example apple.com or https://example.com/page. https only."),
    ]

    func run(_ args: ToolArgs) async -> String {
        do { return try await perform(arguments: Arguments(url: args.string("url"))) }
        catch { return "Failed: \(name) could not finish." }
    }

    func perform(arguments a: Arguments) async throws -> String {
        let rowID = UUID()
        switch WebPolicy.normalize(a.url) {
        case .rejected(let why):
            await reporter.toolStarted(rowID, title: String(localized: "Opening a website…"))
            await reporter.toolFinished(rowID, title: String(localized: "Couldn't open that address"), details: [], failed: true)
            return "Not done: \(why)"
        case .allowed(let url):
            let host = WebPolicy.host(of: url)
            let strict = await MainActor.run { AppSettings.shared.strictWeb }
            let known = await WebSession.shared.isAllowedHost(host, chat: ctx.chatID)
            let tool = (strict && !known) ? "openOtherSite" : "openWebsite"
            return await runWebStep(gate, ctx, reporter, name: tool, json: ["url": url.absoluteString],
                                    title: String(localized: "Opening \(host)…"), rowID: rowID)
        }
    }
}

struct LiveLookAtPageTool: AppTool {
    let name = "lookAtPage"
    let description = "Looks at the open website. Lists the numbered buttons, links and fields in view, or reads the page text."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    struct Arguments {
        var readText: Bool
        var part: Int
        var find: String
    }

    let params: [ToolParam] = [
        .bool("readText", "False lists the numbered buttons, links and fields in view. True reads the page text instead."),
        .int("part", "Which part of the text to read, starting at 1. Only used when readText is true."),
        .string("find", "Words from the label of a button or link to search the whole page for, including parts out of view and menus. Empty for the normal list. Use it when the item you want is not listed."),
    ]

    func run(_ args: ToolArgs) async -> String {
        do { return try await perform(arguments: Arguments(readText: args.bool("readText"), part: args.int("part"), find: args.string("find"))) }
        catch { return "Failed: \(name) could not finish." }
    }

    func perform(arguments a: Arguments) async throws -> String {
        await runWebStep(gate, ctx, reporter, name: "lookAtPage", json: ["readText": a.readText, "part": a.part, "find": a.find],
                         title: String(localized: "Looking at the page…"), rowID: UUID())
    }
}

struct LiveActOnPageTool: AppTool {
    let name = "actOnPage"
    let description = "Clicks, types, chooses or scrolls on the open website. Use element numbers from lookAtPage. Never fills passwords, card numbers or codes."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    enum PageAction: String, CaseIterable {
        case click, type, typeAndEnter, choose, check, uncheck, setSlider, scrollDown, scrollUp, scrollTop, scrollBottom
    }

    struct Arguments {
        var element: Int
        var action: PageAction
        var value: String
    }

    let params: [ToolParam] = [
        .int("element", "Element number from lookAtPage. Use 0 for scrolling."),
        .choice("action", "", PageAction.allCases.map(\.rawValue)),
        .string("value", "Text to type, option to choose, or slider number. Empty for click, check, uncheck and scroll."),
    ]

    func run(_ args: ToolArgs) async -> String {
        guard let action = PageAction(rawValue: args.string("action")) else { return "Not done: action must be one of: \(PageAction.allCases.map(\.rawValue).joined(separator: ", "))." }
        do { return try await perform(arguments: Arguments(element: args.int("element"), action: action, value: args.string("value"))) }
        catch { return "Failed: \(name) could not finish." }
    }

    func perform(arguments a: Arguments) async throws -> String {
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
