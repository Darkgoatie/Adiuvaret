import Testing
import Foundation
@testable import SkillKit

@Suite struct SkillRegistryTests {
    private static let tools: Set<String> = ["readCalendar", "listReminders", "searchWeb", "createEvent"]

    private func registry(visible: Set<String> = SkillRegistryTests.tools, url: URL? = nil) -> SkillRegistry {
        SkillRegistry(url: url, knownTools: { SkillRegistryTests.tools }, visibleTools: { visible })
    }

    private func weekly() -> AgentSkill {
        AgentSkill(id: "weekly-review", name: "Weekly review", description: "Summarise the week and open reminders",
                   keywords: ["weekly", "review", "week"], examples: ["do my weekly review", "summarise my week"],
                   body: "Read the calendar for the week, then list open reminders, then suggest three priorities.",
                   allowedTools: ["readCalendar", "listReminders"], source: .builtin)
    }

    private func betis() -> AgentSkill {
        AgentSkill(id: "match-to-calendar", name: "Match to calendar", description: "Find the next football fixture and add it",
                   keywords: ["football", "fixture", "match"], examples: ["put the next Betis match in my calendar"],
                   body: "Search the web for the fixture, then add the event.", allowedTools: ["searchWeb", "createEvent"])
    }

    @Test func eachExampleFindsItsOwnSkillFirst() throws {
        let r = registry()
        try r.register(weekly()); try r.register(betis())
        #expect(r.find("do my weekly review").first?.id == "weekly-review")
        #expect(r.find("summarise my week").first?.id == "weekly-review")
        #expect(r.find("put the next Betis match in my calendar").first?.id == "match-to-calendar")
    }

    @Test func unrelatedChatFindsNothing() throws {
        let r = registry()
        try r.register(weekly()); try r.register(betis())
        for q in ["hello there", "what is the capital of France", "tell me a joke", ""] {
            #expect(r.find(q).isEmpty, Comment(rawValue: q))
        }
    }

    @Test func skillAddedLaterIsFound() throws {
        let r = registry()
        try r.register(weekly())
        #expect(r.find("football fixture").isEmpty)
        try r.register(betis())
        #expect(r.find("football fixture").first?.id == "match-to-calendar")
    }

    @Test func registrationRejectsBadSkills() throws {
        let r = registry()
        try r.register(weekly())
        #expect(throws: SkillError.duplicate("weekly-review")) { try r.register(weekly()) }
        #expect(throws: SkillError.unknownTool("deleteEverything")) {
            try r.register(AgentSkill(id: "bad-one", name: "Bad", description: "d", body: "x", allowedTools: ["deleteEverything"]))
        }
        #expect(throws: SkillError.emptyBody) { try r.register(AgentSkill(id: "empty-one", name: "E", description: "d", body: "  ")) }
        #expect(throws: SkillError.invalidID) { try r.register(AgentSkill(id: "Bad Id!", name: "E", description: "d", body: "x")) }
        #expect(throws: SkillError.emptyName) { try r.register(AgentSkill(id: "no-name", name: " ", description: "d", body: "x")) }
    }

    @Test func disabledSkillIsNeitherFoundNorUsed() throws {
        let r = registry()
        try r.register(weekly())
        r.setEnabled("weekly-review", false)
        #expect(r.find("weekly review").isEmpty)
        #expect(throws: SkillError.notFound) { try r.use("weekly-review") }
        r.setEnabled("weekly-review", true)
        #expect(r.find("weekly review").count == 1)
    }

    @Test func useHidesToolsOfSwitchedOffConnectors() throws {
        let r = registry(visible: ["readCalendar"])
        try r.register(weekly())
        let u = try r.use("weekly-review")
        #expect(u.tools == ["readCalendar"], Comment(rawValue: "\(u.tools)"))
        #expect(u.body.contains("open reminders"))
    }

    @Test func findReturnsIndexOnly() throws {
        let r = registry()
        try r.register(weekly())
        let hit = try #require(r.find("weekly review").first)
        #expect(hit.name == "Weekly review")
        #expect(!r.index().contains("three priorities"))
    }

    @Test func importedSkillsAreUntrustedAndBuiltinsCannotBeRemoved() throws {
        let r = registry()
        try r.register(weekly())
        var imp = betis(); imp.source = .imported
        try r.register(imp)
        #expect(try r.use("match-to-calendar").untrusted)
        #expect(try !r.use("weekly-review").untrusted)
        #expect(!r.remove("weekly-review"))
        #expect(r.remove("match-to-calendar"))
    }

    @Test func addedSkillsSurviveReloadAndBuiltinsAreNotWritten() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("skills2-\(UUID().uuidString).json")
        let r = registry(url: url)
        try r.register(weekly()); try r.register(betis())
        let again = registry(url: url)
        #expect(again.all().map(\.id) == ["match-to-calendar"])
    }

    @Test func limitsApply() throws {
        let long = AgentSkill(id: "long-one", name: "L", description: "d", body: String(repeating: "a", count: 5000))
        #expect(long.body.count == SkillLimits2.maxBody)
        let many = AgentSkill(id: "many-tools", name: "M", description: "d", body: "x", allowedTools: Array(repeating: "searchWeb", count: 20))
        #expect(many.allowedTools.count == SkillLimits2.maxTools)
    }
}
