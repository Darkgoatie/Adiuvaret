import Foundation

/// Questions that have a proper data source: exchange rates and football fixtures. Pure logic: the app does the requests.
public enum DirectSources {
    public enum Kind: Equatable, Sendable { case next, last }
    public enum Request: Equatable, Sendable {
        case currency(amount: Double, from: String, to: String)
        case team(name: String, kind: Kind)
        case competition(id: String, name: String, kind: Kind)
    }

    public static func request(for text: String) -> Request? { currencyRequest(text) ?? competitionRequest(text) ?? teamRequest(text) }

    // MARK: currency

    private static let currencies: [String: String] = [
        "usd": "USD", "dollar": "USD", "dollars": "USD", "eur": "EUR", "euro": "EUR", "euros": "EUR", "try": "TRY", "lira": "TRY",
        "gbp": "GBP", "pound": "GBP", "pounds": "GBP", "sterling": "GBP", "jpy": "JPY", "yen": "JPY", "cad": "CAD", "aud": "AUD",
        "chf": "CHF", "franc": "CHF", "francs": "CHF", "cny": "CNY", "yuan": "CNY", "rmb": "CNY", "inr": "INR", "rupee": "INR", "rupees": "INR",
        "brl": "BRL", "mxn": "MXN", "sek": "SEK", "nok": "NOK", "dkk": "DKK", "pln": "PLN", "zloty": "PLN", "czk": "CZK", "huf": "HUF",
        "forint": "HUF", "krw": "KRW", "zar": "ZAR", "rand": "ZAR", "nzd": "NZD", "sgd": "SGD", "hkd": "HKD", "ils": "ILS", "thb": "THB",
        "idr": "IDR", "myr": "MYR", "php": "PHP", "ron": "RON", "bgn": "BGN", "isk": "ISK"]

