import Foundation
import FoundationModels
import ModelLibrary
import Diagnostics

/// Lets an online model use the same tool objects the on-device model uses: the schema goes out as JSON,
/// the arguments come back as JSON and are turned into the tool's own argument type.
enum ToolBridge {
    static func wireTool(_ tool: any Tool) -> WireTool? {
        guard let data = try? JSONEncoder().encode(tool.parameters), var schema = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        // Providers want a plain object schema. The framework's own bookkeeping keys are dropped.
        schema["x-order"] = nil
        schema["title"] = nil
        guard let clean = try? JSONSerialization.data(withJSONObject: schema) else { return nil }
        return WireTool(name: tool.name, description: tool.description, schemaJSON: String(decoding: clean, as: UTF8.self))
    }

    /// Runs one tool for a model's call. The result is always text: the tool's output, or a sentence saying why it did not run.
    static func run(_ tool: any Tool, argumentsJSON: String) async -> String {
        func open<T: Tool>(_ t: T) async -> String {
            let content: GeneratedContent
            do { content = try GeneratedContent(json: argumentsJSON.isEmpty ? "{}" : argumentsJSON) }
            catch { return "Not done: the arguments were not valid JSON. Call the tool again with a complete JSON object." }
            let arguments: T.Arguments
            do { arguments = try T.Arguments(content) }
            catch { return "Not done: the arguments did not match what \(t.name) expects. Call it again and fill every field." }
            do {
                let output = try await t.call(arguments: arguments)
                return String(describing: output)
            } catch {
                DiagnosticsLog.shared.record("cloud tool", "\(t.name) threw \(type(of: error))")
                return "Failed: \(t.name) could not finish."
            }
        }
        return await open(tool)
    }
}
