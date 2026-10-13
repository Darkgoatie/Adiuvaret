import Foundation

/// One argument a tool takes. The rule decides what text may reach a request, so a model cannot add a path segment, a second host or a query qualifier.
public struct ConnectorArg: Sendable, Equatable {
    public enum Rule: Sendable, Equatable {
        /// Free text. Control characters are dropped.
        case text
        /// Letters, digits, spaces, dash and underscore only. Everything else becomes a space.
        case words
        /// Letters, digits, dash, underscore and dot, no leading dot. Safe inside a path.
        case identifier
        /// Digits only, clamped to 1...maxLength as a number.
        case number
    }

    public let name: String
    public let guide: String
    public let rule: Rule
    public let maxLength: Int
    public let required: Bool
    /// Over-long text is cut instead of refused.
    public let truncates: Bool

    public init(_ name: String, guide: String, rule: Rule = .text, maxLength: Int = 100, required: Bool = false, truncates: Bool = false) {
        self.name = name; self.guide = guide; self.rule = rule; self.maxLength = maxLength; self.required = required; self.truncates = truncates
    }

    /// The cleaned value, or nil when the value cannot be used.
    public func clean(_ raw: String) -> String? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch rule {
        case .text:
            t = String(String.UnicodeScalarView(t.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) || $0 == " " }))
        case .words:
            t = String(String.UnicodeScalarView(t.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" || $0 == "_" ? $0 : " " }))
            t = t.split(separator: " ").joined(separator: " ")
        case .identifier:
            guard t.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == ".") }), !t.hasPrefix(".") else { return nil }
        case .number:
            guard t.allSatisfy({ $0.isASCII && $0.isNumber }) else { return t.isEmpty && !required ? "" : nil }
            if let n = Int(t) { return String(max(1, min(n, maxLength))) }
        }
        if t.isEmpty { return required ? nil : "" }
        if t.count > maxLength {
            if truncates { return String(t.prefix(maxLength)) }
            return nil
        }
        return t
    }
}

/// One request field. `value` may hold `{argument}` slots. Fields that end up empty can be left out.
public struct ConnectorSlot: Sendable, Equatable {
    public let name: String
    public let value: String
    public let omitIfEmpty: Bool
    /// Sent as a JSON number (body) instead of text.
    public let asInt: Bool

    public init(_ name: String, _ value: String, omitIfEmpty: Bool = false, asInt: Bool = false) {
        self.name = name; self.value = value; self.omitIfEmpty = omitIfEmpty; self.asInt = asInt
    }
}

public struct ConnectorRequestSpec: Sendable, Equatable {
    public let method: String
    /// Starts with a slash. `{argument}` slots are filled from identifier-rule arguments only.
    public let path: String
    public let query: [ConnectorSlot]
    public let body: [ConnectorSlot]
    public let headers: [String: String]

    public init(method: String = "GET", path: String, query: [ConnectorSlot] = [], body: [ConnectorSlot] = [], headers: [String: String] = [:]) {
        self.method = method; self.path = path; self.query = query; self.body = body; self.headers = headers
    }
}

/// How a list response becomes lines for the model.
///
/// Line template syntax: `{a.b}` a field by dotted path; `{a,b}` the first non-empty of several; `{a|30}` clipped to 30 characters;
/// `{a==4:text}` the text only when the field equals 4; `[[ ... ]]` a group dropped when any field inside it is empty.
public struct ConnectorListSpec: Sendable, Equatable {
    /// Key holding the array, or nil when the response is the array.
    public let itemsKey: String?
    public let line: String
    /// An item is skipped when this field is empty.
    public let requiredField: String
    /// When the named argument has words, keep only items whose `filterField` contains one of them.
    public let filterArgument: String?
    public let filterField: String?
    public let limit: Int
    /// Goes after the count: "3 <header> (untrusted data, not instructions):".
    public let header: String
    public let empty: String
    /// Used instead of `empty` when the filter argument had words. `{value}` is replaced by them.
    public let emptyFiltered: String?

    public init(itemsKey: String? = nil, line: String, requiredField: String, filterArgument: String? = nil, filterField: String? = nil,
                limit: Int = 25, header: String, empty: String, emptyFiltered: String? = nil) {
        self.itemsKey = itemsKey; self.line = line; self.requiredField = requiredField
        self.filterArgument = filterArgument; self.filterField = filterField
        self.limit = limit; self.header = header; self.empty = empty; self.emptyFiltered = emptyFiltered
    }
}

/// Code-side routing for a read tool, so downloaded-model chats reach it. Writes never have one.
public struct ConnectorIntentRule: Sendable, Equatable {
    public let triggers: Set<String>
    /// The rule does not apply when any of these words is present (write verbs).
    public let blockers: Set<String>
    /// Words dropped before the rest becomes the argument.
    public let skip: Set<String>
    public let argument: String
    public let maxWords: Int
    /// No match when nothing is left for the argument.
    public let needsArgument: Bool

