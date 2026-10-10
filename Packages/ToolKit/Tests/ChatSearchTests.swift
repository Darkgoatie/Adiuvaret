import Testing
import Foundation
@testable import ToolKit

@Suite struct ChatSearchTests {
    private let now = Date(timeIntervalSince1970: 1_791_600_000)
    private func day(_ n: Int) -> Date { now.addingTimeInterval(-Double(n) * 86_400) }

    private var messages: [PastMessage] {
        [PastMessage(chatTitle: "Seville trip", date: day(3), isUser: true, text: "Which hotel did we pick in Seville near the cathedral?"),
         PastMessage(chatTitle: "Seville trip", date: day(3), isUser: false, text: "You liked Hotel Alfonso XIII, about 220 euros a night."),
         PastMessage(chatTitle: "Groceries", date: day(1), isUser: true, text: "Add milk and eggs to the list."),
         PastMessage(chatTitle: "Old plans", date: day(90), isUser: true, text: "Maybe Seville in spring.")]
    }

    @Test func findsTheMessageThatHoldsTheAnswer() {
        let hits = ChatSearch.rank(messages, query: "hotel in Seville", now: now)
        #expect(hits.first?.speaker == "assistant" || hits.first?.speaker == "user")
        #expect(hits.first?.chatTitle == "Seville trip", Comment(rawValue: "\(hits)"))
        #expect(hits.contains { $0.snippet.contains("Alfonso") }, Comment(rawValue: "\(hits)"))
    }

    @Test func recentMessagesWinTies() {
        let hits = ChatSearch.rank(messages, query: "Seville", now: now)
        #expect(hits.last?.chatTitle == "Old plans", Comment(rawValue: "\(hits.map(\.chatTitle))"))
    }

    @Test func fillerWordsDoNotMatchEverything() {
        #expect(ChatSearch.terms("What did we talk about last week regarding Seville?") == ["regarding", "seville"], Comment(rawValue: "\(ChatSearch.terms("What did we talk about last week regarding Seville?"))"))
        #expect(ChatSearch.rank(messages, query: "what did we talk about", now: now).count <= 4)
    }

    @Test func nothingMatchesNothing() {
        #expect(ChatSearch.rank(messages, query: "zebra giraffe", now: now).isEmpty)
        #expect(ChatSearch.rank([], query: "Seville", now: now).isEmpty)
        #expect(ChatSearch.rank(messages, query: "", now: now).isEmpty)
    }

    @Test func limitIsRespected() {
        #expect(ChatSearch.rank(messages, query: "Seville", now: now, limit: 2).count == 2)
    }

    @Test func linesNameTheChatAndDay() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let hits = [ChatSearch.Hit(chatTitle: "Seville trip", date: Date(timeIntervalSince1970: 1_791_000_000), speaker: "user", snippet: "hotel", score: 1)]
        let lines = ChatSearch.format(hits, searched: 4, calendar: cal)
        #expect(lines == ["1. 2026-10-03 in chat 'Seville trip' (user): hotel"], Comment(rawValue: "\(lines)"))
    }
}
