import Testing
import Foundation
@testable import ToolKit

@Suite struct StandingsTests {
    @Test func tableQuestionsAreRecognised() {
        #expect(Standings.request(for: "laliga table") == .init(code: "esp.1", name: "La Liga", wantsChart: false))
        #expect(Standings.request(for: "show me the premier league standings")?.code == "eng.1")
        #expect(Standings.request(for: "Bundesliga table as a bar chart") == .init(code: "ger.1", name: "Bundesliga", wantsChart: true))
        #expect(Standings.request(for: "chart of the la liga table")?.wantsChart == true)
        #expect(Standings.request(for: "serie a ranking")?.code == "ita.1")
        #expect(Standings.request(for: "super lig puan durumu")?.code == "tur.1")
        #expect(Standings.request(for: "champions league table")?.code == "uefa.champions")
        #expect(Standings.request(for: "conference league standings")?.code == "uefa.europa.conf")
        #expect(Standings.request(for: "europa league table")?.code == "uefa.europa")
    }

    @Test func otherQuestionsAreNotStandings() {
        for t in ["la liga fixtures", "when is the next la liga game", "premier league results", "who won the la liga in 2015", "what is the capital of Spain",
                  "table for two at 8", "la liga", "set the table"] {
            #expect(Standings.request(for: t) == nil, Comment(rawValue: t))
        }
    }

    @Test func standingsQuestionsCountAsWebRequests() {
        #expect(WebIntent.looksLikeWebRequest("laliga table"))
        #expect(WebIntent.looksLikeWebRequest("Show the Bundesliga standings as a bar chart"))
        #expect(!WebIntent.looksLikeWebRequest("set the table for dinner"))
    }

    @Test func urlsStayOnTheStandingsFeed() throws {
        let url = try #require(Standings.url(code: "esp.1"))
        #expect(url.absoluteString == "https://site.api.espn.com/apis/v2/sports/soccer/esp.1/standings")
        #expect(Standings.url(code: "../x") == nil)
        #expect(Standings.url(code: "") == nil)
    }

    private let feed = Data(#"{"children":[{"name":"2026-27 LALIGA","standings":{"seasonDisplayName":"2026-27 Spanish LALIGA","entries":[{"team":{"displayName":"Real Madrid"},"stats":[{"name":"rank","value":2.0},{"name":"gamesPlayed","value":8.0},{"name":"wins","value":6.0},{"name":"ties","value":0.0},{"name":"losses","value":2.0},{"name":"pointsFor","value":19.0},{"name":"pointsAgainst","value":8.0},{"name":"points","value":18.0}]},{"team":{"displayName":"Barcelona"},"stats":[{"name":"rank","value":1.0},{"name":"gamesPlayed","value":8.0},{"name":"wins","value":8.0},{"name":"ties","value":0.0},{"name":"losses","value":0.0},{"name":"pointsFor","value":34.0},{"name":"pointsAgainst","value":7.0},{"name":"points","value":24.0}]},{"team":{"displayName":"Broken"},"stats":[]}]}}]}"#.utf8)

    @Test func rowsAreSortedAndBrokenEntriesSkipped() throws {
        let parsed = try #require(Standings.rows(feed))
        #expect(parsed.season == "2026-27 Spanish LALIGA")
        #expect(parsed.rows.map(\.team) == ["Barcelona", "Real Madrid"])
        #expect(parsed.rows.first == Standings.Row(rank: 1, team: "Barcelona", played: 8, won: 8, drawn: 0, lost: 0, goalsFor: 34, goalsAgainst: 7, points: 24))
        #expect(Standings.rows(Data("{}".utf8)) == nil)
        #expect(Standings.rows(Data("not json".utf8)) == nil)
    }

    @Test func renderedTextHoldsATableAndTheSource() throws {
        let text = try #require(Standings.render(feed, name: "La Liga", wantsChart: false))
        #expect(text.contains("La Liga table, 2026-27 Spanish LALIGA (ESPN)"))
        #expect(text.contains("| 1 | Barcelona | 8 | 8 | 0 | 0 | 34 | 7 | 24 |"), Comment(rawValue: text))
        #expect(!text.contains("```chart"))
    }

    @Test func chartRequestsAddAChartBlock() throws {
        let text = try #require(Standings.render(feed, name: "La Liga", wantsChart: true))
        #expect(text.contains("```chart\ntype: bar\ntitle: La Liga points\nteam,points\nBarcelona,24\nReal Madrid,18\n```"), Comment(rawValue: text))
    }
}