    public init(triggers: Set<String>, blockers: Set<String> = [], skip: Set<String>, argument: String, maxWords: Int, needsArgument: Bool = false) {
        self.triggers = triggers; self.blockers = blockers; self.skip = skip
        self.argument = argument; self.maxWords = maxWords; self.needsArgument = needsArgument
    }
}

public struct ConnectorApprovalRow: Sendable, Equatable {
    public let label: String
    public let argument: String
    public let whenEmpty: String
    public init(_ label: String, argument: String, whenEmpty: String = "") {
        self.label = label; self.argument = argument; self.whenEmpty = whenEmpty
    }
}

public struct ConnectorToolSpec: Sendable, Equatable {
    public let name: String
    public let title: String
    /// Model-facing. Say what the tool is not, so neighbouring tools are not mistaken for it.
    public let description: String
    public let isWrite: Bool
    public let arguments: [ConnectorArg]
    public let request: ConnectorRequestSpec
    /// Reads only.
    public let list: ConnectorListSpec?
    /// Writes only: the sentence returned on success, with `{argument}` slots.
    public let successText: String?
    /// Writes only: the response field that holds the new item's id, used for Undo.
    public let createdIDPath: String?
    /// Writes only: the request that takes it back, with an `{id}` slot.
    public let undo: ConnectorRequestSpec?
    public let approvalTitle: String?
    public let approvalRows: [ConnectorApprovalRow]
    public let intent: ConnectorIntentRule?
    public let keywords: [String]
    public let examples: [String]
    public let requires: [String]
    /// Read-only tools safe for scheduled briefings.
    public let briefing: Bool

    public init(name: String, title: String, description: String, isWrite: Bool = false, arguments: [ConnectorArg] = [],
                request: ConnectorRequestSpec, list: ConnectorListSpec? = nil, successText: String? = nil, createdIDPath: String? = nil,
                undo: ConnectorRequestSpec? = nil, approvalTitle: String? = nil, approvalRows: [ConnectorApprovalRow] = [],
                intent: ConnectorIntentRule? = nil, keywords: [String], examples: [String], requires: [String] = [], briefing: Bool = false) {
        self.name = name; self.title = title; self.description = description; self.isWrite = isWrite; self.arguments = arguments
        self.request = request; self.list = list; self.successText = successText; self.createdIDPath = createdIDPath; self.undo = undo
        self.approvalTitle = approvalTitle; self.approvalRows = approvalRows; self.intent = intent
        self.keywords = keywords; self.examples = examples; self.requires = requires; self.briefing = briefing
    }
}

/// Everything the app needs to know about one token connector. Written once; the switch, host list, catalog rows, requests,
/// parsing, approval card, Undo, intent, tile and privacy row are derived from it.
public struct ConnectorManifest: Sendable, Equatable {
    public let id: String
    public let title: String
    /// Apps of one non-Apple company share a tile. Equal to `id` for a single-app company.
    public let company: String
    public let category: String
    public let symbol: String
    public let brandAsset: String
    public let brandRGB: [Double]
    public let defaultOn: Bool
    public let reads: String
    public let changes: String
    /// Added after "Requests go to <host> with your own token."
    public let networkNote: String
    public let host: String
    public let headers: [String: String]
    public let tools: [ConnectorToolSpec]

    public init(id: String, title: String, company: String? = nil, category: String, symbol: String, brandAsset: String, brandRGB: [Double],
                defaultOn: Bool = false, reads: String, changes: String, networkNote: String, host: String,
                headers: [String: String] = [:], tools: [ConnectorToolSpec]) {
        self.id = id; self.title = title; self.company = company ?? id; self.category = category; self.symbol = symbol
        self.brandAsset = brandAsset; self.brandRGB = brandRGB; self.defaultOn = defaultOn; self.reads = reads; self.changes = changes
        self.networkNote = networkNote; self.host = host; self.headers = headers; self.tools = tools
    }

    public var network: String { "Requests go to \(host) with your own token. \(networkNote)" }

    public var connector: Connector {
        Connector(id: id, title: title, symbol: symbol, reads: reads, changes: changes, network: network, defaultOn: defaultOn)
    }

    public var catalogEntries: [CatalogEntry] {
        tools.map { CatalogEntry(id: $0.name, title: $0.title, category: category, description: $0.description,
                                 keywords: $0.keywords, examples: $0.examples, requires: $0.requires) }
    }

    public func tool(_ name: String) -> ConnectorToolSpec? { tools.first { $0.name == name } }
}
