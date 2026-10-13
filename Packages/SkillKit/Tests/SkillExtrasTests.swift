import Testing
import Foundation
import ToolKit
@testable import SkillKit

@Suite struct BuiltinSkillTests {
    private func registry() throws -> SkillRegistry {
        let ids = Set(ToolCatalog.standard.entries.map(\.id))
        let r = SkillRegistry(knownTools: { ids })
        for s in BuiltinSkills.all { try r.register(s) }
        return r
    }

    @Test func everyBuiltinRegistersAgainstTheRealToolCatalog() throws {
        let r = try registry()
        #expect(r.all().count == BuiltinSkills.all.count)
        #expect(ToolCatalog.standard.entry("skill_use") != nil)
    }

    @Test func everyBuiltinExampleFindsItsOwnSkillFirst() throws {
        let r = try registry()
        for s in BuiltinSkills.all {
            for example in s.examples {
                #expect(r.find(example).first?.id == s.id, Comment(rawValue: "'\(example)' should find \(s.id), got \(r.find(example).map(\.id))"))
            }
        }
    }

    @Test func plainCalendarOrChatQuestionsDoNotPullInASkill() throws {
        let r = try registry()
        for q in ["What's on my calendar tomorrow?", "Do I have anything this week?", "Remind me to call mom in 30 minutes", "What is the weather in Seville?",
                  "Tell me a joke about cats", "thanks, that was great", "Add lunch with Ana tomorrow at 13:00"] {
            #expect(r.find(q).isEmpty, Comment(rawValue: "'\(q)' found \(r.find(q).map(\.id))"))
        }
    }

    @Test func skillNeedingAnOffConnectorIsHiddenUntilItIsOn() throws {
        let r = SkillRegistry(knownTools: { ["searchNotes"] }, connectorOn: { _ in true })
        try r.register(AgentSkill(id: "note-recap", name: "Note recap", description: "Recap my notes", keywords: ["recap", "notes"],
                                  body: "Search the notes and recap.", allowedTools: ["searchNotes"], requires: ["notes"]))
        #expect(!r.find("recap notes").isEmpty)
        let off = SkillRegistry(knownTools: { ["searchNotes"] }, connectorOn: { _ in false })
        try off.register(AgentSkill(id: "note-recap", name: "Note recap", description: "Recap my notes", keywords: ["recap", "notes"],
                                    body: "Search the notes and recap.", allowedTools: ["searchNotes"], requires: ["notes"]))
        #expect(off.find("recap notes").isEmpty)
        #expect(throws: SkillError.notFound) { try off.use("note-recap") }
        #expect(off.index().isEmpty)
    }
}

@Suite struct SkillImportTests {
    @Test func jsonImportIsUntrustedAndKeepsFields() throws {
        let json = #"{"name":"Morning brief","description":"Calendar then reminders","keywords":["morning","brief"],"body":"Read the calendar, then the reminders.","tools":["readCalendar","listReminders"]}"#
        let s = try SkillImport.parse(Data(json.utf8))
        #expect(s.id == "morning-brief")
        #expect(s.source == .imported && s.untrusted)
        #expect(s.allowedTools == ["readCalendar", "listReminders"])
        #expect(s.keywords == ["morning", "brief"])
    }

    @Test func markdownImportReadsTheHeaderAndBody() throws {
        let md = "---\nname: Gym log\ndescription: Log a workout\nkeywords: [gym, workout]\ntools: writeNote\n---\nAppend one line to the workout note with today's date."
        let s = try SkillImport.parse(Data(md.utf8))
        #expect(s.id == "gym-log" && s.name == "Gym log")
        #expect(s.allowedTools == ["writeNote"])
        #expect(s.body.hasPrefix("Append one line"))
        #expect(s.keywords == ["gym", "workout"])
    }

    @Test func plainTextWithoutAHeaderIsRejected() {
        #expect(throws: SkillImportError.missing("name")) { try SkillImport.parse(Data("just some text".utf8)) }
        #expect(throws: SkillImportError.unreadable) { try SkillImport.parse(Data("{ not json".utf8)) }
        #expect(throws: SkillImportError.tooLarge) { try SkillImport.parse(Data(repeating: 65, count: SkillImport.maxBytes + 1)) }
    }

