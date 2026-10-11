import Foundation

/// The built-in information sources. Each category has a few sources that were checked to answer without an account or key.
/// A source is a plain data record: where it lives, what it covers and what it sends. The app picks the user's choice first
/// and falls back to the next source in the category when it fails.
public struct InfoSource: Sendable, Equatable, Identifiable {
    public let id: String
    public let category: InfoCategory
    public let name: String
    public let host: String
    public let coverage: String
    /// What leaves the phone when this source is used.
    public let sends: String
    public let note: String

    public init(id: String, category: InfoCategory, name: String, host: String, coverage: String, sends: String, note: String = "") {
        self.id = id; self.category = category; self.name = name; self.host = host; self.coverage = coverage; self.sends = sends; self.note = note
    }
}

public enum InfoCategory: String, Sendable, CaseIterable, Identifiable {
    case weather, football, sports, news, currency, crypto, stocks, reference, holidays

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .weather: "Weather"
        case .football: "Football"
        case .sports: "Other sports"
        case .news: "News"
        case .currency: "Exchange rates"
        case .crypto: "Crypto prices"
        case .stocks: "Stocks and indices"
        case .reference: "Facts and encyclopedia"
        case .holidays: "Public holidays"
        }
    }

    public var symbol: String {
        switch self {
        case .weather: "cloud.sun"
        case .football: "soccerball"
        case .sports: "sportscourt"
        case .news: "newspaper"
        case .currency: "eurosign.circle"
        case .crypto: "bitcoinsign.circle"
        case .stocks: "chart.line.uptrend.xyaxis"
        case .reference: "book.closed"
        case .holidays: "calendar.badge.clock"
        }
    }

    public var blurb: String {
        switch self {
        case .weather: "Current conditions and the next days for a place."
        case .football: "Tables, fixtures and scores for the big leagues and European cups."
        case .sports: "Scores for basketball, American football, hockey and baseball."
        case .news: "Headlines, and news about a topic."
        case .currency: "Exchange rates between currencies."
        case .crypto: "Prices of Bitcoin, Ethereum and other coins."
        case .stocks: "Share prices and market indices."
        case .reference: "Short summaries of people, places and things."
        case .holidays: "Public holidays by country."
        }
    }
}

