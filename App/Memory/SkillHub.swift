import Foundation
import MemoryKit
import ToolKit
import Diagnostics

/// The app's one skill store, plus the step that decides whether a finished task is worth offering as a skill.
@MainActor
enum SkillHub {
    static let store = SkillStore.standard()

    /// What each tool is called in a playbook. Anything unlisted falls back to its id.
    private static let labels: [String: String] = [
        "readCalendar": "Check the calendar", "findFreeTime": "Find free time", "createEvent": "Add the event", "moveEvent": "Move the event",
        "deleteEvent": "Delete the event", "createReminder": "Add a reminder", "listReminders": "Look at the reminders", "searchWeb": "Search the web",
        "openWebsite": "Open the website", "lookAtPage": "Read the page", "searchNotes": "Search the notes", "readNote": "Read the note",
        "writeNote": "Write the note", "findContact": "Find the contact", "runShortcut": "Run the shortcut", "draftEmail": "Draft the email",
        "listTodoistTasks": "Check Todoist", "addTodoistTask": "Add a Todoist task", "listGitHubIssues": "Check GitHub issues",
        "listGitHubRepos": "Check GitHub repositories", "searchNotion": "Search Notion", "searchPastChats": "Look through earlier chats"]

    struct Offer {
        let title: String
        let playbook: String
    }

    /// A proposal for a task that used two or more different tools, or nil. Tool names only, so nothing personal is kept.
    static func offer(message: String, tools: [String]) -> Offer? {
        guard SkillMath.isWorthSaving(tools: tools) else { return nil }
        let title = SkillMath.suggestedTitle(from: message)
        let playbook = SkillMath.playbook(tools: tools, labels: labels)
        if store.all().contains(where: { $0.playbook == playbook }) { return nil }
        return Offer(title: title, playbook: playbook)
    }

    @discardableResult static func save(title: String, whenToUse: String, playbook: String) -> Bool {
        switch store.add(Skill(title: title, whenToUse: whenToUse, playbook: playbook)) {
        case .added:
            DiagnosticsLog.shared.record("skills", "saved a skill, \(store.all().count) stored")
            return true
        case .duplicate, .full:
            return false
        }
    }

    static func block(for message: String) -> String {
        let text = store.promptBlock(for: message)
        if !text.isEmpty { DiagnosticsLog.shared.record("skills", "added \(text.split(separator: "\n").count - 1) skills to the prompt") }
        return text
    }
}
