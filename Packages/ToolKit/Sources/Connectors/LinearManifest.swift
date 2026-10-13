import Foundation

public enum LinearManifest {
    private static let assignedIssuesQuery = #"query { viewer { assignedIssues(first: 20, filter: { state: { type: { nin: ["completed", "canceled"] } } }) { nodes { identifier title state { name } dueDate } } } }"#
    private static let teamsQuery = #"query Teams { teams(first: 20) { nodes { id key name } } }"#

    public static let manifest = ConnectorManifest(
        id: "linear", title: "Linear", category: "Linear", symbol: "list.bullet.clipboard",
        brandAsset: "brand-linear", brandRGB: [0.36, 0.34, 0.96],
        reads: "Open issues assigned to you and the teams you can access in Linear.",
        changes: "Read only.",
        networkNote: "Calls only POST /graphql on api.linear.app with fixed GraphQL query strings.",
        host: "api.linear.app",
        auth: .rawAuthorization,
        tokenHelp: "Create a personal API key in Linear: Settings → Security & access.",
        tools: [
            ConnectorToolSpec(
                name: "listLinearIssues", title: "List Linear issues",
                description: "Lists your open assigned Linear issues with state and due date. It does not list teams.",
                arguments: [ConnectorArg("search", guide: "Optional words to filter issue titles. Empty lists all open assigned issues.", rule: .words, maxLength: 60, truncates: true)],
                request: ConnectorRequestSpec(method: "POST", path: "/graphql", body: [ConnectorSlot("query", assignedIssuesQuery)]),
                list: ConnectorListSpec(itemsKey: "data.viewer.assignedIssues.nodes",
                                        line: "{identifier} {title|100} — {state.name}[[ (due {dueDate})]]",
                                        requiredField: "identifier", filterArgument: "search", filterField: "title", limit: 20,
                                        header: "open Linear issues assigned to you", empty: "No open Linear issues are assigned to you.",
                                        emptyFiltered: "No open Linear issues matching '{value}'."),
                intent: ConnectorIntentRule(triggers: ["linear"], blockers: ["add", "create", "new", "update", "edit", "move", "close", "complete", "cancel", "assign"],
                                            skip: ["linear", "issue", "issues", "open", "assigned", "to", "me", "my", "list", "show", "what", "are", "is", "in", "the", "for"],
                                            argument: "search", maxWords: 4),
                keywords: ["linear", "linear issues", "linear assigned issues", "linear open issues", "linear work"],
                examples: ["List my Linear issues", "What open issues are assigned to me in Linear?", "Show my Linear work about onboarding"],
                briefing: true),
            ConnectorToolSpec(
                name: "listLinearTeams", title: "List Linear teams",
                description: "Lists teams visible to the current Linear token. It does not list issues.",
                arguments: [ConnectorArg("search", guide: "Optional words to filter team names.", rule: .words, maxLength: 40, truncates: true)],
                request: ConnectorRequestSpec(method: "POST", path: "/graphql", body: [ConnectorSlot("query", teamsQuery)]),
                list: ConnectorListSpec(itemsKey: "data.teams.nodes",
                                        line: "{key,name|12} — {name|80} (id {id})",
                                        requiredField: "id", filterArgument: "search", filterField: "name", limit: 20,
                                        header: "Linear teams", empty: "No Linear teams were returned.",
                                        emptyFiltered: "No Linear teams matching '{value}'."),
                intent: ConnectorIntentRule(triggers: ["linear"], blockers: ["add", "create", "new", "update", "edit", "move", "close", "complete", "cancel", "assign"],
                                            skip: ["linear", "team", "teams", "list", "show", "what", "which", "can", "i", "see", "my", "in", "the"],
                                            argument: "search", maxWords: 3),
                keywords: ["linear", "linear teams", "linear team list", "linear workspace teams", "linear groups"],
                examples: ["List my Linear teams", "Which teams can this Linear token access?", "Show the Linear team list"],
                briefing: true),
        ])
}
