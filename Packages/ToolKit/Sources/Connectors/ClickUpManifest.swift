import Foundation

/// ClickUp as a token connector manifest.
public enum ClickUpManifest {
    public static let manifest = ConnectorManifest(
        id: "clickup",
        title: "ClickUp",
        category: "ClickUp",
        symbol: "checklist.checked",
        brandAsset: "brand-clickup",
        brandRGB: [0.49, 0.41, 0.93],
        reads: "Your ClickUp Workspaces and tasks visible to the token.",
        changes: "Nothing. This connector is read-only.",
        networkNote: "Personal tokens are sent as a raw Authorization header value, matching ClickUp docs.",
        host: "api.clickup.com",
        auth: .rawAuthorization,
        tokenHelp: "In ClickUp, open Settings → Apps, generate a personal API token (pk_...), then paste it here. ClickUp docs use Authorization: {personal_token} for personal tokens.",
        tools: [
            ConnectorToolSpec(
                name: "listClickUpTeams",
                title: "List ClickUp Workspaces",
                description: "Lists ClickUp Workspaces (teams) available to the authenticated user. Not a task list.",
                arguments: [
                    ConnectorArg("search", guide: "Optional words to filter Workspaces by name.", rule: .words, maxLength: 60, truncates: true),
                ],
                request: ConnectorRequestSpec(path: "/api/v2/team"),
                list: ConnectorListSpec(
                    itemsKey: "teams",
                    line: "{name|80} ({id})[[ • color {color}]]",
                    requiredField: "name",
                    filterArgument: "search",
                    filterField: "name",
                    limit: 30,
                    header: "ClickUp Workspaces",
                    empty: "No ClickUp Workspaces were returned.",
                    emptyFiltered: "No ClickUp Workspaces matching '{value}'."),
                intent: ConnectorIntentRule(
                    triggers: ["clickup"],
                    blockers: ["task", "tasks", "todo", "add", "create", "new", "write", "update"],
                    skip: ["clickup", "workspace", "workspaces", "team", "teams", "list", "show", "my", "what", "can", "i", "access", "available"],
                    argument: "search",
                    maxWords: 3),
                keywords: ["clickup", "clickup workspaces", "clickup teams", "clickup team list", "clickup authorized teams"],
                examples: [
                    "List my ClickUp workspaces",
                    "What ClickUp teams can this token access?",
                    "Show available ClickUp workspaces",
                ],
                briefing: true),
            ConnectorToolSpec(
                name: "listClickUpTasks",
                title: "List ClickUp tasks",
                description: "Lists tasks from one ClickUp Workspace (team) using the filtered team tasks endpoint. Not a Workspace list.",
                arguments: [
                    ConnectorArg("team", guide: "Workspace (team) ID from listClickUpTeams.", rule: .identifier, maxLength: 40, required: true),
                    ConnectorArg("assignee", guide: "Optional ClickUp user ID to filter assigned tasks.", rule: .identifier, maxLength: 40),
                    ConnectorArg("search", guide: "Optional words to filter task names after fetch.", rule: .words, maxLength: 60, truncates: true),
                ],
                request: ConnectorRequestSpec(
                    path: "/api/v2/team/{team}/task",
                    query: [
                        ConnectorSlot("page", "0"),
                        ConnectorSlot("include_closed", "false"),
                        ConnectorSlot("assignees[]", "{assignee}", omitIfEmpty: true),
                    ]),
                list: ConnectorListSpec(
                    itemsKey: "tasks",
                    line: "{name|100} ({id})[[ — {status.status|30}]][[ • list {list.name|40}]][[ • due {due_date}]]",
                    requiredField: "name",
                    filterArgument: "search",
                    filterField: "name",
                    limit: 25,
                    header: "ClickUp tasks",
                    empty: "No ClickUp tasks were returned for that Workspace.",
                    emptyFiltered: "No ClickUp tasks matching '{value}'."),
                keywords: ["clickup", "clickup tasks", "clickup workspace tasks", "clickup team tasks", "clickup assigned tasks"],
                examples: [
                    "List ClickUp tasks for workspace 123",
                    "Show ClickUp tasks in team 7002367",
                    "Get ClickUp tasks for workspace 123 assigned to user 183",
                ],
                requires: ["listClickUpTeams"]),
        ])
}
