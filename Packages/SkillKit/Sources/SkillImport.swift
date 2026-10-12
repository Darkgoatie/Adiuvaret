import Foundation

public enum SkillImportError: Error, Sendable, Equatable {
    case tooLarge
    case unreadable
    case missing(String)
}

/// Reads a skill from a file the user picks. Two formats: a JSON object with the AgentSkill fields, or Markdown with a
/// small header (name, description, keywords, tools between lines of three dashes) followed by the body.
/// The result is always an imported, untrusted skill; the registry still checks its tool names.
public enum SkillImport {
    public static let maxBytes = 20_000

    public static func parse(_ data: Data) throws -> AgentSkill {
        guard data.count <= maxBytes else { throw SkillImportError.tooLarge }
        guard let text = String(data: data, encoding: .utf8) else { throw SkillImportError.unreadable }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") { return try fromJSON(Data(trimmed.utf8)) }
        return try fromMarkdown(trimmed)
    }

    private struct Raw: Decodable {
        var id: String?
        var name: String?
        var description: String?
        var keywords: [String]?
        var examples: [String]?
        var body: String?
        var allowedTools: [String]?
        var tools: [String]?
        var requires: [String]?
    }

    private static func fromJSON(_ data: Data) throws -> AgentSkill {
        guard let raw = try? JSONDecoder().decode(Raw.self, from: data) else { throw SkillImportError.unreadable }
        return try build(id: raw.id, name: raw.name, description: raw.description, keywords: raw.keywords ?? [], examples: raw.examples ?? [],
                         body: raw.body, tools: raw.allowedTools ?? raw.tools ?? [], requires: raw.requires ?? [])
    }

    private static func fromMarkdown(_ text: String) throws -> AgentSkill {
        var header: [String: String] = [:]
        var body = text
        let lines = text.components(separatedBy: .newlines)
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---", let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
            for line in lines[1..<end] {
                guard let colon = line.firstIndex(of: ":") else { continue }
                let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                header[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            }
            body = lines[(end + 1)...].joined(separator: "\n")
        }
        func list(_ v: String?) -> [String] {
            (v ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "[]")).split(separator: ",")
                .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"'"))) }.filter { !$0.isEmpty }
        }
        return try build(id: header["id"], name: header["name"], description: header["description"], keywords: list(header["keywords"]),
                         examples: list(header["examples"]), body: body, tools: list(header["tools"] ?? header["allowed-tools"]), requires: list(header["requires"]))
    }

    private static func build(id: String?, name: String?, description: String?, keywords: [String], examples: [String],
                              body: String?, tools: [String], requires: [String]) throws -> AgentSkill {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { throw SkillImportError.missing("name") }
        guard let body = body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty else { throw SkillImportError.missing("body") }
        let slug = id.flatMap { $0.isEmpty ? nil : slugify($0) } ?? slugify(name)
        let desc = (description?.isEmpty == false ? description! : String(body.prefix(SkillLimits2.maxDescription)))
        return AgentSkill(id: slug, name: name, description: desc, keywords: keywords, examples: examples, body: body,
                          allowedTools: tools, requires: requires, version: 1, source: .imported, enabled: true)
    }

    public static func slugify(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        var out = ""
        var lastDash = false
        for ch in folded {
            if ch.isASCII, ch.isLetter || ch.isNumber { out.append(ch); lastDash = false }
            else if !lastDash, !out.isEmpty { out.append("-"); lastDash = true }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return String(out.prefix(40))
    }
}
