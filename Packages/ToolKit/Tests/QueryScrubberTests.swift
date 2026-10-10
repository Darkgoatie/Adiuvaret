import Testing
@testable import ToolKit

@Suite struct QueryScrubberTests {
    @Test func contactDetailsAreRemoved() {
        let r = QueryScrubber.scrub(query: "weather Seville ana@example.com +34 600 123 456", userMessage: "weather Seville")
        #expect(r.query == "weather Seville", Comment(rawValue: r.query))
        #expect(r.changed && r.removed.count == 2, Comment(rawValue: "\(r.removed)"))
    }

    @Test func wordsFromTheCalendarAreRemoved() {
        let private_ = "Dentist Dr Moreno 10:00 Clinica Sevilla Norte"
        let r = QueryScrubber.scrub(query: "dentist Moreno opening hours", userMessage: "what are opening hours near me", privateText: private_)
        #expect(r.query == "opening hours", Comment(rawValue: r.query))
    }

    @Test func wordsTheUserTypedStay() {
        let r = QueryScrubber.scrub(query: "Moreno clinic hours", userMessage: "find Moreno clinic hours", privateText: "Dr Moreno clinic")
        #expect(r.query == "Moreno clinic hours" && !r.changed, Comment(rawValue: r.query))
    }

    @Test func plainQueriesPassUntouched() {
        let r = QueryScrubber.scrub(query: "next UCL matchday", userMessage: "When is the next UCL matchday?")
        #expect(r.query == "next UCL matchday" && !r.changed)
        #expect(QueryScrubber.scrub(query: "iPhone 17 release date 2026", userMessage: "x").query == "iPhone 17 release date 2026")
    }

    @Test func longNumbersAndLinksWithLoginsAreRemoved() {
        #expect(QueryScrubber.scrub(query: "track 123456789012 parcel", userMessage: "track parcel").query == "track parcel")
        #expect(QueryScrubber.scrub(query: "open https://user:pw@site.com/a news", userMessage: "news").query == "open news")
    }
}
