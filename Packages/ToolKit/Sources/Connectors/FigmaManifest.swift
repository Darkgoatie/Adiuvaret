import Foundation

/// Figma as a manifest. Token auth only, read-only tools.
public enum FigmaManifest {
    public static let manifest = ConnectorManifest(
        id: "figma", title: "Figma", category: "Figma", symbol: "paintpalette",
        brandAsset: "brand-figma", brandRGB: [0.95, 0.33, 0.31],
        reads: "Projects, files, and file comments you can already access in Figma.",
        changes: "No changes. Read-only access.",
        networkNote: "Figma has no list-my-files endpoint without a team id; start from your team URL.",
        host: "api.figma.com",
        auth: .header("X-Figma-Token"),
        tokenHelp: "Create a Figma personal access token. For team_id, open your team page in Figma and copy the id from the URL segment after '/team/' and before the team name.",
        tools: [
            ConnectorToolSpec(
                name: "listFigmaTeamProjects", title: "List Figma team projects",
                description: "Lists projects visible to the token in one Figma team. Use this first: Figma has no endpoint to list your files without a team id.",
                arguments: [
                    ConnectorArg("team", guide: "Team ID from the Figma team URL.", rule: .identifier, maxLength: 40, required: true),
                ],
                request: ConnectorRequestSpec(path: "/v1/teams/{team}/projects"),
                list: ConnectorListSpec(itemsKey: "projects", line: "{name|100} (project {id})",
                                        requiredField: "id", limit: 30,
                                        header: "Figma team projects", empty: "No Figma projects were returned for that team."),
                keywords: ["figma team projects", "figma projects in team", "figma team id projects"],
                examples: [
                    "List Figma projects in team 1170245155647481265",
                    "Show Figma team 1170245155647481265 projects",
                    "What Figma projects are in team 1170245155647481265?",
                ]),
            ConnectorToolSpec(
                name: "listFigmaProjectFiles", title: "List Figma project files",
                description: "Lists files in one Figma project id. This does not search all files across your account.",
                arguments: [
                    ConnectorArg("project", guide: "Project ID from a Figma project URL.", rule: .identifier, maxLength: 40, required: true),
                ],
                request: ConnectorRequestSpec(path: "/v1/projects/{project}/files"),
                list: ConnectorListSpec(itemsKey: "files", line: "{name|100} (file {key})[[, updated {last_modified|25}]]",
                                        requiredField: "key", limit: 30,
                                        header: "Figma project files", empty: "No files were returned for that Figma project."),
                keywords: ["figma project files", "figma files in project", "figma project id files"],
                examples: [
                    "List Figma files in project 1234567890",
                    "Show Figma project 1234567890 files",
                    "What files are in Figma project 1234567890?",
                ],
                requires: ["listFigmaTeamProjects"]),
            ConnectorToolSpec(
                name: "listFigmaComments", title: "List Figma file comments",
                description: "Lists comments on one Figma file key. It does not list comments across every file.",
                arguments: [
                    ConnectorArg("file", guide: "File key from a Figma file URL.", rule: .identifier, maxLength: 80, required: true),
                ],
                request: ConnectorRequestSpec(path: "/v1/files/{file}/comments"),
                list: ConnectorListSpec(itemsKey: "comments", line: "#{order_id,id} by {user.handle,user.id|40}: {message,id|140}[[ ({created_at|25})]]",
                                        requiredField: "id", limit: 40,
                                        header: "Figma file comments", empty: "No comments were returned for that Figma file."),
                keywords: ["figma file comments", "figma comments list", "figma feedback comments"],
                examples: [
                    "List Figma comments in file AbCdEF123456",
                    "Show Figma file AbCdEF123456 comments",
                    "What comments are on Figma file AbCdEF123456?",
                ],
                requires: ["listFigmaProjectFiles"]),
        ])
}