    static func currencyRequest(_ text: String) -> Request? {
        let cleaned = text.lowercased().replacingOccurrences(of: "(?<=[0-9]),(?=[0-9])", with: "", options: .regularExpression)
        let words = cleaned.split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == ".") })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }.filter { !$0.isEmpty }
        var found: [String] = []
        for w in words { if let code = currencies[w] { found.append(code) } }
        guard let first = found.first, found.contains(where: { $0 != first }) else { return nil }
        var amount = 1.0
        var from = first
        for i in 0..<(words.count - 1) {
            if let n = Double(words[i]), n > 0, let code = currencies[words[i + 1]] { amount = n; from = code; break }
        }
        guard let to = found.first(where: { $0 != from }) else { return nil }
        return .currency(amount: amount, from: from, to: to)
    }

    public static func currencyURL(amount: Double, from: String, to: String) -> URL? {
        guard amount > 0, amount < 1e12 else { return nil }
        var parts = URLComponents(string: "https://api.frankfurter.dev/v1/latest")
        parts?.queryItems = [URLQueryItem(name: "amount", value: amount == amount.rounded() ? String(Int(amount)) : String(amount)),
                             URLQueryItem(name: "base", value: from), URLQueryItem(name: "symbols", value: to)]
        return parts?.url
    }

    static func num(_ v: Double) -> String { abs(v) >= 1 ? String(format: "%.2f", v) : String(format: "%.4f", v) }

    public static func renderCurrency(_ data: Data, amount: Double, from: String, to: String) -> String? {
        guard amount > 0, let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rates = o["rates"] as? [String: Any],
              let value = (rates[to] as? Double) ?? (rates[to] as? Int).map(Double.init) else { return nil }
        let date = (o["date"] as? String) ?? ""
        return "Live exchange rate (European Central Bank via Frankfurter, \(date)): \(num(amount)) \(from) = \(num(value)) \(to). 1 \(from) = \(num(value / amount)) \(to)."
    }

    // MARK: competitions

    /// Competitions that have a fixture list in TheSportsDB. Longer names come first so "europa conference league" is not read as "europa league".
    static let competitions: [(names: [String], id: String, title: String)] = [
        (["champions league", "ucl"], "4480", "UEFA Champions League"),
        (["europa league", "uel"], "4481", "UEFA Europa League"),
        (["premier league", "epl"], "4328", "English Premier League"),
        (["la liga", "laliga"], "4335", "La Liga"),
        (["bundesliga"], "4331", "Bundesliga"),
        (["serie a"], "4332", "Serie A"),
        (["ligue 1"], "4334", "Ligue 1"),
        (["super lig", "süper lig"], "4339", "Süper Lig"),
        (["eredivisie"], "4337", "Eredivisie"),
        (["primeira liga"], "4344", "Primeira Liga"),
        (["mls", "major league soccer"], "4346", "Major League Soccer"),
        (["fa cup"], "4482", "FA Cup"),
        (["world cup"], "4429", "FIFA World Cup")]

    static let competitionWords: Set<String> = Set(competitions.flatMap(\.names).flatMap { $0.split(separator: " ").map(String.init) })
        .union(["uefa", "european", "league", "english", "spanish", "german", "italian", "french", "turkish", "dutch", "portuguese"])
    static let timeWords: Set<String> = ["weekend", "week", "month", "stage", "leg", "round", "midweek", "saturday", "sunday", "friday", "monday", "tuesday", "wednesday", "thursday"]

    private static let roundWords: Set<String> = ["matchday", "matchdays", "round", "fixtures", "fixture", "match", "matches", "game", "games", "schedule", "results", "result", "scores", "score", "play", "plays", "playing", "tonight", "today", "tomorrow", "next", "upcoming", "last", "latest", "when", "yesterday", "who", "won", "lost", "beat", "draw"]

    static func competitionRequest(_ text: String) -> Request? {
        let words = text.lowercased().split(whereSeparator: { !($0.isLetter || $0.isNumber) }).map(String.init)
        guard !words.contains(where: { blockers.contains($0) }), words.contains(where: { roundWords.contains($0) }) else { return nil }
        let padded = " " + words.joined(separator: " ") + " "
        guard !padded.contains(" conference league ") else { return nil }
        guard let comp = competitions.first(where: { c in c.names.contains { padded.contains(" " + $0 + " ") } }) else { return nil }
        // A question that names a team as well ("Real Madrid in the Champions League") is about that team, so the team lookup handles it.
        let leftover = words.filter { !teamFillers.contains($0) && !roundWords.contains($0) && !competitionWords.contains($0) && !lastWords.contains($0) && !nextWords.contains($0) && !timeWords.contains($0) }
        guard leftover.isEmpty else { return nil }
        let isLast = words.contains(where: { lastWords.contains($0) }) && !words.contains(where: { upcomingWords.contains($0) })
        return .competition(id: comp.id, name: comp.title, kind: isLast ? .last : .next)
    }

    /// The days to ask for: today and the following days for upcoming games, yesterday and the days before for results.
    public static func competitionDayURLs(id: String, kind: Kind, now: Date = Date(), timeZone: TimeZone = .current) -> [URL] {
        guard id.allSatisfy(\.isNumber), !id.isEmpty else { return [] }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        let f = formatter("yyyy-MM-dd", timeZone)
        let offsets = kind == .next ? Array(0...9) : Array((1...7).map { -$0 })
        return offsets.compactMap { o in
            cal.date(byAdding: .day, value: o, to: now).flatMap { URL(string: "https://www.thesportsdb.com/api/v1/json/3/eventsday.php?d=\(f.string(from: $0))&l=\(id)") }
        }
    }

    /// The first day that has matches, with every match that day: one matchday.
    public static func renderCompetition(days: [Data], name: String, kind: Kind, timeZone: TimeZone = .current) -> String? {
        struct Row { let date: Date; let line: String }
        let utc = TimeZone(identifier: "UTC") ?? timeZone
        let stamp = formatter("yyyy-MM-dd'T'HH:mm:ss", utc)
        let when = formatter("EEE d MMM HH:mm", timeZone)
        let dayKey = formatter("yyyy-MM-dd", timeZone)
        var byDay: [String: [Row]] = [:]
        for data in days {
            guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let events = o["events"] as? [[String: Any]] else { continue }
            for e in events {
                guard let title = e["strEvent"] as? String, let ts = (e["strTimestamp"] as? String).flatMap({ stamp.date(from: $0) }) else { continue }
                var line = title + ", " + when.string(from: ts)
                if kind == .last {
                    if let h = scoreText(e["intHomeScore"]), let a = scoreText(e["intAwayScore"]), let home = e["strHomeTeam"] as? String, let away = e["strAwayTeam"] as? String {
                        line = "\(home) \(h)-\(a) \(away), " + when.string(from: ts)
                    } else {
                        line += ", score not recorded"
                    }
                }
                if let r = e["intRound"] as? String, !r.isEmpty, byDay[dayKey.string(from: ts)] == nil { line += " (round \(r))" }
                byDay[dayKey.string(from: ts), default: []].append(Row(date: ts, line: line))
            }
        }
        guard !byDay.isEmpty else { return nil }
        let keys = byDay.keys.sorted()
        let first = kind == .next ? keys.first! : keys.last!
        var rows = byDay[first] ?? []
        if kind == .next, keys.count > 1 { rows += byDay[keys[1]] ?? [] }
        rows.sort { $0.date < $1.date }
        let head = kind == .next
            ? "Upcoming \(name) matches (TheSportsDB, times in \(timeZone.identifier)):"
            : "Latest \(name) results (TheSportsDB, times in \(timeZone.identifier)):"
        return ([head] + rows.prefix(24).enumerated().map { "\($0.offset + 1). \($0.element.line)" }).joined(separator: "\n")
    }

    // MARK: football fixtures

    private static let matchWords: Set<String> = ["match", "matches", "game", "games", "fixture", "fixtures", "play", "plays", "playing", "score", "scores",
                                                  "result", "results", "won", "lost", "beat"]
    static let upcomingWords: Set<String> = ["next", "upcoming", "following", "tomorrow", "tonight", "later"]
    static let nextWords: Set<String> = ["next", "upcoming", "following", "when", "tomorrow", "tonight", "later", "kickoff"]
    static let lastWords: Set<String> = ["last", "latest", "recent", "previous", "yesterday", "won", "lost", "beat", "result", "results", "score", "scores", "final"]
    static let teamFillers: Set<String> = [
        "is", "does", "do", "did", "was", "were", "the", "a", "an", "of", "for", "what", "whats", "time", "date", "who", "whom", "how", "tell", "me", "give",
        "show", "find", "my", "team", "club", "football", "soccer", "vs", "against", "with", "on", "in", "at", "to", "and", "it", "this", "season", "can",
        "you", "please", "about", "their", "his", "her", "s", "i", "want", "know", "get", "are", "will", "be", "going", "there", "today", "now", "start", "starts"]
    static let blockers: Set<String> = ["calendar", "meeting", "meetings", "reminder", "reminders", "appointment", "appointments", "schedule"]

    static func teamRequest(_ text: String) -> Request? {
        let words = text.lowercased().split(whereSeparator: { !($0.isLetter || $0.isNumber) }).map(String.init)
        guard !words.contains(where: { blockers.contains($0) }),
              words.contains(where: { matchWords.contains($0) }),
              words.contains(where: { nextWords.contains($0) || lastWords.contains($0) }) else { return nil }
        let isNext = words.contains(where: { upcomingWords.contains($0) }) || !words.contains(where: { lastWords.contains($0) })
        // A year or a tournament word means a history or event question, not a team lookup.
        let eventWords: Set<String> = ["cup", "world", "olympics", "olympic", "euro", "final", "finals", "tournament", "championship"]
        if words.contains(where: { eventWords.contains($0) || ($0.count == 4 && $0.hasPrefix("20") && $0.allSatisfy(\.isNumber)) || ($0.count == 4 && $0.hasPrefix("19") && $0.allSatisfy(\.isNumber)) }) { return nil }
        let name = words.filter { !teamFillers.contains($0) && !matchWords.contains($0) && !nextWords.contains($0) && !lastWords.contains($0) && !competitionWords.contains($0) }
            .prefix(4).joined(separator: " ")
        return name.isEmpty ? nil : .team(name: name, kind: isNext ? .next : .last)
    }

    public static func teamSearchURL(_ name: String) -> URL? {
        var parts = URLComponents(string: "https://www.thesportsdb.com/api/v1/json/3/searchteams.php")
        parts?.queryItems = [URLQueryItem(name: "t", value: name)]
        return parts?.url
    }

    public static func parseTeam(_ data: Data) -> (id: String, name: String)? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (o["teams"] as? [[String: Any]])?.first,
              let id = first["idTeam"] as? String, let name = first["strTeam"] as? String else { return nil }
        return (id, name)
    }

    public static func eventsURL(teamID: String, kind: Kind) -> URL? {
        guard teamID.allSatisfy(\.isNumber), !teamID.isEmpty else { return nil }
        return URL(string: "https://www.thesportsdb.com/api/v1/json/3/" + (kind == .next ? "eventsnext" : "eventslast") + ".php?id=" + teamID)
    }

    static func scoreText(_ v: Any?) -> String? {
        if let s = v as? String, !s.isEmpty { return s }
        if let n = v as? Int { return String(n) }
        return nil
    }

    static func formatter(_ format: String, _ zone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone; f.dateFormat = format
        return f
    }

    public static func renderEvents(_ data: Data, team: String, kind: Kind, timeZone: TimeZone = .current) -> String? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = (o["events"] as? [[String: Any]]) ?? (o["results"] as? [[String: Any]]), !raw.isEmpty else { return nil }
        let utc = TimeZone(identifier: "UTC") ?? timeZone
        let stamp = formatter("yyyy-MM-dd'T'HH:mm:ss", utc)
        let dayOnly = formatter("yyyy-MM-dd", utc)
        let withTime = formatter("EEE d MMM yyyy HH:mm", timeZone)
        let dayText = formatter("EEE d MMM yyyy", utc)
        var rows: [(date: Date, line: String)] = []
        for e in raw {
            guard let title = e["strEvent"] as? String, !title.isEmpty else { continue }
            let timed = (e["strTimestamp"] as? String).flatMap { stamp.date(from: $0) }
            guard let date = timed ?? (e["dateEvent"] as? String).flatMap({ dayOnly.date(from: $0) }) else { continue }
            var shown = timed != nil ? withTime.string(from: date) : dayText.string(from: date)
            if timed == nil, kind == .next { shown += " (time not listed)" }
            var line: String
            if kind == .last {
                if let h = scoreText(e["intHomeScore"]), let a = scoreText(e["intAwayScore"]),
                   let home = e["strHomeTeam"] as? String, let away = e["strAwayTeam"] as? String {
                    line = "\(home) \(h)-\(a) \(away), \(shown)"
                } else {
                    line = "\(title), \(shown), score not recorded"
                }
            } else {
                line = "\(title), \(shown)"
            }
            if let league = e["strLeague"] as? String, !league.isEmpty { line += ", \(league)" }
            rows.append((date, line))
        }
        guard !rows.isEmpty else { return nil }
        rows.sort { kind == .next ? $0.date < $1.date : $0.date > $1.date }
        let head = kind == .next
            ? "Upcoming matches for \(team) (TheSportsDB, times in \(timeZone.identifier); a competition missing here may just not be covered):"
            : "Latest results for \(team) (TheSportsDB, newest first):"
        return ([head] + rows.prefix(3).enumerated().map { "\($0.offset + 1). \($0.element.line)" }).joined(separator: "\n")
    }
}