public enum InfoSources {
    /// The first source of each category is the default. All of these answered a real request without an account when they were added.
    public static let all: [InfoSource] = [
        InfoSource(id: "open-meteo", category: .weather, name: "Open-Meteo", host: "api.open-meteo.com", coverage: "Worldwide, 4-day forecast",
                   sends: "The place name and its coordinates.", note: "Free for non-commercial use."),
        InfoSource(id: "met-norway", category: .weather, name: "MET Norway", host: "api.met.no", coverage: "Worldwide, 3-day forecast",
                   sends: "The place coordinates.", note: "The Norwegian meteorological institute."),

        InfoSource(id: "espn-football", category: .football, name: "ESPN", host: "site.api.espn.com", coverage: "Full tables for 10 leagues and the three European cups, and the next matchday",
                   sends: "The league code."),
        InfoSource(id: "thesportsdb", category: .football, name: "TheSportsDB", host: "www.thesportsdb.com", coverage: "Fixtures and results for leagues, cups and single teams. Latest results and team questions always use it.",
                   sends: "The league or team name.", note: "Free tier: its tables list only the top 5, so tables always come from ESPN."),

        InfoSource(id: "espn-sports", category: .sports, name: "ESPN", host: "site.api.espn.com", coverage: "Live scores and today's games for the NBA, NFL, NHL and MLB",
                   sends: "The sport and league code."),

        InfoSource(id: "bbc-rss", category: .news, name: "BBC News", host: "feeds.bbci.co.uk", coverage: "World headlines",
                   sends: "Nothing but the request for the feed."),
        InfoSource(id: "guardian-rss", category: .news, name: "The Guardian", host: "www.theguardian.com", coverage: "World headlines",
                   sends: "Nothing but the request for the feed."),
        InfoSource(id: "npr-rss", category: .news, name: "NPR", host: "feeds.npr.org", coverage: "US and world headlines",
                   sends: "Nothing but the request for the feed."),
        InfoSource(id: "google-news", category: .news, name: "Google News", host: "news.google.com", coverage: "News about any topic you name",
                   sends: "Your topic words.", note: "The only news source here that searches by topic."),

        InfoSource(id: "frankfurter", category: .currency, name: "Frankfurter (ECB)", host: "api.frankfurter.dev", coverage: "About 30 major currencies, daily",
                   sends: "The currency codes and amount."),
        InfoSource(id: "open-er", category: .currency, name: "ExchangeRate-API", host: "open.er-api.com", coverage: "About 160 currencies, daily",
                   sends: "The base currency."),

        InfoSource(id: "coinbase", category: .crypto, name: "Coinbase", host: "api.coinbase.com", coverage: "Major coins in USD, EUR, TRY and more",
                   sends: "The coin and currency codes."),
        InfoSource(id: "coingecko", category: .crypto, name: "CoinGecko", host: "api.coingecko.com", coverage: "Thousands of coins with the 24-hour change",
                   sends: "The coin and currency names.", note: "Rate limited on the free tier."),

        InfoSource(id: "yahoo-finance", category: .stocks, name: "Yahoo Finance", host: "query1.finance.yahoo.com", coverage: "Shares, indices and ETFs worldwide",
                   sends: "The ticker symbol.", note: "An unofficial feed; it can change without notice."),

        InfoSource(id: "wikipedia", category: .reference, name: "Wikipedia", host: "en.wikipedia.org", coverage: "Summaries of people, places and things",
                   sends: "The name you asked about."),
        InfoSource(id: "duckduckgo", category: .reference, name: "DuckDuckGo", host: "api.duckduckgo.com", coverage: "Short instant answers",
                   sends: "The name you asked about.", note: "Often has no answer for less known topics."),

        InfoSource(id: "nager", category: .holidays, name: "Nager.Date", host: "date.nager.at", coverage: "Public holidays for about 200 countries",
                   sends: "The country code and year.")
    ]

    public static func sources(_ category: InfoCategory) -> [InfoSource] { all.filter { $0.category == category } }
    public static func source(_ id: String) -> InfoSource? { all.first { $0.id == id } }
    public static func defaultSource(_ category: InfoCategory) -> InfoSource { sources(category)[0] }

    /// The user's choices first, then the rest of the category in catalog order. A saved id that no longer exists is ignored.
    public static func order(for category: InfoCategory, preferred: String?) -> [InfoSource] {
        let list = sources(category)
        guard let preferred, let first = list.first(where: { $0.id == preferred }) else { return list }
        return [first] + list.filter { $0.id != preferred }
    }

    /// Every host a source may contact. Used to refuse a request to any other address.
    public static func isAllowed(_ url: URL, source: InfoSource) -> Bool {
        url.scheme == "https" && url.host?.lowercased() == source.host && url.port == nil && url.user == nil && url.password == nil
    }
}

/// The user's preferred source per category, stored on the phone only.
public struct SourcePreferences: Sendable, Equatable {
    private var chosen: [String: String]

    public init(chosen: [String: String] = [:]) { self.chosen = chosen }

    public func preferred(_ category: InfoCategory) -> String? { chosen[category.rawValue] }

    /// The id the user sees as selected: their pick when valid, else the default.
    public func selected(_ category: InfoCategory) -> InfoSource {
        InfoSources.order(for: category, preferred: preferred(category))[0]
    }

    public mutating func choose(_ id: String, for category: InfoCategory) {
        guard let s = InfoSources.source(id), s.category == category else { return }
        chosen[category.rawValue] = id
    }

    public mutating func reset(_ category: InfoCategory) { chosen[category.rawValue] = nil }
    public mutating func resetAll() { chosen = [:] }
    public var isDefault: Bool { chosen.isEmpty }
    public var raw: [String: String] { chosen }
}
