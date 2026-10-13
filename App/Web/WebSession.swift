import Foundation
import Observation
import WebKit
import ToolKit
import Diagnostics

/// What a web step looked like, for the row in the chat.
struct WebSummary: Sendable {
    var title: String
    var details: [String]
    var failed: Bool
}

enum WebAction: Sendable {
    case click, type, typeAndEnter, choose, check, uncheck, setSlider
    case scrollDown, scrollUp, scrollTop, scrollBottom

    var isScroll: Bool {
        switch self { case .scrollDown, .scrollUp, .scrollTop, .scrollBottom: true; default: false }
    }
}

/// The one in-app browser the assistant drives. It keeps its sign-ins between runs and only visits sites the user approved.
@MainActor @Observable
final class WebSession: NSObject {
    static let shared = WebSession()

    struct BlockedMove: Equatable { let host: String; let url: URL }

    private(set) var host = ""
    private(set) var title = ""
    private(set) var isLoading = false
    private(set) var canGoBack = false
    private(set) var agentActing = false
    private(set) var blocked: BlockedMove?
    var panelVisible = false

    var hasPage: Bool { !host.isEmpty }

    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private let world = WKContentWorld.world(name: "adiuvaret-agent")
    @ObservationIgnored private var allowed: [String] = []
    @ObservationIgnored private var lastBody = ""
    @ObservationIgnored private var sameBody = 0
    @ObservationIgnored private var trailHost = ""
    @ObservationIgnored private var trail: [String] = []
    @ObservationIgnored private let siteNotes = SiteNoteStore.shared
    @ObservationIgnored private var owner: UUID?
    @ObservationIgnored private var elements: [Int: PageElement] = [:]
    @ObservationIgnored private var lastHasPassword = false
    @ObservationIgnored private var lastLoadError: String?
    @ObservationIgnored private var summaries: [UUID: WebSummary] = [:]
    @ObservationIgnored private var waiters: [Waiter] = []

