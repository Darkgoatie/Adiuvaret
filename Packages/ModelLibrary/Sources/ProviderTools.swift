import Foundation

/// A tool offered to an online model: its name, what it does, and its arguments as a JSON schema.
public struct WireTool: Sendable, Equatable {
    public let name: String
    public let description: String
    /// The arguments schema as JSON text, an object schema.
    public let schemaJSON: String
    public init(name: String, description: String, schemaJSON: String) { self.name = name; self.description = description; self.schemaJSON = schemaJSON }
}

/// One tool call a model asked for.
public struct WireCall: Sendable, Equatable {
    public let id: String
    public let name: String
    public let argumentsJSON: String
    public init(id: String, name: String, argumentsJSON: String) { self.id = id; self.name = name; self.argumentsJSON = argumentsJSON }
}

/// A conversation turn that can carry tool calls and tool results, which the plain `ProviderWire.Message` cannot.
public enum WireTurn: Sendable, Equatable {
    case user(String, images: [ProviderWire.Image])
    case assistant(text: String, calls: [WireCall])
    case toolResults([ToolResult])

    public struct ToolResult: Sendable, Equatable {
        public let callID: String
        public let name: String
        public let output: String
        public init(callID: String, name: String, output: String) { self.callID = callID; self.name = name; self.output = output }
    }
}

/// Collects the pieces of a streamed answer: text, plus tool calls that arrive in fragments.
public struct WireAccumulator: Sendable {
    public private(set) var text = ""
    private var order: [Int] = []
    private var ids: [Int: String] = [:]
    private var names: [Int: String] = [:]
    private var args: [Int: String] = [:]
    public private(set) var finishedForTools = false

    public init() {}

    public mutating func add(_ delta: ProviderWire.Delta) {
        text += delta.text
        for f in delta.toolFragments {
            if !order.contains(f.index) { order.append(f.index) }
            if let id = f.id, !id.isEmpty { ids[f.index] = id }
            if let n = f.name, !n.isEmpty { names[f.index] = n }
            if let a = f.arguments { args[f.index, default: ""] += a }
        }
        if delta.toolStop { finishedForTools = true }
    }

    public var calls: [WireCall] {
        order.sorted().compactMap { i in
            guard let name = names[i], !name.isEmpty else { return nil }
            let raw = (args[i] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return WireCall(id: ids[i] ?? "call_\(i)", name: name, argumentsJSON: raw.isEmpty ? "{}" : raw)
        }
    }
}
