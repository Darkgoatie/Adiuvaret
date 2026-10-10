import Foundation

/// Decides whether the pages read so far answer the question, and what to search for next if they do not.
public enum SearchLoop {
    public static let maxRounds = 3

    /// Share of the question's key words that appear in the page text.
    public static func coverage(query: String, excerpts: [String]) -> Double {
        let terms = PageExtract.terms(query)
        guard !terms.isEmpty else { return excerpts.isEmpty ? 0 : 1 }
        let text = excerpts.joined(separator: " ").lowercased()
        return Double(terms.filter { text.contains($0) }.count) / Double(terms.count)
    }

    public static func isEnough(query: String, excerpts: [String]) -> Bool {
        let text = excerpts.joined(separator: " ")
        return text.count >= 80 && coverage(query: query, excerpts: excerpts) >= 0.6
    }

    /// Words for the next round. Round 2 adds the year for fresh pages, round 3 asks for official sources.
    public static func refine(_ query: String, round: Int, year: Int) -> String? {
        let base = WebSearch.queryFrom(query)
        switch round {
        case 2: return base.contains(String(year)) ? base + " latest" : base + " " + String(year)
        case 3: return base + " official"
        default: return nil
        }
    }
}
