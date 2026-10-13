import Foundation

/// One argument of a tool, described without any model framework. The Apple model, online models and tests all read the same list.
public struct ToolParam: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case string, int, bool, choice([String]) }

    public let name: String
    public let guide: String
    public let kind: Kind

    public init(_ name: String, _ guide: String, _ kind: Kind) {
        self.name = name; self.guide = guide; self.kind = kind
    }

    public static func string(_ name: String, _ guide: String = "") -> ToolParam { ToolParam(name, guide, .string) }
    public static func int(_ name: String, _ guide: String = "") -> ToolParam { ToolParam(name, guide, .int) }
    public static func bool(_ name: String, _ guide: String = "") -> ToolParam { ToolParam(name, guide, .bool) }
    public static func choice(_ name: String, _ guide: String = "", _ options: [String]) -> ToolParam { ToolParam(name, guide, .choice(options)) }
}

/// The values a model sent for a tool call, read without knowing which model sent them. Numbers may arrive as text and text as numbers.
public struct ToolArgs: Sendable, Equatable {
    private let values: [String: String]

    public init(_ values: [String: String] = [:]) { self.values = values }

    /// Nil when the text is not a JSON object. Nested values are ignored; tools take flat arguments.
    public init?(json: String) {
        guard let data = json.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        var out: [String: String] = [:]
        for (key, value) in object {
            if let s = value as? String { out[key] = s }
            else if let n = value as? NSNumber {
                out[key] = CFGetTypeID(n) == CFBooleanGetTypeID() ? (n.boolValue ? "true" : "false") : n.stringValue
            }
        }
        values = out
    }

    public func string(_ name: String) -> String { values[name] ?? "" }

    public func int(_ name: String) -> Int {
        let s = (values[name] ?? "").trimmingCharacters(in: .whitespaces)
        if let i = Int(s) { return i }
        if let d = Double(s), d.isFinite, abs(d) < 1e15 { return Int(d) }
        return 0
    }

    public func bool(_ name: String) -> Bool { ["true", "1", "yes"].contains((values[name] ?? "").lowercased()) }

    public var asDictionary: [String: String] { values }
}

/// A tool the assistant can use, independent of the model that calls it. The Apple model gets it through an adapter on iOS 26 and later;
/// online models get its JSON schema. `run` never throws: a problem comes back as a sentence the model can read.
public protocol AppTool: Sendable {
    var name: String { get }
    var description: String { get }
    var params: [ToolParam] { get }
    func run(_ args: ToolArgs) async -> String
}

public enum ToolSchema {
    /// A JSON schema object for the parameters, as providers expect it. Every parameter is required.
    public static func json(_ params: [ToolParam]) -> String {
        var properties: [String: Any] = [:]
        for p in params {
            var o: [String: Any] = [:]
            switch p.kind {
            case .string: o["type"] = "string"
            case .int: o["type"] = "integer"
            case .bool: o["type"] = "boolean"
            case .choice(let options): o["type"] = "string"; o["enum"] = options
            }
            if !p.guide.isEmpty { o["description"] = p.guide }
            properties[p.name] = o
        }
        let schema: [String: Any] = ["type": "object", "properties": properties, "required": params.map(\.name), "additionalProperties": false]
        let data = (try? JSONSerialization.data(withJSONObject: schema, options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

public extension ConnectorToolSpec {
    /// The parameters a model sees for this tool. A tool with none gets one empty placeholder, which models and schemas handle better than no properties.
    var toolParams: [ToolParam] {
        arguments.isEmpty ? [.string("unused", "Always an empty string.")] : arguments.map { .string($0.name, $0.guide) }
    }
}
