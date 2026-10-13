import Foundation

public enum AsanaManifest {
    public static let manifest = ConnectorManifest(
        id: "asana", title: "Asana", category: "Asana", symbol: "checkmark.circle",
        brandAsset: "brand-asana", brandRGB: [0.95, 0.42, 0.40],
        reads: "Workspaces you can access and tasks assigned to you in one workspace.",
        changes: "No writes. Read-only access.",
        networkNote: "Only workspace listing and assignee task listing requests are sent.",
        host: "app.asana.com",
        auth: .bearer,
        tokenHelp: "Create a personal access token in Asana. Required scopes: workspaces:read and tasks:read.",
        tools: [
            ConnectorToolSpec(
                name: "listAsanaWorkspaces", title: "List Asana workspaces",
                description: "Lists Asana workspaces visible to the token. It does not list tasks.",
                arguments: [
                    ConnectorArg("search", guide: "Optional words to filter workspace names.", rule: .words, maxLength: 60, truncates: true),
                ],
                request: ConnectorRequestSpec(path: "/api/1.0/workspaces"),
                list: ConnectorListSpec(itemsKey: "data", line: "{name|100} (workspace {gid})",
                                        requiredField: "gid", filterArgument: "search", filterField: "name", limit: 25,
                                        header: "Asana workspaces", empty: "No Asana workspaces found.",
                                        emptyFiltered: "No Asana workspaces matching '{value}'."),
                intent: ConnectorIntentRule(triggers: ["asana", "workspace", "workspaces"], blockers: ["add", "create", "update", "delete", "task", "tasks"],
                                            skip: ["asana", "workspace", "workspaces", "list", "show", "what", "which", "are", "is", "my", "can", "i", "access", "visible", "to", "this", "token", "ids"],
                                            argument: "search", maxWords: 3),
                keywords: ["asana workspaces", "asana workspace list", "asana organizations", "asana workspace ids"],
                examples: ["List my Asana workspaces", "Show Asana workspace IDs I can access", "What Asana workspaces are visible to this token?"],
                briefing: true),
            ConnectorToolSpec(
                name: "listAsanaTasks", title: "List Asana tasks",
                description: "Lists tasks assigned to you for one Asana workspace GID. It does not list workspaces.",
                arguments: [
                    ConnectorArg("workspace", guide: "Workspace GID from listAsanaWorkspaces.", rule: .identifier, maxLength: 32, required: true),
                ],
                request: ConnectorRequestSpec(path: "/api/1.0/tasks",
                                              query: [
                                                ConnectorSlot("assignee", "me"),
                                                ConnectorSlot("workspace", "{workspace}"),
                                                ConnectorSlot("completed_since", "now"),
                                                ConnectorSlot("opt_fields", "name,due_on"),
                                              ]),
                list: ConnectorListSpec(itemsKey: "data", line: "{name|120} (task {gid})[[ — due {due_on|20}]]",
                                        requiredField: "gid", limit: 50,
                                        header: "Asana tasks assigned to you", empty: "No Asana tasks were returned for that workspace."),
                intent: ConnectorIntentRule(triggers: ["asana", "task", "tasks"], blockers: ["add", "create", "update", "delete", "complete", "close"],
                                            skip: ["asana", "task", "tasks", "list", "show", "what", "which", "are", "is", "my", "me", "assigned", "to", "in", "workspace", "for", "the"],
                                            argument: "workspace", maxWords: 1, needsArgument: true),
                keywords: ["asana tasks", "asana assigned tasks", "asana task list", "asana my tasks"],
                examples: ["List my Asana tasks for 67890", "Show Asana tasks assigned to me in 67890", "What Asana tasks do I have for 67890?"],
                requires: ["listAsanaWorkspaces"],
                briefing: true),
        ])
}
