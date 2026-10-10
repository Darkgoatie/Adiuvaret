import Testing
import Foundation
@testable import ToolKit

@Suite struct DirectSourcesTests {
    @Test func currencyQuestionsAreRecognised() {
        #expect(DirectSources.request(for: "How much is 100 USD in Turkish lira?") == .currency(amount: 100, from: "USD", to: "TRY"))
        #expect(DirectSources.request(for: "convert 50 euros to dollars") == .currency(amount: 50, from: "EUR", to: "USD"))
        #expect(DirectSources.request(for: "what is the exchange rate usd to try") == .currency(amount: 1, from: "USD", to: "TRY"))
        #expect(DirectSources.request(for: "How many lira is 1,000 dollars?") == .currency(amount: 1000, from: "USD", to: "TRY"))
        #expect(DirectSources.request(for: "I will try this") == nil)
        #expect(DirectSources.request(for: "What's the price of gold in dollars") == nil)
    }

    @Test func teamQuestionsAreRecognised() {
        #expect(DirectSources.request(for: "When is Real Betis' next game?") == .team(name: "real betis", kind: .next))
        #expect(DirectSources.request(for: "When does Real Betis play?") == .team(name: "real betis", kind: .next))
        #expect(DirectSources.request(for: "Who won the Barcelona game yesterday?") == .team(name: "barcelona", kind: .last))
        #expect(DirectSources.request(for: "What time is the match") == nil)
        #expect(DirectSources.request(for: "Cancel my meeting next game") == nil)
        #expect(DirectSources.request(for: "Tell me a joke") == nil)
    }

    @Test func competitionQuestionsAreRecognised() {
        #expect(DirectSources.request(for: "next UCL matchday") == .competition(id: "4480", name: "UEFA Champions League", kind: .next))
        #expect(DirectSources.request(for: "When is the next Champions League match?") == .competition(id: "4480", name: "UEFA Champions League", kind: .next))
        #expect(DirectSources.request(for: "Premier League fixtures this weekend") == .competition(id: "4328", name: "English Premier League", kind: .next))
        #expect(DirectSources.request(for: "latest Champions League results") == .competition(id: "4480", name: "UEFA Champions League", kind: .last))
        #expect(DirectSources.request(for: "Europa Conference League matchday") == nil)
        #expect(DirectSources.request(for: "When does Real Madrid play in the Champions League?") == .team(name: "real madrid", kind: .next))
        #expect(DirectSources.request(for: "Champions League winners history") == nil)
    }

