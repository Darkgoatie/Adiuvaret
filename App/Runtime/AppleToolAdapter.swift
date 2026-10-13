import Foundation
import FoundationModels
import ToolKit
import Diagnostics

/// Shows one AppTool to Apple's model. The schema is built at run time from the tool's parameter list, and the arguments the model
/// sends come back as JSON text that the tool reads itself, so the tools do not depend on the framework at all.
@available(iOS 26.0, *)
struct AppleToolAdapter: Tool {
    let inner: any AppTool

    var name: String { inner.name }
    var description: String { inner.description }

    var parameters: GenerationSchema {
        do { return try Self.schema(for: inner) }
        catch {
            // A schema that cannot be built leaves the model a tool with no parameters rather than no tool at all.
            DiagnosticsLog.shared.record("apple tool", "schema failed for \(inner.name): \(String(String(describing: error).prefix(100)))")
            return (try? GenerationSchema(root: DynamicGenerationSchema(name: inner.name, properties: []), dependencies: [])) ?? GeneratedContent.generationSchema
        }
    }

    func call(arguments: GeneratedContent) async throws -> String {
        guard let args = ToolArgs(json: arguments.jsonString) else {
            return "Not done: the arguments could not be read. Call the tool again with every field filled."
        }
        return await inner.run(args)
    }

    static func schema(for tool: any AppTool) throws -> GenerationSchema {
        let properties = tool.params.map { p -> DynamicGenerationSchema.Property in
            let type: DynamicGenerationSchema
            switch p.kind {
            case .string: type = DynamicGenerationSchema(type: String.self)
            case .int: type = DynamicGenerationSchema(type: Int.self)
            case .bool: type = DynamicGenerationSchema(type: Bool.self)
            case .choice(let options): type = DynamicGenerationSchema(name: p.name + "Choice", anyOf: options)
            }
            return DynamicGenerationSchema.Property(name: p.name, description: p.guide.isEmpty ? nil : p.guide, schema: type)
        }
        return try GenerationSchema(root: DynamicGenerationSchema(name: tool.name + "Arguments", properties: properties), dependencies: [])
    }
}

@available(iOS 26.0, *)
extension ToolHost {
    /// The tools for these ids in the form Apple's model takes.
    func appleTools(for ids: [String]) -> [any Tool] {
        tools(for: ids).map { AppleToolAdapter(inner: $0) }
    }
}
