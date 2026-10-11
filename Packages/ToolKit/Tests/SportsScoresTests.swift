import Testing
import Foundation
@testable import ToolKit

@Suite struct SportsScoresTests {
    @Test func scoreQuestionsAreRecognised() {
        #expect(SportsScores.request(for: "nba scores") == .init(path: "basketball/nba", name: "NBA"))
        #expect(SportsScores.request(for: "NFL games today")?.path == "football/nfl")
        #expect(SportsScores.request(for: "what is the hockey score")?.path == "hockey/nhl")
        #expect(SportsScores.request(for: "mlb schedule")?.path == "baseball/mlb")
    }

    @Test func otherQuestionsAreNot() {
        for t in ["nba standings", "who won the nba title", "basketball", "la liga scores", "tennis scores", "set a reminder for the nba game"] {
            #expect(SportsScores.request(for: t) == nil, Comment(rawValue: t))
        }
    }

    @Test func urlsOnlyForKnownSports() {
        #expect(SportsScores.url(path: "basketball/nba")?.absoluteString == "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard")
        #expect(SportsScores.url(path: "../x") == nil)
        #expect(SportsScores.url(path: "tennis/atp") == nil)
    }

    private let feed = Data(#"{"events":[{"name":"Dallas Mavericks at Houston Rockets","date":"2026-10-11T10:00Z","status":{"type":{"state":"in","shortDetail":"6:55 - 4th"}},"competitions":[{"competitors":[{"homeAway":"home","score":"99","team":{"displayName":"Houston Rockets"}},{"homeAway":"away","score":"107","team":{"displayName":"Dallas Mavericks"}}]}]},{"name":"Orlando Magic at Cleveland Cavaliers","date":"2026-10-11T22:30Z","status":{"type":{"state":"pre","shortDetail":"10/11 - 6:30 PM EDT"}},"competitions":[{"competitors":[{"homeAway":"home","score":"0","team":{"displayName":"Cleveland Cavaliers"}},{"homeAway":"away","score":"0","team":{"displayName":"Orlando Magic"}}]}]}]}"#.utf8)

    @Test func liveAndUpcomingGamesAreRendered() throws {
        let text = try #require(SportsScores.render(feed, name: "NBA", timeZone: TimeZone(identifier: "UTC")!))
        #expect(text.hasPrefix("NBA on ESPN right now"))
        #expect(text.contains("1. Dallas Mavericks 107-99 Houston Rockets, 6:55 - 4th"), Comment(rawValue: text))
        #expect(text.contains("2. Orlando Magic at Cleveland Cavaliers, Sun 11 Oct 22:30"), Comment(rawValue: text))
        #expect(SportsScores.render(Data(#"{"events":[]}"#.utf8), name: "NBA") == nil)
        #expect(SportsScores.render(Data("nope".utf8), name: "NBA") == nil)
    }
}
