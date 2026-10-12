import Foundation

/// Reads the skills.json that the first skill store (task 40) wrote and turns each entry into a learned skill.
/// The old file is only read, never changed.
public enum SkillMigration {
    private struct Legacy: Decodable {
        let id: UUID
        let title: String
        let whenToUse: String
        let playbook: String
        let enabled: Bool
    }

    /// labelToTool maps a playbook step label ("Check the calendar") back to its tool id, so the learned skill keeps its tools.
    public static func learnedSkills(from data: Data, labelToTool: [String: String]) -> [AgentSkill] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let old = try? decoder.decode([Legacy].self, from: data) else { return [] }
        return old.map { l in
            var found: [(position: Int, tool: String)] = []
            for (label, tool) in labelToTool {
                if let r = l.playbook.range(of: label) { found.append((l.playbook.distance(from: l.playbook.startIndex, to: r.lowerBound), tool)) }
            }
            let tools = found.sorted { $0.position < $1.position }.map(\.tool)
            return AgentSkill(id: learnedID(l.id), name: l.title, description: l.whenToUse.isEmpty ? l.title : l.whenToUse,
                              keywords: SkillTerms.terms(l.title), examples: [l.title], body: l.playbook,
                              allowedTools: tools, version: 1, source: .learned, enabled: l.enabled)
        }
    }

    public static func learnedID(_ uuid: UUID) -> String {
        "learned-" + String(uuid.uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12))
    }
}
