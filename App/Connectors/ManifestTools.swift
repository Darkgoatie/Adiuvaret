import Foundation
import AdiuvaretCore
import PolicyEngine
import ToolKit

/// Runs any tool of a connector that is described by a manifest. The manifest decides the request, the engine builds it,
/// ServiceClient sends it with the token, and the answer is formatted by the manifest's own list template.
struct ManifestExecutor: ToolExecutor {
    let manifest: ConnectorManifest
    let tool: ConnectorToolSpec
    let reporter: (any ToolReporter)?

    /// Argument values as text. A model may send a number where the manifest expects words.
    static func strings(_ args: [String: Any]) -> [String: String] {
        var out: [String: String] = [:]
        for (k, v) in args {
            if let s = v as? String { out[k] = s }
            else if let n = v as? Int { out[k] = String(n) }
            else if let d = v as? Double { out[k] = d == d.rounded() ? String(Int(d)) : String(d) }
            else if let b = v as? Bool { out[k] = b ? "true" : "false" }
        }
        return out
    }

    func execute(_ call: ToolCall) async throws -> String {
        guard ConnectorCatalog.isOn(manifest.id) else { return ConnectorCatalog.offMessage(manifest.id) }
        let raw = Self.strings(CalendarStore.args(call))
        guard let args = ConnectorEngine.resolve(tool, raw), let request = ConnectorEngine.request(manifest, tool, raw) else {
            return "Not done: a required value was missing or not allowed. Check the arguments and call the tool again."
        }
        do {
            let data = try await ServiceClient.send(request, to: manifest.id)
            if let problem = ConnectorEngine.apiError(data, service: manifest.title) { return problem }
            if tool.isWrite {
                let id = tool.createdIDPath.flatMap { ConnectorEngine.createdID(data, path: $0) }
                let undo: UndoAction? = tool.undo == nil ? nil : id.map { .undoConnector(connector: manifest.id, tool: tool.name, id: $0) }
                let first = ConnectorEngine.approvalRows(manifest, tool, raw).first?.value ?? ""
                await reporter?.actionDone(title: "\(manifest.title): \(tool.title)", detail: String(first.prefix(80)), undo: undo)
                return ConnectorEngine.successText(tool, args: args)
            }
            guard let list = tool.list else { return "Not done: this tool has no result format." }
            return ConnectorEngine.result(list, data: data, args: args)
        } catch {
            return ServiceClient.message(error, service: manifest.title)
        }
    }
}

extension LiveDescriptors {
    /// One policy descriptor per manifest tool. A write the service can take back is a reversible write; one it cannot is irreversible and always asks.
    static var manifest: [ToolDescriptor] {
        ConnectorRegistry.manifests.flatMap { m in
            m.tools.map { t in
                ToolDescriptor(name: t.name, summary: t.title, permission: !t.isWrite ? .readOnly : (t.undo == nil ? .irreversible : .reversibleWrite), outputSensitivity: .personal)
            }
        }
    }
}

enum ManifestExecutors {
    /// One executor per manifest tool, keyed by tool name.
    static func make(reporter: (any ToolReporter)?) -> [String: any ToolExecutor] {
        var out: [String: any ToolExecutor] = [:]
        for m in ConnectorRegistry.manifests {
            for t in m.tools { out[t.name] = ManifestExecutor(manifest: m, tool: t, reporter: reporter) }
        }
        return out
    }
}

/// What every generated tool calls. Reads show a "Looked at" row; writes go through the gate and its approval card.
func runManifestTool(_ gate: PolicyGate, _ ctx: TaskContext, _ reporter: any ToolReporter, name: String, json: [String: Any]) async -> String {
    guard let owner = ConnectorRegistry.owner(ofTool: name) else { return "Failed: \(name) is not a known tool." }
    if owner.tool.isWrite {
        let data = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
        switch await gate.run(ToolCall(toolName: name, argumentsJSON: String(decoding: data, as: UTF8.self)), in: ctx.callContext()) {
        case .executed(let out): return out
        case .blocked(let r): return "Not done: \(r). Tell the user nothing was changed."
        case .failed(let m): return "Failed: \(m)"
        }
    }
    let title = owner.manifest.title
    return await serviceRead(gate, ctx, reporter, name: name, json: json, running: String(localized: "Checking \(title)…")) { n in
        n == 0 ? String(localized: "Looked at \(title) · nothing found") : String(localized: "Looked at \(title) · \(n) found")
    }
}
