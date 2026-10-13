import Foundation
import AdiuvaretCore
import PolicyEngine
import ToolKit

/// One HTTPS request to a host the user approved. The token is attached here, only for that host, with no redirects.
enum APIClient {
    static func send(_ request: URLRequest) async -> (status: Int, data: Data)? {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCache = nil
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(for: request), let http = response as? HTTPURLResponse, data.count < 1_500_000 else { return nil }
        return (http.statusCode, data)
    }
}

/// Runs callAPI (reads only) and callAPIWrite (any method, always asks). The read name refuses everything but GET, so the
/// model cannot reach a write through the tool that never shows a card.
struct CallAPIExecutor: ToolExecutor {
    func execute(_ call: ToolCall) async throws -> String {
        let a = ManifestExecutor.strings(CalendarStore.args(call))
        let methodText = (a["method"] ?? "").isEmpty ? "GET" : (a["method"] ?? "")
        guard let method = APIMethod.normalize(methodText) else { return "Not done: the method must be GET, POST, PUT, PATCH or DELETE." }
        if call.toolName == "callAPI", APIMethod.isWrite(method) { return "Not done: only GET is allowed here." }
        guard let host = APIHost.normalize(a["host"] ?? "") else { return "Not done: the host must be a plain domain name such as api.example.com." }
        guard let entry = APIHostStore.shared.entry(host) else { return "Not done: \(host) is not approved yet." }
        let auth = entry.style
        var token: String?
        if auth.needsToken {
            token = SecretStore.token(for: APIHostStore.secretID(host))
            if token == nil { return "Not done: \(host) needs a token and none is stored. Tell the user to add one in Advanced, API access." }
        }
        switch APIRequestBuilder.build(host: host, method: method, path: a["path"] ?? "", query: a["query"] ?? "", body: a["body"] ?? "", auth: auth, token: token) {
        case .failure(let e): return "Not done: \(e.message)"
        case .success(let request):
            guard let (status, data) = await APIClient.send(request) else { return "Not done: \(host) could not be reached, or the answer was too large. Tell the user." }
            var text = APIResponse.text(status: status, data: data, host: host, token: token)
            if status == 401 || status == 403, !auth.needsToken || token != nil {
                text += "\nThe host refused the credentials. Tell the user to check the token and its style in Advanced, API access."
            }
            return text
        }
    }
}

/// Adds a host the user just approved on a card. It starts with no token; a token is added in Advanced, API access.
struct ApproveAPIHostExecutor: ToolExecutor {
    func execute(_ call: ToolCall) async throws -> String {
        let a = ManifestExecutor.strings(CalendarStore.args(call))
        guard let host = APIHost.normalize(a["host"] ?? "") else { return "Not done: not a valid host." }
        if APIHostStore.shared.entry(host) == nil { APIHostStore.shared.add(host: host, auth: .none, token: nil) }
        return "Approved \(host)."
    }
}

struct LiveCallAPITool: AppTool {
    let name = "callAPI"
    let description = "Calls a web API over HTTPS and returns the answer. Use it to do what the user asks on a service, after reading its documentation with searchWeb, openWebsite or lookAtPage, or from documentation the user pasted. GET reads automatically; POST, PUT, PATCH and DELETE ask the user first. The first call to a new host asks the user to allow it. Credentials are added by the user in the app; never ask for or write a token. Only report what the answer contains."
    let gate: PolicyGate; let ctx: TaskContext; let reporter: any ToolReporter

    let params: [ToolParam] = [
        .string("host", "The API host only, for example api.example.com"),
        .choice("method", "GET reads. The others change data and ask the user.", ["GET", "POST", "PUT", "PATCH", "DELETE"]),
        .string("path", "The endpoint path starting with a slash, for example /v1/servers"),
        .string("query", "Query string without the question mark, for example limit=5&sort=name. Empty for none."),
        .string("body", "A JSON object as text for POST, PUT and PATCH. Empty for none."),
    ]

    func run(_ args: ToolArgs) async -> String {
        guard let host = APIHost.normalize(args.string("host")) else { return "Not done: the host must be a plain domain name such as api.example.com." }
        let method = APIMethod.normalize(args.string("method").isEmpty ? "GET" : args.string("method")) ?? "GET"
        let path = args.string("path")
        let json: [String: Any] = ["host": host, "method": method, "path": path, "query": args.string("query"), "body": args.string("body")]
        let write = APIMethod.isWrite(method)

        if APIHostStore.shared.entry(host) == nil {
            switch await gate.run(ToolCall(toolName: "approveAPIHost", argumentsJSON: Self.encode(["host": host])), in: ctx.callContext()) {
            case .executed: break
            case .blocked(let r): return "Not done: \(r). Nothing was sent."
            case .failed(let m): return "Failed: \(m)"
            }
        }
        let rowID = UUID()
        if !write { await reporter.toolStarted(rowID, title: String(localized: "Calling \(host)…")) }
        let outcome = await gate.run(ToolCall(id: rowID, toolName: write ? "callAPIWrite" : "callAPI", argumentsJSON: Self.encode(json)), in: ctx.callContext())
        switch outcome {
        case .executed(let out):
            ctx.markUntrusted(personal: false)
            let failed = out.hasPrefix("Not done")
            if write {
                if !failed { await reporter.actionDone(title: String(localized: "Sent to \(host)"), detail: String("\(method) \(path)".prefix(80)), undo: nil) }
            } else {
                await reporter.toolFinished(rowID, title: failed ? String(localized: "Couldn't call \(host)") : String(localized: "Called \(host)"), details: [String("\(method) \(path)".prefix(90))], failed: failed)
            }
            return out
        case .blocked(let r):
            if !write { await reporter.toolFinished(rowID, title: String(localized: "Not allowed"), details: [], failed: true) }
            return "Not done: \(r). Tell the user nothing was sent."
        case .failed(let m):
            if !write { await reporter.toolFinished(rowID, title: String(localized: "Couldn't do that"), details: [], failed: true) }
            return "Failed: \(m)"
        }
    }

    private static func encode(_ json: [String: Any]) -> String {
        String(decoding: (try? JSONSerialization.data(withJSONObject: json)) ?? Data(), as: UTF8.self)
    }
}
