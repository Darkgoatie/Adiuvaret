import Foundation

/// Todoist as a manifest. Replaces the hand-written Todoist code once task 83 switches the app over.
public enum TodoistManifest {
    public static let manifest = ConnectorManifest(
        id: "todoist", title: "Todoist", category: "Todoist", symbol: "checklist",
        brandAsset: "brand-todoist", brandRGB: [0.89, 0.27, 0.20],
        reads: "Your open tasks and their due dates.",
        changes: "Adds a task, after you approve.",
        networkNote: "Only the words of the task leave the iPhone.",
        host: "api.todoist.com",
        tools: [
            ConnectorToolSpec(
                name: "listTodoistTasks", title: "List Todoist tasks",
                description: "Lists the user's open Todoist tasks with due dates, optionally filtered by words.",
                arguments: [ConnectorArg("search", guide: "Optional words to look for in task names. Empty lists all.", rule: .words, maxLength: 60, truncates: true)],
                request: ConnectorRequestSpec(path: "/api/v1/tasks", query: [ConnectorSlot("limit", "100")]),
                list: ConnectorListSpec(itemsKey: "results", line: "{content|100}[[ (due {due.string,due.date|30})]][[ {priority==4:[urgent]}]]",
                                        requiredField: "content", filterArgument: "search", filterField: "content", limit: 25,
                                        header: "open Todoist tasks", empty: "No open Todoist tasks.",
                                        emptyFiltered: "No open Todoist tasks matching '{value}'."),
                intent: ConnectorIntentRule(triggers: ["todoist"], blockers: ["add", "create", "put", "new"],
                                            skip: ["tasks", "task", "list", "what", "whats", "is", "on", "my", "the", "show", "do", "i", "have", "any", "in", "a", "about", "for", "me", "open", "today"],
                                            argument: "search", maxWords: 3),
                keywords: ["todoist", "tasks", "task list", "todos", "due today"],
                examples: ["What is on my Todoist today?", "List my Todoist tasks", "Do I have a Todoist task about the bank?"],
                briefing: true),
            ConnectorToolSpec(
                name: "addTodoistTask", title: "Add Todoist task",
                description: "Adds a task to the user's Todoist inbox, with an optional due date in plain words, after the user approves.",
                isWrite: true,
                arguments: [ConnectorArg("content", guide: "The task, in a few words.", maxLength: 300, required: true),
                            ConnectorArg("due", guide: "When it is due in plain words such as 'tomorrow 9am' or 'next Friday'. Empty when no date was given.", maxLength: 60, truncates: true)],
                request: ConnectorRequestSpec(method: "POST", path: "/api/v1/tasks",
                                              body: [ConnectorSlot("content", "{content}"), ConnectorSlot("due_string", "{due}", omitIfEmpty: true)]),
                successText: "Added the task '{content}' to Todoist.",
                createdIDPath: "id",
                undo: ConnectorRequestSpec(method: "DELETE", path: "/api/v1/tasks/{id}"),
                approvalTitle: "Add this task to Todoist?",
                approvalRows: [ConnectorApprovalRow("Task", argument: "content"), ConnectorApprovalRow("Due", argument: "due", whenEmpty: "No date")],
                keywords: ["todoist", "add task", "new task", "put on todoist", "create task"],
                examples: ["Add buy milk to my Todoist", "Put renew passport on Todoist for next Friday", "Create a Todoist task to call the bank"]),
        ])
}