    @Test func importedSkillStillFailsOnUnknownTools() throws {
        let json = #"{"name":"Sneaky","body":"Do it.","tools":["wipeDevice"]}"#
        let s = try SkillImport.parse(Data(json.utf8))
        let r = SkillRegistry(knownTools: { ["readCalendar"] })
        #expect(throws: SkillError.unknownTool("wipeDevice")) { try r.register(s) }
    }

    @Test func slugsAreSafeIDs() {
        #expect(SkillImport.slugify("Weekly Review!") == "weekly-review")
        #expect(SkillImport.slugify("Café plan") == "cafe-plan")
        #expect(SkillImport.slugify("  --  ") == "")
    }
}

@Suite struct SkillMigrationTests {
    private let legacy = #"[{"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3301","title":"Betis match to calendar","whenToUse":"football fixtures into the calendar","playbook":"Steps that worked before: 1. Search the web 2. Add the event Check each result before the next step.","enabled":true,"created":"2026-10-08T10:00:00Z"},{"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3302","title":"Groceries","whenToUse":"shopping list","playbook":"1. Add a reminder","enabled":false,"created":"2026-10-09T10:00:00Z"}]"#

    @Test func oldSkillsFileLoadsAsLearnedSkills() throws {
        let labels = ["Search the web": "searchWeb", "Add the event": "createEvent", "Add a reminder": "createReminder"]
        let skills = SkillMigration.learnedSkills(from: Data(legacy.utf8), labelToTool: labels)
        #expect(skills.count == 2 && skills[0].id.count <= 40 && skills[0].id != skills[1].id)
        #expect(skills[0].source == .learned && skills[0].name == "Betis match to calendar")
        #expect(skills[0].allowedTools == ["searchWeb", "createEvent"], Comment(rawValue: "\(skills[0].allowedTools)"))
        #expect(!skills[1].enabled && skills[1].allowedTools == ["createReminder"])
        let r = SkillRegistry(knownTools: { ["searchWeb", "createEvent", "createReminder"] })
        for s in skills { try r.register(s) }
        #expect(r.find("betis football fixtures").first?.id == skills[0].id)
        #expect(r.find("shopping list").isEmpty)
    }

    @Test func garbageFileGivesNoSkills() {
        #expect(SkillMigration.learnedSkills(from: Data("nope".utf8), labelToTool: [:]).isEmpty)
    }
}

@Suite struct SkillIntentTests {
    @Test func skillRequestsAreRecognised() {
        for t in ["use my weekly review skill", "what skills do you have?", "run the plan my day skill", "list your skills", "which saved skills are available", "use my weekly review workflow", "what workflows do you have?"] {
            #expect(SkillIntent.looksLikeSkillRequest(t), Comment(rawValue: t))
        }
        for t in ["what's on my calendar", "he has a great skill at chess", "tell me a joke", ""] {
            #expect(!SkillIntent.looksLikeSkillRequest(t), Comment(rawValue: t))
        }
    }

    @Test func skillCallParsesOnlyAWholeLineReply() {
        #expect(SkillCall.parse("skill_use: weekly-review") == "weekly-review")
        #expect(SkillCall.parse("  `skill_use: Plan-My-Day`  ") == "plan-my-day")
        #expect(SkillCall.parse("```\nskill_use: weekly-review\n```") == "weekly-review")
        #expect(SkillCall.parse("skill_use: weekly-review\nand more text") == nil)
        #expect(SkillCall.parse("Sure! skill_use: weekly-review") == nil)
        #expect(SkillCall.parse("skill_use: not a valid id") == nil)
        #expect(SkillCall.parse("skill_use:") == nil)
        #expect(SkillCall.parse("Here is your week.") == nil)
    }

    @Test func streamedMarkerIsHeldBackOnlyWhileItCouldBeOne() {
        #expect(SkillCall.hidesPartial("skill"))
        #expect(SkillCall.hidesPartial("skill_use: weekly"))
        #expect(!SkillCall.hidesPartial("Skills are useful"))
        #expect(!SkillCall.hidesPartial(""))
        #expect(!SkillCall.hidesPartial("Hello"))
    }

    @Test func instructionListsIdsAndTheReplyFormat() {
        #expect(SkillCall.instruction(index: "").isEmpty)
        let t = SkillCall.instruction(index: "- weekly-review: Summarise the week")
        #expect(t.contains("weekly-review") && t.contains("skill_use: <id>"))
    }
}
