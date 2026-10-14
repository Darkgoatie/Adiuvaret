import Testing
import Foundation
@testable import ToolKit

@Suite struct ToolEvidenceTests {
    private let catalog = ToolCatalog.standard

    private func offered(_ prompt: String, previous: String? = nil, otherMatch: Bool = false) -> [String] {
        let hits = catalog.search(primary: "", secondary: prompt).map(\.entry)
        return ToolEvidence.filter(catalog.withRequirements(hits, cap: 6), prompt: prompt, previous: previous, otherMatch: otherMatch).map(\.id)
    }

    @Test func realCalendarRequestsKeepTheirTools() {
        for p in ["What's on my calendar tomorrow?", "Do I have anything next week?", "Add lunch with Ana tomorrow at 13:00 to my calendar",
                  "Move my 10:00 meeting to 14:00", "When am I free this week?", "Remind me to call mom in 30 minutes", "Which reminders are overdue?",
                  "Cancel my 3pm meeting", "tell me about my week", "Find me an hour free on Friday", "Book a haircut on Saturday at 11",
                  "Schedule a call on Monday at 10", "What's on my to-do list?", "Is there a gap for a 30 minute call?", "Push lunch back an hour",
                  "Don't let me forget to buy milk", "Set a reminder to pay rent", "Show my pending tasks"] {
            #expect(ToolEvidence.calendarAllowed(prompt: p, previous: nil, otherMatch: false), Comment(rawValue: p))
        }
    }

    @Test func serverAndApiRequestsGetNoCalendar() {
        for p in ["restart my hetzner server", "schedule the backup job on the server", "list my servers again", "move the files to the server",
                  "add the invoice to my list", "what is on for the project", "set up the webhook", "create a new project in linear"] {
            let ids = offered(p)
            #expect(!ids.contains { catalog.entry($0)?.category == "Calendar" || catalog.entry($0)?.category == "Reminders" }, Comment(rawValue: "\(p) -> \(ids)"))
        }
    }

    @Test func aWeakWordAloneStillWorksWhenNothingElseMatches() {
        #expect(ToolEvidence.calendarAllowed(prompt: "anything tomorrow?", previous: nil, otherMatch: false))
        #expect(!ToolEvidence.calendarAllowed(prompt: "anything tomorrow?", previous: nil, otherMatch: true))
    }

    @Test func followUpsContinueACalendarQuestion() {
        #expect(ToolEvidence.calendarAllowed(prompt: "and the day after?", previous: "What's on my calendar tomorrow?", otherMatch: false))
        #expect(!ToolEvidence.calendarAllowed(prompt: "and the day after?", previous: "restart my server", otherMatch: false))
        #expect(!ToolEvidence.calendarAllowed(prompt: "now do the same thing for the other eleven machines in the rack please", previous: "What's on my calendar?", otherMatch: false))
    }

    @Test func otherToolsAreNeverRemoved() {
        let entries = ["callAPI", "searchWeb", "createEvent"].compactMap { catalog.entry($0) }
        let kept = ToolEvidence.filter(entries, prompt: "restart my hetzner server", previous: nil)
        #expect(kept.map(\.id) == ["callAPI", "searchWeb"])
    }
}
