import Testing
import Foundation
@testable import ToolKit

@Suite struct WebSearchTests {
    private func row(_ href: String, _ title: String, _ snippet: String? = "snippet") -> String {
        var s = "<tr><td>1.&nbsp;</td><td><a rel=\"nofollow\" href=\"\(href)\" class='result-link'>\(title)</a></td></tr>"
        if let snippet { s += "<tr><td>&nbsp;</td><td class='result-snippet'>\(snippet)</td></tr>" }
        return "<table>" + s + "</table>"
    }

    private func parse(_ rows: String...) -> [SearchResult] { WebSearch.parse(html: rows.joined()) }

    @Test func theRealPageGivesThreeCleanResults() {
        let r = WebSearch.parse(html: SearchFixture.lite)
        #expect(r.count == 3, "got \(r.count)")
        guard r.count == 3 else { return }
        #expect(r[0].host == "www.laliga.com" && r[0].url.scheme == "https")
        #expect(r[0].title.contains("LALIGA") && !r[0].title.contains("<"))
        #expect(r[0].snippet.contains("Real Betis") && !r[0].snippet.contains("<b>") && !r[0].snippet.contains("&#x27;"), Comment(rawValue: r[0].snippet))
        #expect(r[1].host == "en.realbetisbalompie.es")
        #expect(r.allSatisfy { !$0.snippet.isEmpty })
    }

    @Test func redirectLinksAreUnwrapped() {
        let r = parse(row("//duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2Fa%3Fx%3D1&amp;rut=abc", "Redirected"))
        #expect(r.first?.url.absoluteString == "https://example.com/a?x=1", "\(r)")
    }

    @Test func adsAndInternalLinksAreDropped() {
        let r = parse(row("https://duckduckgo.com/y.js?ad_domain=shop.com&ad_provider=x", "Ad"),
                      row("/lite/?q=more", "Next page"),
                      row("https://example.com/ok", "Real"))
        #expect(r.map(\.title) == ["Real"], "\(r.map(\.title))")
    }

    @Test func privateAndUnsafeAddressesAreDropped() {
        let r = parse(row("http://192.168.0.1/x", "A"), row("javascript:alert(1)", "B"), row("https://localhost/a", "C"),
                      row("ftp://example.com/f", "D"), row("http://example.org/z", "E"))
        #expect(r.map(\.title) == ["E"], "\(r.map(\.title))")
        #expect(r.first?.url.scheme == "https")
    }

    @Test func repeatsAndCrowdedSitesAreTrimmed() {
        let same = row("https://example.com/a", "One") + row("https://example.com/a", "One again")
        #expect(parse(same).count == 1)
        let crowded = parse(row("https://x.com/1", "1"), row("https://x.com/2", "2"), row("https://x.com/3", "3"), row("https://y.com/", "4"))
        #expect(crowded.map(\.title) == ["1", "2", "4"], "\(crowded.map(\.title))")
        let many = (1...9).map { row("https://site\($0).com/", "T\($0)") }.joined()
        #expect(WebSearch.parse(html: many).count == WebSearch.maxResults)
    }

    @Test func entitiesAndTagsAreCleaned() {
        let r = parse(row("https://example.com/", "Fish &amp; Chips &#x27;n&#39; <b>more</b>", "  a\n   <b>b</b>&nbsp;c  "))
        #expect(r.first?.title == "Fish & Chips 'n' more", "\(r.first?.title ?? "")")
        #expect(r.first?.snippet == "a b c", "\(r.first?.snippet ?? "")")
    }

    @Test func aSnippetBelongsToItsOwnResult() {
        let r = parse(row("https://a.com/", "A", nil), row("https://b.com/", "B", "only for b"))
        #expect(r.count == 2 && r[0].snippet.isEmpty && r[1].snippet == "only for b", "\(r)")
    }

    @Test func aPageWithoutResultsGivesNothing() {
        #expect(WebSearch.parse(html: "<html><body>No results.</body></html>").isEmpty)
        #expect(WebSearch.parse(html: "").isEmpty)
    }

    @Test func queryAddressIsBuiltAndEncoded() {
        #expect(WebSearch.url(for: "real betis next match")?.absoluteString == "https://lite.duckduckgo.com/lite/?q=real%20betis%20next%20match")
        #expect(WebSearch.url(for: "a&b #c")?.absoluteString == "https://lite.duckduckgo.com/lite/?q=a%26b%20%23c")
        #expect(WebSearch.url(for: "   ") == nil)
        #expect(WebSearch.cleanQuery("  weather \n in   Seville ") == "weather in Seville")
        #expect(WebSearch.cleanQuery(String(repeating: "a", count: 500)).count == WebSearch.maxQueryLength)
    }

    @Test func resultsAreRenderedShortAndMarkedUntrusted() {
        let results = (1...5).map {
            SearchResult(title: "Title \($0) " + String(repeating: "x", count: 150), url: URL(string: "https://site\($0).com/page")!,
                         snippet: String(repeating: "word ", count: 80))
        }
        let text = WebSearch.render(results, query: "say \"hi\"")
        #expect(text.contains("untrusted") && text.contains("1. Title 1") && text.contains("(site1.com)") && text.contains("https://site1.com/page"))
        #expect(!text.contains("\"hi\"") && text.contains("'hi'"))
        #expect(text.count <= 2300, "\(text.count)")
        #expect(text.contains("openWebsite"))
    }

    @Test func noResultsExplainsAndSuggestsNewWords() {
        let text = WebSearch.render([], query: "zzzz")
        #expect(text.contains("found nothing") && text.contains("different words"))
    }
}

@Suite struct WebIntentTests {
    @Test func plainWebRequestsAreRecognised() {
        for t in ["When is Real Betis' next match?", "What's the weather in Seville?", "Latest news about Apple", "Search for pizza near me",
                  "How much are AirPods?", "Who won the match yesterday?", "What's the price of Bitcoin?", "Google the opening hours of the Louvre",
                  "look up the release date of the new iPhone", "Convert 50 euros to dollars", "When does Real Betis play next?"] {
            #expect(WebIntent.looksLikeWebRequest(t), "\(t)")
        }
    }

    @Test func calendarAndChatAreNotWebRequests() {
        for t in ["What's on my calendar tomorrow?", "Remind me to call mom", "Find me an hour free on Friday", "Search my calendar for the dentist",
                  "Tell me a joke", "Thanks!", "Write a short email to Ana", "Cancel my meeting", "Explain how rainbows form", ""] {
            #expect(!WebIntent.looksLikeWebRequest(t), "\(t)")
        }
    }
}
