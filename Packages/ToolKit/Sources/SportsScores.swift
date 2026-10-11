import Foundation

/// Live scores and today's games for basketball, American football, hockey and baseball, from ESPN's public scoreboard. Team sports only: tennis, Formula 1 and MMA use a different shape.
public enum SportsScores {
    public struct Request: Equatable, Sendable {
        public let path: String
        public let name: String
    }

    static let sports: [(names: [String], path: String, title: String)] = [
        (["nba", "basketball"], "basketball/nba", "NBA"),
        (["nfl", "american football"], "football/nfl", "NFL"),
        (["nhl", "hockey", "ice hockey"], "hockey/nhl", "NHL"),
        (["mlb", "baseball"], "baseball/mlb", "MLB")]

    private static let askWords: Set<String> = ["score", "scores", "result", "results", "game", "games", "match", "matches", "schedule", "today", "tonight", "playing", "live", "fixtures", "fixture"]
    private static let blockers: Set<String> = ["standings", "table", "ranking", "rankings", "history", "won", "winner", "champion", "champions", "season", "calendar", "reminder"]

    /// "nba scores", "NFL games today", "f1 schedule".
    public static func request(for text: String) -> Request? {
        let words = text.lowercased().split(whereSeparator: { !($0.isLetter || $0.isNumber) }).map(String.init)
        guard words.contains(where: { askWords.contains($0) }), !words.contains(where: { blockers.contains($0) }) else { return nil }
        let padded = " " + words.joined(separator: " ") + " "
        guard let s = sports.first(where: { sp in sp.names.contains { padded.contains(" " + $0 + " ") } }) else { return nil }
        return Request(path: s.path, name: s.title)
    }

    public static func url(path: String) -> URL? {
        guard sports.contains(where: { $0.path == path }) else { return nil }
        return URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(path)/scoreboard")
    }

    public static func render(_ data: Data, name: String, timeZone: TimeZone = .current) -> String? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let events = o["events"] as? [[String: Any]], !events.isEmpty else { return nil }
        let when = DateFormatter(); when.timeZone = timeZone; when.locale = Locale(identifier: "en_US_POSIX"); when.dateFormat = "EEE d MMM HH:mm"
        let parser = DateFormatter(); parser.timeZone = TimeZone(identifier: "UTC"); parser.locale = Locale(identifier: "en_US_POSIX"); parser.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        var lines: [String] = []
        for e in events.prefix(12) {
            guard let title = e["name"] as? String else { continue }
            let status = ((e["status"] as? [String: Any])?["type"] as? [String: Any])
            let state = status?["state"] as? String ?? ""
            let detail = status?["shortDetail"] as? String ?? (status?["description"] as? String) ?? ""
            let comps = ((e["competitions"] as? [[String: Any]])?.first?["competitors"] as? [[String: Any]]) ?? []
            func team(_ side: String) -> (String, String)? {
                guard let c = comps.first(where: { ($0["homeAway"] as? String) == side }),
                      let n = ((c["team"] as? [String: Any])?["displayName"] as? String) ?? ((c["athlete"] as? [String: Any])?["displayName"] as? String) else { return nil }
                return (n, (c["score"] as? String) ?? "")
            }
            var line: String
            if let home = team("home"), let away = team("away") {
                switch state {
                case "pre":
                    let t = (e["date"] as? String).flatMap { parser.date(from: $0) }.map { when.string(from: $0) } ?? ""
                    line = "\(away.0) at \(home.0), \(t)"
                default:
                    line = "\(away.0) \(away.1)-\(home.1) \(home.0), \(detail)"
                }
            } else {
                line = title + (detail.isEmpty ? "" : ", \(detail)")
            }
            lines.append(line)
        }
        guard !lines.isEmpty else { return nil }
        return (["\(name) on ESPN right now (use these exactly, say where they come from):"] + lines.enumerated().map { "\($0.offset + 1). \($0.element)" }).joined(separator: "\n")
    }
}
