import Foundation
import Observation
import ToolKit
import Diagnostics

/// The user's preferred source per category. Stored on the phone only; nothing here is sent anywhere.
@MainActor @Observable
final class SourceSettings {
    static let shared = SourceSettings()
    nonisolated private static let key = "settings.sourcePreferences"

    private(set) var preferences: SourcePreferences

    private init() {
        let saved = UserDefaults.standard.dictionary(forKey: Self.key) as? [String: String] ?? [:]
        preferences = SourcePreferences(chosen: saved)
    }

    func selected(_ category: InfoCategory) -> InfoSource { preferences.selected(category) }
    func choose(_ id: String, for category: InfoCategory) { preferences.choose(id, for: category); save() }
    func reset(_ category: InfoCategory) { preferences.reset(category); save() }
    func resetAll() { preferences.resetAll(); save() }

    private func save() { UserDefaults.standard.set(preferences.raw, forKey: Self.key) }

    /// Readable from the tool executors, which do not run on the main actor.
    nonisolated static func order(for category: InfoCategory) -> [InfoSource] {
        let saved = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        return InfoSources.order(for: category, preferred: saved[category.rawValue])
    }
}

/// Fetches from the built-in sources in the user's order. The first one that answers wins; a failed one is logged by id only.
enum InfoFetcher {
    private static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.httpCookieStorage = nil
        config.urlCache = nil
        return URLSession(configuration: config)
    }

    private static func get(_ url: URL?, source: InfoSource, _ session: URLSession) async -> Data? {
        guard let url, InfoSources.isAllowed(url, source: source) else { return nil }
        var request = URLRequest(url: url)
        request.setValue(source.id == "met-norway" ? "Adiuvaret/0.2 github.com/Darkgoatie/Adiuvaret" : WebSearch.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, application/xml, text/xml, */*", forHTTPHeaderField: "Accept")
        guard let result = try? await session.data(for: request), (result.1 as? HTTPURLResponse)?.statusCode == 200, result.0.count < 2_000_000 else { return nil }
        return result.0
    }

    private static func log(_ category: InfoCategory, _ source: InfoSource, _ ok: Bool) {
        DiagnosticsLog.shared.record("source", "\(category.rawValue) \(source.id) \(ok ? "ok" : "failed")")
    }

    /// Weather: the user's source first, the other one if it fails.
    static func weather(place: Weather.Place) async -> String? {
        let s = session(); defer { s.finishTasksAndInvalidate() }
        let fahrenheit = Locale.current.measurementSystem == .us
        for source in SourceSettings.order(for: .weather) {
            var text: String?
            switch source.id {
            case "met-norway":
                if let data = await get(InfoFeeds.metURL(latitude: place.latitude, longitude: place.longitude), source: source, s) {
                    text = InfoFeeds.renderMET(data, place: place.label, fahrenheit: fahrenheit)
                }
            default:
                if let data = await get(Weather.forecastURL(place, fahrenheit: fahrenheit), source: source, s) { text = Weather.render(data, place: place) }
            }
            log(.weather, source, text != nil)
            if let text { return text }
        }
        return nil
    }

    static func currency(amount: Double, from: String, to: String) async -> String? {
        let s = session(); defer { s.finishTasksAndInvalidate() }
        for source in SourceSettings.order(for: .currency) {
            var text: String?
            switch source.id {
            case "open-er":
                if let data = await get(InfoFeeds.erURL(base: from), source: source, s) { text = InfoFeeds.renderER(data, amount: amount, from: from, to: to) }
            default:
                if let data = await get(DirectSources.currencyURL(amount: amount, from: from, to: to), source: source, s) {
                    text = DirectSources.renderCurrency(data, amount: amount, from: from, to: to)
                }
            }
            log(.currency, source, text != nil)
            if let text { return text }
        }
        return nil
    }

    static func crypto(_ request: InfoFeeds.CryptoRequest) async -> String? {
        let s = session(); defer { s.finishTasksAndInvalidate() }
        for source in SourceSettings.order(for: .crypto) {
            var text: String?
            switch source.id {
            case "coingecko":
                if let data = await get(InfoFeeds.geckoURL(id: request.gecko, fiat: request.fiat), source: source, s) { text = InfoFeeds.renderGecko(data, request: request) }
            default:
                if let data = await get(InfoFeeds.coinbaseURL(symbol: request.symbol, fiat: request.fiat), source: source, s) { text = InfoFeeds.renderCoinbase(data, request: request) }
            }
            log(.crypto, source, text != nil)
            if let text { return text }
        }
        return nil
    }

    /// The next football matchday from ESPN, only when the user's first football source is ESPN. The caller falls back to TheSportsDB.
    static func footballNext(title: String) async -> String? {
        guard SourceSettings.order(for: .football).first?.id == "espn-football", let code = Standings.code(forTitle: title),
              let source = InfoSources.source("espn-football") else { return nil }
        let s = session(); defer { s.finishTasksAndInvalidate() }
        let text = await get(Standings.scoreboardURL(code: code), source: source, s).flatMap { SportsScores.render($0, name: title) }
        log(.football, source, text != nil)
        return text
    }

    static func sports(_ request: SportsScores.Request) async -> String? {
        let s = session(); defer { s.finishTasksAndInvalidate() }
        guard let source = InfoSources.sources(.sports).first else { return nil }
        let text = await get(SportsScores.url(path: request.path), source: source, s).flatMap { SportsScores.render($0, name: request.name) }
        log(.sports, source, text != nil)
        return text
    }

    static func stock(_ request: InfoFeeds.StockRequest) async -> String? {
        let s = session(); defer { s.finishTasksAndInvalidate() }
        guard let source = InfoSources.sources(.stocks).first else { return nil }
        let text = await get(InfoFeeds.yahooURL(symbol: request.symbol), source: source, s).flatMap { InfoFeeds.renderYahoo($0, request: request) }
        log(.stocks, source, text != nil)
        return text
    }

    static func reference(subject: String) async -> String? {
        let s = session(); defer { s.finishTasksAndInvalidate() }
        for source in SourceSettings.order(for: .reference) {
            var text: String?
            switch source.id {
            case "duckduckgo":
                if let data = await get(InfoFeeds.duckDuckGoURL(subject: subject), source: source, s) { text = InfoFeeds.renderDuckDuckGo(data) }
            default:
                if let data = await get(InfoFeeds.wikipediaURL(subject: subject), source: source, s) { text = InfoFeeds.renderWikipedia(data) }
            }
            log(.reference, source, text != nil)
            if let text { return text }
        }
        return nil
    }

    static func holidays(_ request: InfoFeeds.HolidayRequest) async -> String? {
        let s = session(); defer { s.finishTasksAndInvalidate() }
        guard let source = InfoSources.sources(.holidays).first, let data = await get(InfoFeeds.holidaysURL(code: request.code, year: request.year), source: source, s) else { return nil }
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        let thisYear = Calendar.current.component(.year, from: Date()) == request.year
        let text = InfoFeeds.renderHolidays(data, request: request, today: thisYear ? f.string(from: Date()) : nil)
        log(.holidays, source, text != nil)
        return text
    }

    /// Headlines or topic news. A topic can only use Google News; general headlines use the user's chosen feed, then the others.
    static func news(topic: String) async -> String? {
        let s = session(); defer { s.finishTasksAndInvalidate() }
        let order = SourceSettings.order(for: .news)
        let candidates = topic.isEmpty ? order : order.filter { $0.id == "google-news" }
        for source in candidates {
            let url = source.id == "google-news" ? InfoFeeds.googleNewsURL(topic: topic.isEmpty ? "top stories" : topic) : InfoFeeds.newsFeedURL(sourceID: source.id)
            let text = await get(url, source: source, s).flatMap { InfoFeeds.renderNews($0, source: source.name, topic: topic) }
            log(.news, source, text != nil)
            if let text { return text }
        }
        return nil
    }
}
