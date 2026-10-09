import Foundation

/// Questions that have a proper data source: exchange rates and football fixtures. Pure logic: the app does the requests.
public enum DirectSources {
    public enum Kind: Equatable, Sendable { case next, last }
    public enum Request: Equatable, Sendable {
        case currency(amount: Double, from: String, to: String)
        case team(name: String, kind: Kind)
    }

    public static func request(for text: String) -> Request? { currencyRequest(text) ?? teamRequest(text) }

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

    // MARK: football fixtures

    private static let matchWords: Set<String> = ["match", "matches", "game", "games", "fixture", "fixtures", "play", "plays", "playing", "score", "scores",
                                                  "result", "results", "won", "lost", "beat"]
    private static let upcomingWords: Set<String> = ["next", "upcoming", "following", "tomorrow", "tonight", "later"]
    private static let nextWords: Set<String> = ["next", "upcoming", "following", "when", "tomorrow", "tonight", "later", "kickoff"]
    private static let lastWords: Set<String> = ["last", "latest", "recent", "previous", "yesterday", "won", "lost", "beat", "result", "results", "score", "scores", "final"]
    private static let teamFillers: Set<String> = [
        "is", "does", "do", "did", "was", "were", "the", "a", "an", "of", "for", "what", "whats", "time", "date", "who", "whom", "how", "tell", "me", "give",
        "show", "find", "my", "team", "club", "football", "soccer", "vs", "against", "with", "on", "in", "at", "to", "and", "it", "this", "season", "can",
        "you", "please", "about", "their", "his", "her", "s", "i", "want", "know", "get", "are", "will", "be", "going", "there", "today", "now", "start", "starts"]
    private static let blockers: Set<String> = ["calendar", "meeting", "meetings", "reminder", "reminders", "appointment", "appointments", "schedule"]

    static func teamRequest(_ text: String) -> Request? {
        let words = text.lowercased().split(whereSeparator: { !($0.isLetter || $0.isNumber) }).map(String.init)
        guard !words.contains(where: { blockers.contains($0) }),
              words.contains(where: { matchWords.contains($0) }),
              words.contains(where: { nextWords.contains($0) || lastWords.contains($0) }) else { return nil }
        let isNext = words.contains(where: { upcomingWords.contains($0) }) || !words.contains(where: { lastWords.contains($0) })
        let name = words.filter { !teamFillers.contains($0) && !matchWords.contains($0) && !nextWords.contains($0) && !lastWords.contains($0) }
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

    private static func scoreText(_ v: Any?) -> String? {
        if let s = v as? String, !s.isEmpty { return s }
        if let n = v as? Int { return String(n) }
        return nil
    }

    private static func formatter(_ format: String, _ zone: TimeZone) -> DateFormatter {
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
