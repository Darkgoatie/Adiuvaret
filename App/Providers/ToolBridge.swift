import Foundation
import ModelLibrary
import ToolKit

/// Lets an online model use the same tool objects the on-device model uses: the schema goes out as JSON,
/// the arguments come back as JSON and are read into the tool's own argument type.
enum ToolBridge {
    static func wireTool(_ tool: any AppTool) -> WireTool {
        WireTool(name: tool.name, description: tool.description, schemaJSON: ToolSchema.json(tool.params))
    }

    /// Runs one tool for a model's call. The result is always text: the tool's output, or a sentence saying why it did not run.
    static func run(_ tool: any AppTool, argumentsJSON: String) async -> String {
        guard let args = ToolArgs(json: argumentsJSON.isEmpty ? "{}" : argumentsJSON) else {
            return "Not done: the arguments were not valid JSON. Call the tool again with a complete JSON object."
        }
        return await tool.run(args)
    }
}
