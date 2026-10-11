import Foundation

/// League tables from ESPN's public standings feed. Pure logic: the app does the request.
public enum Standings {
    public struct Request: Equatable, Sendable {
        public let code: String
        public let name: String
        public let wantsChart: Bool
    }

    /// Longer names first so "europa conference league" is not read as "europa league".
    static let leagues: [(names: [String], code: String, title: String)] = [
        (["champions league", "ucl"], "uefa.champions", "UEFA Champions League"),
        (["europa conference league", "conference league", "uecl"], "uefa.europa.conf", "UEFA Conference League"),
        (["europa league", "uel"], "uefa.europa", "UEFA Europa League"),
        (["premier league", "epl"], "eng.1", "English Premier League"),
        (["la liga", "laliga"], "esp.1", "La Liga"),
        (["bundesliga"], "ger.1", "Bundesliga"),
        (["serie a"], "ita.1", "Serie A"),
        (["ligue 1"], "fra.1", "Ligue 1"),
        (["super lig", "süper lig", "super lik"], "tur.1", "Süper Lig"),
        (["eredivisie"], "ned.1", "Eredivisie"),
        (["primeira liga"], "por.1", "Primeira Liga")]

    private static let tableWords: Set<String> = ["table", "standings", "standing", "ranking", "rankings", "leaderboard", "positions"]
    private static let chartWords: Set<String> = ["chart", "graph", "plot", "bar", "diagram"]
    private static let blockers: Set<String> = ["fixtures", "fixture", "schedule", "next", "when", "tomorrow", "tonight", "kickoff", "played", "result", "results", "score", "scores"]

    /// "la liga table", "show the premier league standings as a bar chart", "Süper Lig puan durumu".
    public static func request(for text: String) -> Request? {
        let words = text.lowercased().split(whereSeparator: { !($0.isLetter || $0.isNumber) }).map(String.init)
        let padded = " " + words.joined(separator: " ") + " "
        let turkish = padded.contains(" puan durumu ") || padded.contains(" puan tablosu ")
        guard words.contains(where: { tableWords.contains($0) }) || turkish || (words.contains(where: { chartWords.contains($0) }) && padded.contains(" table ")) else { return nil }
        guard !words.contains(where: { blockers.contains($0) }) else { return nil }
        guard let league = leagues.first(where: { l in l.names.contains { padded.contains(" " + $0 + " ") } }) else { return nil }
        return Request(code: league.code, name: league.title, wantsChart: words.contains(where: { chartWords.contains($0) }))
    }

    public static func url(code: String) -> URL? {
        guard code.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." }), !code.isEmpty else { return nil }
        return URL(string: "https://site.api.espn.com/apis/v2/sports/soccer/\(code)/standings")
    }

    public struct Row: Equatable, Sendable {
        public let rank: Int
        public let team: String
        public let played: Int
        public let won: Int
        public let drawn: Int
        public let lost: Int
        public let goalsFor: Int
        public let goalsAgainst: Int
        public let points: Int
    }

    public static func rows(_ data: Data) -> (season: String, rows: [Row])? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let group = (o["children"] as? [[String: Any]])?.first,
              let standings = group["standings"] as? [String: Any], let entries = standings["entries"] as? [[String: Any]], !entries.isEmpty else { return nil }
        var out: [Row] = []
        for e in entries {
            guard let team = (e["team"] as? [String: Any])?["displayName"] as? String, let stats = e["stats"] as? [[String: Any]] else { continue }
            func v(_ name: String) -> Int? {
                guard let s = stats.first(where: { ($0["name"] as? String) == name }), let n = s["value"] as? Double else { return nil }
                return Int(n)
            }
            guard let rank = v("rank"), let played = v("gamesPlayed"), let points = v("points") else { continue }
            out.append(Row(rank: rank, team: team, played: played, won: v("wins") ?? 0, drawn: v("ties") ?? 0, lost: v("losses") ?? 0,
                           goalsFor: v("pointsFor") ?? 0, goalsAgainst: v("pointsAgainst") ?? 0, points: points))
        }
        guard !out.isEmpty else { return nil }
        let season = (standings["seasonDisplayName"] as? String) ?? (group["name"] as? String) ?? ""
        return (season, out.sorted { $0.rank < $1.rank })
    }

    /// Text for the model and the chat: a source line and a markdown table. The model is told to show it as is.
    public static func render(_ data: Data, name: String, wantsChart: Bool) -> String? {
        guard let (season, rows) = rows(data) else { return nil }
        var lines = ["\(name) table, \(season) (ESPN). Show this table to the user exactly as written, do not change any number."]
        lines.append("| # | Team | P | W | D | L | GF | GA | Pts |")
        lines.append("|---|---|---|---|---|---|---|---|---|")
        for r in rows { lines.append("| \(r.rank) | \(r.team) | \(r.played) | \(r.won) | \(r.drawn) | \(r.lost) | \(r.goalsFor) | \(r.goalsAgainst) | \(r.points) |") }
        if wantsChart {
            lines.append("")
            lines.append("The user asked for a chart. Add this block after the table, unchanged:")
            lines.append("```chart")
            lines.append("type: bar")
            lines.append("title: \(name) points")
            lines.append("team,points")
            for r in rows.prefix(RichChart.maxRows) { lines.append("\(r.team),\(r.points)") }
            lines.append("```")
        }
        return lines.joined(separator: "\n")
    }
}

enum RichChart { static let maxRows = 20 }
