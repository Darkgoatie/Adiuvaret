import Foundation

public enum VercelManifest {
    public static let manifest = ConnectorManifest(
        id: "vercel", title: "Vercel", category: "Vercel", symbol: "triangle",
        brandAsset: "brand-vercel", brandRGB: [0.00, 0.00, 0.00],
        reads: "Projects and recent deployments visible to the token.",
        changes: "No writes. Read-only access.",
        networkNote: "Only project listing and deployment listing requests are sent.",
        host: "api.vercel.com",
        auth: .bearer,
        tokenHelp: "Create a Vercel access token (vcp_) scoped to the account, team, or project. For this connector, grant Projects and Deployments read access.",
        tools: [
            ConnectorToolSpec(
                name: "listVercelProjects", title: "List Vercel projects",
                description: "Lists Vercel projects visible to the token. It does not list deployment history.",
                arguments: [
                    ConnectorArg("search", guide: "Optional words to filter project names.", rule: .words, maxLength: 60, truncates: true),
                ],
                request: ConnectorRequestSpec(path: "/v9/projects",
                                              query: [
                                                ConnectorSlot("limit", "20"),
                                                ConnectorSlot("search", "{search}", omitIfEmpty: true),
                                              ]),
                list: ConnectorListSpec(itemsKey: "projects", line: "{name|90} (project {id})[[ — {framework|20}]][[ — updated {updatedAt,createdAt}]]",
                                        requiredField: "id", filterArgument: "search", filterField: "name", limit: 20,
                                        header: "Vercel projects", empty: "No Vercel projects found.",
                                        emptyFiltered: "No Vercel projects matching '{value}'."),
                intent: ConnectorIntentRule(triggers: ["vercel", "project", "projects"], blockers: ["add", "create", "delete", "remove", "update", "deploy", "deployment", "deployments"],
                                            skip: ["vercel", "project", "projects", "list", "show", "what", "which", "are", "is", "my", "can", "this", "token", "access", "accessible", "named", "the", "me"],
                                            argument: "search", maxWords: 3),
                keywords: ["vercel projects", "vercel project list", "vercel project names", "vercel accessible projects", "vercel project ids"],
                examples: ["List my Vercel projects", "Show Vercel projects named docs", "What Vercel projects can this token access?"],
                briefing: true),
            ConnectorToolSpec(
                name: "listVercelDeployments", title: "List Vercel deployments",
                description: "Lists recent Vercel deployments with name, state, URL, and created timestamp. It does not return build logs.",
                arguments: [
                    ConnectorArg("search", guide: "Optional words to filter deployment names.", rule: .words, maxLength: 60, truncates: true),
                    ConnectorArg("project", guide: "Optional Vercel project ID or name from listVercelProjects.", rule: .identifier, maxLength: 96),
                ],
                request: ConnectorRequestSpec(path: "/v6/deployments",
                                              query: [
                                                ConnectorSlot("limit", "10"),
                                                ConnectorSlot("projectId", "{project}", omitIfEmpty: true),
                                              ]),
                list: ConnectorListSpec(itemsKey: "deployments", line: "{name|80} ({state,readyState|16}) — {url|90} (created {created,createdAt})",
                                        requiredField: "uid", filterArgument: "search", filterField: "name", limit: 10,
                                        header: "Vercel deployments", empty: "No Vercel deployments were returned.",
                                        emptyFiltered: "No Vercel deployments matching '{value}'."),
                intent: ConnectorIntentRule(triggers: ["vercel", "deployment", "deployments", "deploy"], blockers: ["add", "create", "delete", "remove", "cancel", "rollback"],
                                            skip: ["vercel", "deployment", "deployments", "deploy", "list", "show", "recent", "my", "what", "which", "are", "is", "for", "the", "in", "on", "me", "project"],
                                            argument: "search", maxWords: 3),
                keywords: ["vercel deployments", "vercel deployment list", "vercel deployment states", "vercel deployment urls", "vercel recent deploys"],
                examples: ["List my recent Vercel deployments", "Show Vercel deployments for docs", "Which Vercel deployments are in error state?"],
                requires: ["listVercelProjects"],
                briefing: true),
        ])
}
