import Testing
import Foundation
@testable import ToolKit

@Suite struct ToolDiscoveryTests {
    private let catalog = ToolCatalog.standard

    @Test func theCoreHasTheFinderAndIsSmall() {
        #expect(ToolDiscovery.core.contains(ToolDiscovery.toolName) && ToolDiscovery.core.count <= 6)
        for id in ToolDiscovery.core where id != ToolDiscovery.toolName {
            #expect(catalog.entry(id) != nil, Comment(rawValue: id))
        }
    }

    @Test func listingNamesEveryCategoryAndStaysShort() {
        let text = ToolDiscovery.listing(catalog)
        for c in ["Calendar", "Web", "Notes", "API", "Slack"] { #expect(text.contains(c + ":"), Comment(rawValue: c)) }
        #expect(text.count < 2600, Comment(rawValue: "\(text.count)"))
    }

    @Test func findReturnsWhatTheModelAsksFor() {
        func ids(_ q: String) -> [String] { ToolDiscovery.find(q, in: catalog, loaded: []).map(\.id) }
        #expect(ids("read my calendar events").contains("readCalendar"))
        #expect(ids("create a reminder").contains("createReminder"))
        #expect(ids("post a message to Slack").contains("postSlackMessage"))
        #expect(ids("search my notes folder").contains("searchNotes"))
        #expect(ids("   ").isEmpty && ids("zzqx").isEmpty)
    }

    @Test func findLeavesOutWhatIsAlreadyLoaded() {
        let found = ToolDiscovery.find("read my calendar events", in: catalog, loaded: ["readCalendar"]).map(\.id)
        #expect(!found.contains("readCalendar"))
        #expect(ToolDiscovery.find("search the web for news", in: catalog, loaded: Set(ToolDiscovery.core)).allSatisfy { !ToolDiscovery.core.contains($0.id) })
    }

    @Test func findDoesNotOfferCalendarForAServerRequest() {
        let ids = ToolDiscovery.find("restart a server through an API", in: catalog, loaded: Set(ToolDiscovery.core)).map(\.id)
        #expect(!ids.contains("createEvent") && !ids.contains("moveEvent"), Comment(rawValue: "\(ids)"))
    }

    @Test func initialPutsTheCoreFirstAndCapsTheList() {
        let hints = (0..<30).map { "hint\($0)" }
        let out = ToolDiscovery.initial(hints: hints)
        #expect(Array(out.prefix(ToolDiscovery.core.count)) == ToolDiscovery.core && out.count == ToolDiscovery.maxLoaded)
        #expect(ToolDiscovery.initial(hints: ["searchWeb", "readCalendar"]) == ToolDiscovery.core + ["readCalendar"])
    }

    @Test func growStopsAtTheCapAndSkipsDuplicates() {
        var loaded = ToolDiscovery.initial(hints: [])
        let before = loaded.count
        let added = ToolDiscovery.grow(&loaded, with: ["readCalendar", "readCalendar", "searchWeb"] + (0..<30).map { "x\($0)" })
        #expect(loaded.count == ToolDiscovery.maxLoaded && added.first == "readCalendar" && !added.contains("searchWeb"))
        #expect(loaded.count > before)
        var full = loaded
        #expect(ToolDiscovery.grow(&full, with: ["more"]).isEmpty)
    }

    @Test func renderSaysWhatWasLoadedOrThatNothingMatched() {
        let found = ToolDiscovery.find("read my calendar events", in: catalog, loaded: [])
        let t = ToolDiscovery.render(found: found, alreadyLoaded: [], query: "read my calendar events")
        #expect(t.hasPrefix("Loaded for your next step") && t.contains("readCalendar"))
        #expect(ToolDiscovery.render(found: [], alreadyLoaded: [], query: "zz \"q\"").contains("No tool matches \"zz 'q'\""))
    }
}
