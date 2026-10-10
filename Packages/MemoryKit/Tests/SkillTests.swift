import Testing
import Foundation
@testable import MemoryKit

@Suite struct SkillTests {
    private func tempURL() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("skills-\(UUID().uuidString).json") }

    @Test func onlyTasksWithTwoDifferentToolsAreWorthSaving() {
        #expect(SkillMath.isWorthSaving(tools: ["searchWeb", "createEvent"]))
        #expect(!SkillMath.isWorthSaving(tools: ["searchWeb"]))
        #expect(!SkillMath.isWorthSaving(tools: ["searchWeb", "searchWeb", "searchWeb"]))
        #expect(!SkillMath.isWorthSaving(tools: []))
    }

    @Test func playbookHasStepsButNoValues() {
        let book = SkillMath.playbook(tools: ["searchWeb", "createEvent", "searchWeb"], labels: ["searchWeb": "Search the web", "createEvent": "Add the event"])
        #expect(book.contains("1. Search the web") && book.contains("2. Add the event"), Comment(rawValue: book))
        #expect(!book.contains("3."), Comment(rawValue: book))
        #expect(book.count <= SkillLimits.maxPlaybook)
    }

    @Test func titlesKeepWordsAndDropDigits() {
        #expect(SkillMath.suggestedTitle(from: "Find the next Betis match and add it to my calendar") == "Find the next Betis match and")
        #expect(SkillMath.suggestedTitle(from: "call 0555 123 4567") == "call")
        #expect(SkillMath.suggestedTitle(from: "123 456") == "Saved routine")
    }

    @Test func matchingUsesEnabledSkillsOnly() {
        let a = Skill(title: "Betis match to calendar", whenToUse: "football fixtures into the calendar", playbook: "1. Search the web 2. Add the event")
        var b = Skill(title: "Weekly groceries", whenToUse: "shopping list", playbook: "1. Add reminders")
        #expect(SkillMath.matching([a, b], for: "put the next Betis match in my calendar").map(\.id) == [a.id])
        b.enabled = false
        #expect(SkillMath.matching([b], for: "groceries shopping").isEmpty)
        #expect(SkillMath.matching([a], for: "").isEmpty)
        #expect(SkillMath.matching([a], for: "what is the weather").isEmpty)
    }

    @Test func promptBlockIsEmptyWithoutSkills() {
        #expect(SkillMath.promptBlock([]) == "")
        let s = Skill(title: "T", whenToUse: "w", playbook: "p")
        #expect(SkillMath.promptBlock([s]).contains("- T: p"))
    }

    @Test func storeSavesRemovesAndReloads() {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = SkillStore(url: url)
        let skill = Skill(title: "Route", whenToUse: "when asked", playbook: "1. Search")
        #expect(store.add(skill) == .added(skill))
        #expect(store.add(skill) == .duplicate)
        #expect(SkillStore(url: url).all().count == 1)
        store.setEnabled(skill.id, false)
        #expect(SkillStore(url: url).all().first?.enabled == false)
        #expect(store.remove(skill.id))
        #expect(!store.remove(skill.id))
        #expect(SkillStore(url: url).all().isEmpty)
    }

    @Test func storeRefusesPastTheCap() {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url) }
        let store = SkillStore(url: url)
        for i in 0..<SkillLimits.maxSkills { _ = store.add(Skill(title: "S\(i)", whenToUse: "w", playbook: "p\(i)")) }
        #expect(store.add(Skill(title: "Extra", whenToUse: "w", playbook: "p")) == .full)
        #expect(store.all().count == SkillLimits.maxSkills)
    }

    @Test func skillTextIsClipped() {
        let s = Skill(title: String(repeating: "a", count: 200), whenToUse: String(repeating: "b", count: 500), playbook: String(repeating: "c", count: 900))
        #expect(s.title.count == SkillLimits.maxTitle && s.whenToUse.count == 200 && s.playbook.count == SkillLimits.maxPlaybook)
    }
}