    @Test func competitionDaysAreListed() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        let now = Date(timeIntervalSince1970: 1_791_590_400)
        let next = DirectSources.competitionDayURLs(id: "4480", kind: .next, now: now, timeZone: utc)
        #expect(next.count == 10 && next[0].absoluteString.hasSuffix("eventsday.php?d=2026-10-10&l=4480"), "\(next.first?.absoluteString ?? "")")
        let last = DirectSources.competitionDayURLs(id: "4480", kind: .last, now: now, timeZone: utc)
        #expect(last.count == 7 && last[0].absoluteString.contains("d=2026-10-09"), "\(last.first?.absoluteString ?? "")")
        #expect(DirectSources.competitionDayURLs(id: "x1", kind: .next, now: now, timeZone: utc).isEmpty)
    }

    @Test func aMatchdayIsRenderedFromTheFirstDayWithGames() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        let empty = Data(#"{"events":null}"#.utf8)
        let day1 = Data(#"{"events":[{"strEvent":"Arsenal vs Lille","strTimestamp":"2026-10-13T19:00:00","intRound":"2"},{"strEvent":"Lens vs Sporting CP","strTimestamp":"2026-10-13T16:45:00","intRound":"2"}]}"#.utf8)
        let day2 = Data(#"{"events":[{"strEvent":"Manchester City vs Paris Saint-Germain","strTimestamp":"2026-10-14T19:00:00","intRound":"2"}]}"#.utf8)
        let text = try #require(DirectSources.renderCompetition(days: [empty, day1, day2], name: "UEFA Champions League", kind: .next, timeZone: utc))
        #expect(text.contains("Upcoming UEFA Champions League matches"), "\(text)")
        #expect(text.contains("1. Lens vs Sporting CP, Tue 13 Oct 16:45") && text.contains("2. Arsenal vs Lille, Tue 13 Oct 19:00"), "\(text)")
        #expect(text.contains("Manchester City vs Paris Saint-Germain, Wed 14 Oct 19:00"), "\(text)")
        #expect(DirectSources.renderCompetition(days: [empty], name: "x", kind: .next, timeZone: utc) == nil)
    }

    @Test func addressesAreBuilt() {
        let url = DirectSources.currencyURL(amount: 100, from: "USD", to: "TRY")?.absoluteString ?? ""
        #expect(url.hasPrefix("https://api.frankfurter.dev/v1/latest?") && url.contains("amount=100") && url.contains("base=USD") && url.contains("symbols=TRY"), "\(url)")
        #expect(DirectSources.currencyURL(amount: 0, from: "USD", to: "TRY") == nil)
        #expect(DirectSources.teamSearchURL("real betis")?.absoluteString.contains("t=real%20betis") == true)
        #expect(DirectSources.eventsURL(teamID: "133722", kind: .next)?.absoluteString.hasSuffix("eventsnext.php?id=133722") == true)
        #expect(DirectSources.eventsURL(teamID: "13x", kind: .last) == nil)
    }

    @Test func aRateIsRendered() throws {
        let data = Data(#"{"amount":100.0,"base":"USD","date":"2026-10-09","rates":{"TRY":4917.01}}"#.utf8)
        let text = try #require(DirectSources.renderCurrency(data, amount: 100, from: "USD", to: "TRY"))
        #expect(text.contains("100.00 USD = 4917.01 TRY") && text.contains("1 USD = 49.17 TRY") && text.contains("2026-10-09"), "\(text)")
        #expect(DirectSources.renderCurrency(Data("{}".utf8), amount: 1, from: "USD", to: "TRY") == nil)
    }

    @Test func aTeamIsReadFromTheSearchAnswer() {
        let data = Data(#"{"teams":[{"idTeam":"133722","strTeam":"Real Betis"}]}"#.utf8)
        let team = DirectSources.parseTeam(data)
        #expect(team?.id == "133722" && team?.name == "Real Betis")
        #expect(DirectSources.parseTeam(Data(#"{"teams":null}"#.utf8)) == nil)
    }

    private let next = Data(#"{"events":[{"strEvent":"Real Betis vs Osasuna","strTimestamp":"2026-10-11T16:30:00","strLeague":"Spanish La Liga","dateEvent":"2026-10-11"}]}"#.utf8)

    @Test func theNextMatchShowsLocalTime() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        let text = try #require(DirectSources.renderEvents(next, team: "Real Betis", kind: .next, timeZone: utc))
        #expect(text.contains("Real Betis vs Osasuna") && text.contains("Sun 11 Oct 2026 16:30") && text.contains("Spanish La Liga"), "\(text)")
        let madrid = try #require(TimeZone(identifier: "Europe/Madrid"))
        let local = try #require(DirectSources.renderEvents(next, team: "Real Betis", kind: .next, timeZone: madrid))
        #expect(local.contains("Sun 11 Oct 2026 18:30"), "\(local)")
    }

    @Test func latestResultsShowScoresAndGaps() throws {
        let data = Data(#"{"results":[{"strEvent":"Real Betis vs Ceuta","dateEvent":"2026-10-01","strLeague":"Copa","strHomeTeam":"Real Betis","strAwayTeam":"Ceuta","intHomeScore":null,"intAwayScore":null},{"strEvent":"Real Betis vs Osasuna","dateEvent":"2026-09-20","strHomeTeam":"Real Betis","strAwayTeam":"Osasuna","intHomeScore":"2","intAwayScore":"1","strLeague":"Spanish La Liga"}]}"#.utf8)
        let text = try #require(DirectSources.renderEvents(data, team: "Real Betis", kind: .last))
        #expect(text.contains("Real Betis vs Ceuta") && text.contains("score not recorded"), "\(text)")
        #expect(text.contains("Real Betis 2-1 Osasuna") && text.contains("20 Sep 2026"), "\(text)")
        #expect(DirectSources.renderEvents(Data(#"{"events":null}"#.utf8), team: "x", kind: .next) == nil)
    }
}

@Suite struct SearchLoopTests {
    @Test func queriesAreWrittenFromSentences() {
        #expect(WebSearch.queryFrom("When is the next UCL matchday?") == "next UCL matchday")
        #expect(WebSearch.queryFrom("Who is the CEO of Nvidia?") == "CEO Nvidia")
        #expect(WebSearch.queryFrom("What is the capital of France") == "capital France")
        #expect(WebSearch.queryFrom("is the") == "is the")
    }

    @Test func coverageDecidesWhenThePagesAreEnough() {
        let good = ["The next UCL matchday is on 13 October with Arsenal vs Lille at 19:00 local time and Lens vs Sporting after that."]
        #expect(SearchLoop.isEnough(query: "next UCL matchday", excerpts: good))
        #expect(!SearchLoop.isEnough(query: "next UCL matchday", excerpts: []))
        #expect(!SearchLoop.isEnough(query: "next UCL matchday", excerpts: ["A long text about gardening and tomatoes that has nothing to do with football at all, truly nothing."]))
        #expect(!SearchLoop.isEnough(query: "next UCL matchday", excerpts: ["UCL"]))
        #expect(SearchLoop.coverage(query: "next UCL matchday", excerpts: good) == 1)
    }

    @Test func laterRoundsChangeTheWords() {
        #expect(SearchLoop.refine("next UCL matchday", round: 2, year: 2026) == "next UCL matchday 2026")
        #expect(SearchLoop.refine("next UCL matchday 2026", round: 2, year: 2026) == "next UCL matchday 2026 latest")
        #expect(SearchLoop.refine("next UCL matchday", round: 3, year: 2026) == "next UCL matchday official")
        #expect(SearchLoop.refine("x", round: 4, year: 2026) == nil)
    }

    @Test func resultsWithPageTextComeFirst() throws {
        func r(_ n: Int) -> SearchResult { SearchResult(title: "T\(n)", url: URL(string: "https://s\(n).com/")!, snippet: "") }
        let picked = WebSearch.select(results: (0..<7).map(r), excerpts: [4: "four", 6: "six"], limit: 4)
        #expect(picked.results.map(\.title) == ["T4", "T6", "T0", "T1"], "\\(picked.results.map(\.title))")
        #expect(picked.excerpts == [0: "four", 1: "six"], "\\(picked.excerpts)")
        #expect(WebSearch.select(results: [], excerpts: [:]).results.isEmpty)
    }
}

@Suite struct PageExtractTests {
    @Test func tableRowsAndListItemsAreRead() {
        let html = "<table><tr><td>Arsenal vs Lille</td><td>Tue 13 Oct</td><td>19:00</td></tr><tr><td>x</td></tr></table><ul><li>Lens vs Sporting CP, Tue 13 Oct 16:45</li></ul>"
        let text = PageExtract.excerpt(html: html, query: "arsenal lille lens sporting")
        #expect(text.contains("Arsenal vs Lille Tue 13 Oct 19:00"), "\\(text)")
        #expect(text.contains("Lens vs Sporting CP, Tue 13 Oct 16:45"), "\\(text)")
    }

    @Test func dataBlocksOfScriptDrivenPagesAreRead() {
        let html = #"<script id="__NEXT_DATA__" type="application/json">{"props":{"fixtures":[{"t":"Arsenal v Lille kicks off Tuesday 13 October 19:00"},{"t":"Unrelated text about cooking pasta at home tonight"}]}}</script>"#
        let text = PageExtract.excerpt(html: html, query: "arsenal lille kickoff")
        #expect(text.contains("Arsenal v Lille kicks off"), "\\(text)")
        #expect(!text.contains("pasta"), "\\(text)")
    }

    private let page = """
    <html><head><title>T</title>
    <meta property="og:description" content="Real Betis host Osasuna on Sunday at 16:30 in La Liga.">
    <script type="application/ld+json">{"@context":"https://schema.org","@type":"SportsEvent","name":"Real Betis vs Osasuna","startDate":"2026-10-11T16:30","location":{"@type":"Place","name":"Estadio Benito Villamarin"}}</script>
    <script>var x = "<p>this paragraph sits inside a script block and must never be shown to anyone</p>";</script>
    </head><body><nav><p>Menu paragraph that is long enough to pass the length filter easily okay</p></nav>
    <p>We use cookies to improve your experience on this website and for many other purposes.</p>
    <p>The sky was blue and the grass was green and nothing else was going on over there at all.</p>
    <p>Real Betis will play Osasuna at Estadio Benito Villamarin on Sunday, kickoff is at 16:30 local time.</p>
    </body></html>
    """

    @Test func termsDropFillerWords() {
        #expect(PageExtract.terms("What's the weather in New York today?") == ["weather", "new", "york"])
        #expect(PageExtract.terms("latest scores of the games") == ["score", "game"])
    }

    @Test func theExcerptHoldsDescriptionFactsAndTheMatchingParagraph() {
        let text = PageExtract.excerpt(html: page, query: "real betis next match")
        #expect(text.contains("Osasuna on Sunday"), "\(text)")
        #expect(text.contains("Event: Real Betis vs Osasuna") && text.contains("Estadio Benito Villamarin"), "\(text)")
        #expect(text.contains("kickoff is at 16:30"), "\(text)")
        #expect(!text.contains("Menu paragraph") && !text.contains("cookies") && !text.contains("inside a script") && !text.contains("grass"), "\(text)")
        #expect(text.count <= 520, "\(text.count)")
    }

    @Test func aPageWithNothingUsefulGivesAnEmptyExcerpt() {
        #expect(PageExtract.excerpt(html: "<html><body><div>hi</div></body></html>", query: "anything here").isEmpty)
        #expect(PageExtract.excerpt(html: "", query: "x").isEmpty)
    }

    @Test func productPricesAreRead() {
        let html = #"<script type="application/ld+json">{"@type":"Product","name":"AirPods Pro","offers":{"@type":"Offer","price":"249.00","priceCurrency":"USD"}}</script>"#
        #expect(PageExtract.excerpt(html: html, query: "airpods price").contains("Product: AirPods Pro, price 249.00 USD"))
    }
}