    @MainActor private final class Waiter {
        var continuation: CheckedContinuation<Void, Never>?
        func resume() { continuation?.resume(); continuation = nil }
    }

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        config.applicationNameForUserAgent = "Version/26.0 Mobile/15E148 Safari/604.1"
        if let url = Bundle.main.url(forResource: "agent", withExtension: "js"), let source = try? String(contentsOf: url, encoding: .utf8) {
            config.userContentController.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: WKContentWorld.world(name: "adiuvaret-agent")))
        }
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 700), configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    // MARK: what the tools ask

    func isAllowedHost(_ host: String, chat: UUID) -> Bool { owner == chat && WebPolicy.isAllowed(host, in: allowed) }
    func element(_ id: Int) -> PageElement? { elements[id] }
    var pageHasPassword: Bool { lastHasPassword }

    func takeSummary(_ id: UUID) -> WebSummary {
        summaries.removeValue(forKey: id) ?? WebSummary(title: String(localized: "Used the browser"), details: [], failed: false)
    }

    func open(_ url: URL, chat: UUID, callID: UUID) async -> String {
        claim(chat)
        let host = WebPolicy.host(of: url)
        if !WebPolicy.isAllowed(host, in: allowed) { allowed.append(host) }
        blocked = nil
        lastLoadError = nil
        elements = [:]
        trailHost = host
        trail = []
        lastBody = ""; sameBody = 0
        return await busy {
            webView.load(URLRequest(url: url, timeoutInterval: 30))
            await waitForLoad(seconds: 25)
            await settle()
            if let error = lastLoadError {
                summarize(callID, String(localized: "Couldn't open \(host)"), [], failed: true)
                return "Could not open the page: \(error)"
            }
            let known = SiteNoteRules.render(siteNotes.note(for: host))
            return await observe(callID, title: String(localized: "Opened \(host)"), budget: 1200, extra: known)
        }
    }

    func look(controls: Bool, part: Int, find: String = "", chat: UUID, callID: UUID) async -> String {
        if let problem = notReady(chat) { summarize(callID, String(localized: "No website is open"), [], failed: true); return problem }
        return await busy {
            let query = find.trimmingCharacters(in: .whitespacesAndNewlines)
            if controls || !query.isEmpty { return await observe(callID, title: nil, budget: 1500, query: query) }
            let raw = (try? await webView.callAsyncJavaScript("return window.__agent ? window.__agent.readText() : ''", contentWorld: world)) as? String ?? ""
            let parts = SnapshotFormat.partCount(of: raw)
            let shown = min(max(part, 1), parts)
            summarize(callID, String(localized: "Read the page · part \(shown) of \(parts)"), [], failed: false)
            return SnapshotFormat.page(text: raw, part: shown)
        }
    }

    func act(_ action: WebAction, element id: Int, value: String, chat: UUID, callID: UUID) async -> String {
        if let problem = notReady(chat) { summarize(callID, String(localized: "No website is open"), [], failed: true); return problem }
        return await busy {
            let before = blocked
            lastLoadError = nil
            let label: String
            let message: String
            if action.isScroll {
                let direction: String = switch action {
                case .scrollUp: "up"
                case .scrollTop: "top"
                case .scrollBottom: "bottom"
                default: "down"
                }
                let reply = await runScript("return window.__agent.scroll(direction)", ["direction": direction])
                label = ""
                message = reply.message
                if !reply.ok { summarize(callID, String(localized: "Couldn't scroll"), [], failed: true); return "Not done: \(reply.message)" }
            } else {
                let (mode, text, enter): (String, String, Bool) = switch action {
                case .click: ("click", "", false)
                case .type: ("fill", value, false)
                case .typeAndEnter: ("fill", value, true)
                case .choose, .setSlider: ("fill", value, false)
                case .check: ("fill", "true", false)
                default: ("fill", "false", false)
                }
                let reply = await runScript("return window.__agent.act(id, mode, text, enter)", ["id": id, "mode": mode, "text": text, "enter": enter])
                label = reply.label
                message = reply.message
                if !reply.ok {
                    let refusal = reply.message == "sensitive"
                        ? "That is a password, card or code field. I never fill those. Ask the user to type it in the browser panel and tell you when it is done."
                        : reply.message
                    summarize(callID, refusal.hasPrefix("That is a password") ? String(localized: "Left a private field to you") : String(localized: "Couldn't do that"), [], failed: true)
                    return "Not done: \(refusal)"
                }
            }
            try? await Task.sleep(for: .milliseconds(700))
            if isLoading { await waitForLoad(seconds: 12) }
            await settle()
            var extra = ""
            if let now = blocked, now != before {
                extra = "The site tried to go to \(now.host), which this chat has not opened. Tell the user; they can allow it in the browser panel."
            } else if let error = lastLoadError {
                extra = "The page reported an error: \(error)"
            }
            if action == .click, !trailHost.isEmpty {
                trail.append(label)
                siteNotes.record(host: trailHost, steps: trail)
            }
            let title = Self.actionTitle(action, label: label, value: value, message: message)
            return await observe(callID, title: title, budget: 900, extra: extra)
        }
    }

    // MARK: user controls

    func allowBlockedMove() {
        guard let move = blocked else { return }
        if !WebPolicy.isAllowed(move.host, in: allowed) { allowed.append(move.host) }
        blocked = nil
        webView.load(URLRequest(url: move.url))
    }

    func dismissBlockedMove() { blocked = nil }
    func goBack() { webView.goBack() }
    func reload() { webView.reload() }
    func stopLoading() { webView.stopLoading() }

    /// Forgets every sign-in and cookie the browser holds and closes the page.
    func clearWebsiteData() async {
        await WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        allowed = []; owner = nil; elements = [:]; blocked = nil
        siteNotes.clear(); trail = []; trailHost = ""
        webView.load(URLRequest(url: URL(string: "about:blank")!))
        DiagnosticsLog.shared.record("web", "website data cleared")
    }

    // MARK: inside

    private func claim(_ chat: UUID) {
        guard owner != chat else { return }
        owner = chat
        allowed = []
        elements = [:]
    }

    private func notReady(_ chat: UUID) -> String? {
        guard owner == chat, let url = webView.url, WebPolicy.isAllowed(WebPolicy.host(of: url), in: allowed) else {
            return "No website is open for this chat. Call openWebsite first."
        }
        return nil
    }

    private func busy<T>(_ body: () async -> T) async -> T {
        agentActing = true
        defer { agentActing = false }
        return await body()
    }

    private func summarize(_ id: UUID, _ title: String, _ details: [String], failed: Bool) {
        summaries[id] = WebSummary(title: title, details: details, failed: failed)
    }

    private func observe(_ callID: UUID, title: String?, budget: Int, extra: String = "", query: String = "") async -> String {
        guard let snap = await snapshot(query: query) else {
            summarize(callID, String(localized: "Couldn't read the page"), [], failed: true)
            return "The page could not be read. It may still be loading; try lookAtPage again."
        }
        let lines = snap.elements.prefix(8).map { SnapshotFormat.elementLine($0) }
        let looked = query.isEmpty ? String(localized: "Looked at the page · \(snap.elements.count) items") : String(localized: "Searched the page · \(snap.elements.count) found")
        summarize(callID, title ?? looked, lines, failed: false)
        let body = SnapshotFormat.render(snap, budget: budget)
        if body == lastBody { sameBody += 1 } else { sameBody = 0; lastBody = body }
        var notes = extra
        if sameBody >= 1 {
            notes += (notes.isEmpty ? "" : "\n") + "The page looks exactly as it did the last time. Clicking or looking again will not change it. Events, tables and most content are plain text and are not listed as buttons: call lookAtPage with readText true and answer from that text. If it does not hold the answer, tell the user what is blocking you instead of repeating a step."
        }
        return notes.isEmpty ? body : notes + "\n" + body
    }

    private func snapshot(query: String = "") async -> PageSnapshot? {
        let raw = try? await webView.callAsyncJavaScript(
            "return window.__agent ? window.__agent.snapshot(max, query) : null", arguments: ["max": 60, "query": query], contentWorld: world)
        guard let json = raw as? String, let snap = try? JSONDecoder().decode(PageSnapshot.self, from: Data(json.utf8)) else { return nil }
        elements = Dictionary(snap.elements.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        lastHasPassword = snap.hasPassword
        return snap
    }

    private struct ScriptReply { let ok: Bool; let message: String; let label: String }

    private func runScript(_ body: String, _ arguments: [String: Any]) async -> ScriptReply {
        let raw = try? await webView.callAsyncJavaScript(
            "if (!window.__agent) { return JSON.stringify({ok:false,message:'The page is not ready.'}); } " + body,
            arguments: arguments, contentWorld: world)
        guard let json = raw as? String, let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
            return ScriptReply(ok: false, message: "The page did not answer.", label: "")
        }
        return ScriptReply(ok: object["ok"] as? Bool ?? false, message: object["message"] as? String ?? "", label: object["label"] as? String ?? "")
    }

    private static func actionTitle(_ action: WebAction, label: String, value: String, message: String) -> String {
        let name = label.isEmpty ? String(localized: "the page") : "“\(String(label.prefix(30)))”"
        switch action {
        case .click: return String(localized: "Clicked \(name)")
        case .type: return String(localized: "Typed in \(name)")
        case .typeAndEnter: return String(localized: "Typed in \(name) and pressed Enter")
        case .choose: return String(localized: "Chose an option in \(name)")
        case .check: return String(localized: "Ticked \(name)")
        case .uncheck: return String(localized: "Unticked \(name)")
        case .setSlider: return String(localized: "Moved \(name)")
        case .scrollDown, .scrollUp, .scrollTop, .scrollBottom: return String(localized: "Scrolled the page")
        }
    }

    private func settle() async {
        try? await Task.sleep(for: .milliseconds(500))
        if isLoading { await waitForLoad(seconds: 6) }
    }

    private func waitForLoad(seconds: Double) async {
        guard isLoading || webView.isLoading else { return }
        let waiter = Waiter()
        waiters.append(waiter)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiter.continuation = continuation
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(seconds))
                waiter.resume()
            }
        }
        waiters.removeAll { $0.continuation == nil }
    }

    private func loadEnded() {
        isLoading = false
        refreshState()
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }

    private func refreshState() {
        host = webView.url.map { WebPolicy.host(of: $0) } ?? ""
        title = webView.title ?? ""
        canGoBack = webView.canGoBack
    }
}

extension WebSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        if url.scheme == "about" { return .allow }
        guard url.scheme == "https" else { return .cancel }
        let host = WebPolicy.host(of: url)
        if WebPolicy.isBlockedHost(host) { return .cancel }
        let isMain = navigationAction.targetFrame?.isMainFrame ?? true
        if isMain, !WebPolicy.isAllowed(host, in: allowed) {
            blocked = BlockedMove(host: host, url: url)
            DiagnosticsLog.shared.record("web", "blocked a move to another site")
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        navigationResponse.canShowMIMEType ? .allow : .cancel
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        lastLoadError = nil
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { refreshState() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loadEnded() }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }

    private func failed(_ error: Error) {
        let code = (error as NSError).code
        if code != NSURLErrorCancelled { lastLoadError = String(error.localizedDescription.prefix(120)) }
        loadEnded()
    }
}

extension WebSession: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Pop-ups open in the same view, and still pass the site check.
        if navigationAction.request.url?.scheme == "https" { webView.load(navigationAction.request) }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async {}
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool { false }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo) async -> String? { nil }
}
