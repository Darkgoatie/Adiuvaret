import Testing
@testable import ToolKit

@Suite struct ToolCatalogTests {
    let catalog = ToolCatalog.standard

    @Test func idsAreUniqueAndComplete() {
        let ids = catalog.entries.map(\.id)
        #expect(Set(ids).count == ids.count)
        for e in catalog.entries {
            #expect(!e.title.isEmpty && !e.description.isEmpty && !e.category.isEmpty, "\(e.id) needs title, description, category")
            #expect(e.keywords.count >= 3 && e.examples.count >= 3, "\(e.id) needs 3+ keywords and examples")
        }
    }

    @Test func everyExampleFindsItsOwnToolFirst() {
        for e in catalog.entries {
            for example in e.examples {
                let hits = catalog.search(primary: "", secondary: example)
                #expect(hits.first?.entry.id == e.id, "'\(example)' should find \(e.id) first, got \(hits.map(\.entry.id))")
            }
        }
    }

    @Test func routerWordsOutweighTheRawMessage() {
        let hits = catalog.search(primary: "calendar event move", secondary: "can we make it later")
        #expect(hits.first?.entry.id == "moveEvent" || hits.first?.entry.id == "readCalendar")
        #expect(hits.map(\.entry.id).contains("moveEvent"))
    }

    @Test func unrelatedChatFindsNothing() {
        for text in ["Tell me a joke about cats", "What is the capital of France?", "Explain how rainbows form", "thanks, that was great"] {
            #expect(catalog.search(primary: "", secondary: text).isEmpty, "'\(text)' should match no tool")
        }
    }

    @Test func ambiguousRequestsReturnSeveralCandidatesUpToTheLimit() {
        let hits = catalog.search(primary: "calendar event schedule", secondary: "", limit: 2)
        #expect(hits.count == 2)
        #expect(catalog.search(primary: "calendar event schedule", limit: 5).count <= 5)
    }

    @Test func accentsAndCaseAreIgnored() {
        #expect(catalog.search(primary: "", secondary: "RÉMIND me to call mom").first?.entry.id == "createReminder")
    }

    @Test func categoriesKeepOrder() {
        #expect(catalog.categories == ["Calendar", "Reminders", "Web", "Notes", "Contacts", "Shortcuts", "Email"])
    }

    @Test func tokensSplitCamelCaseAndDropNoise() {
        #expect(ToolCatalog.tokens("readCalendar") == ["read", "calendar"])
        #expect(ToolCatalog.tokens("What is the 10 times?") == ["tim"])
    }

    @Test func moveAndDeletePullInTheCalendarRead() {
        let move = catalog.entry("moveEvent")!, del = catalog.entry("deleteEvent")!
        #expect(catalog.withRequirements([move]).map(\.id) == ["moveEvent", "readCalendar"])
        #expect(catalog.withRequirements([move, del]).map(\.id) == ["moveEvent", "readCalendar", "deleteEvent"])
    }

    @Test func requirementsNeverDuplicateOrExceedTheCap() {
        let all = catalog.entries
        let list = catalog.withRequirements(all, cap: 4)
        #expect(list.count == 4 && Set(list.map(\.id)).count == 4)
    }

    @Test func everyRequirementExists() {
        for e in catalog.entries { for r in e.requires { #expect(catalog.entry(r) != nil, "\(e.id) requires missing \(r)") } }
    }

    @Test func anyBrowserHitBringsTheWholeBrowserKit() {
        for id in ["openWebsite", "lookAtPage", "actOnPage"] {
            let ids = catalog.withRequirements([catalog.entry(id)!]).map(\.id)
            #expect(Set(ids) == ["openWebsite", "lookAtPage", "actOnPage"], "\(id) -> \(ids)")
        }
    }

    @Test func searchBringsOpenAndReadButNotClicking() {
        let ids = catalog.withRequirements([catalog.entry("searchWeb")!]).map(\.id)
        #expect(ids == ["searchWeb", "openWebsite", "lookAtPage"], "\(ids)")
    }

    @Test func webQuestionsFindTheSearchTool() {
        for text in ["When is Real Betis' next match?", "What's the weather in Seville?", "Latest news about Apple", "Who won the match yesterday?"] {
            #expect(catalog.search(primary: "", secondary: text).first?.entry.id == "searchWeb", "\(text)")
            #expect(catalog.search(primary: "search web", secondary: text).first?.entry.id == "searchWeb", "\(text)")
        }
    }

    @Test func calendarChatDoesNotTriggerTheBrowser() {
        for text in ["What's on my calendar tomorrow?", "Remind me to call mom in 30 minutes", "Find me an hour free on Friday", "Cancel my 3pm meeting"] {
            let ids = catalog.search(primary: "", secondary: text).map(\.entry.id)
            #expect(!ids.contains("searchWeb") && !ids.contains("openWebsite") && !ids.contains("lookAtPage") && !ids.contains("actOnPage"), "\(text) -> \(ids)")
        }
    }
}
