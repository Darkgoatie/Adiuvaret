import Foundation

public enum GitLabManifest {
    public static let manifest = ConnectorManifest(
        id: "gitlab",
        title: "GitLab",
        category: "GitLab",
        symbol: "tray.full",
        brandAsset: "brand-gitlab",
        brandRGB: [0.96, 0.33, 0.21],
        reads: "Your open merge requests, review requests, issues, and active projects on GitLab.com.",
        changes: "Read only.",
        networkNote: "Self-hosted GitLab instances are out of scope. This connector only calls gitlab.com.",
        host: "gitlab.com",
        auth: .header("PRIVATE-TOKEN"),
        tokenHelp: "Create a personal access token on GitLab with read_api scope.",
        tools: [
            ConnectorToolSpec(
                name: "listGitLabMergeRequests",
                title: "List GitLab merge requests",
                description: "Lists open GitLab merge requests assigned to the current user, not issues and not projects.",
                request: ConnectorRequestSpec(
                    path: "/api/v4/merge_requests",
                    query: [
                        ConnectorSlot("scope", "assigned_to_me"),
                        ConnectorSlot("state", "opened"),
                        ConnectorSlot("order_by", "updated_at"),
                        ConnectorSlot("sort", "desc"),
                        ConnectorSlot("per_page", "20"),
                    ]),
                list: ConnectorListSpec(
                    line: "{references.full,reference} {title|90}[[ ({state}, updated {updated_at})]]",
                    requiredField: "title",
                    limit: 20,
                    header: "open GitLab merge requests assigned to you",
                    empty: "No open GitLab merge requests assigned to you."),
                keywords: ["gitlab", "gitlab merge requests", "gitlab assigned merge requests", "gitlab mrs", "gitlab merge request queue"],
                examples: [
                    "What GitLab merge requests are assigned to me?",
                    "List my assigned GitLab merge requests",
                    "Show my open GitLab MRs",
                ],
                briefing: true),
            ConnectorToolSpec(
                name: "listGitLabMergeRequestsToReview",
                title: "List GitLab merge requests to review",
                description: "Lists open GitLab merge requests where the current user is a reviewer, not authored merge requests.",
                request: ConnectorRequestSpec(
                    path: "/api/v4/merge_requests",
                    query: [
                        ConnectorSlot("scope", "reviews_for_me"),
                        ConnectorSlot("state", "opened"),
                        ConnectorSlot("order_by", "updated_at"),
                        ConnectorSlot("sort", "desc"),
                        ConnectorSlot("per_page", "20"),
                    ]),
                list: ConnectorListSpec(
                    line: "{references.full,reference} {title|90}[[ ({state}, updated {updated_at})]]",
                    requiredField: "title",
                    limit: 20,
                    header: "open GitLab merge requests waiting for your review",
                    empty: "No open GitLab merge requests are waiting for your review."),
                keywords: ["gitlab", "gitlab review", "gitlab merge requests to review", "gitlab reviewer", "gitlab code review"],
                examples: [
                    "Which GitLab merge requests are waiting for my review?",
                    "List GitLab MRs I need to review",
                    "Show my GitLab review queue",
                ],
                briefing: true),
            ConnectorToolSpec(
                name: "listGitLabIssues",
                title: "List GitLab issues",
                description: "Lists open GitLab issues assigned to the current user, not merge requests and not projects.",
                request: ConnectorRequestSpec(
                    path: "/api/v4/issues",
                    query: [
                        ConnectorSlot("scope", "assigned_to_me"),
                        ConnectorSlot("state", "opened"),
                        ConnectorSlot("order_by", "updated_at"),
                        ConnectorSlot("sort", "desc"),
                        ConnectorSlot("per_page", "20"),
                    ]),
                list: ConnectorListSpec(
                    line: "{references.full,reference} {title|90}[[ ({state}, updated {updated_at})]]",
                    requiredField: "title",
                    limit: 20,
                    header: "open GitLab issues assigned to you",
                    empty: "No open GitLab issues are assigned to you."),
                keywords: ["gitlab", "gitlab issues", "gitlab assigned issues", "gitlab bugs", "gitlab tickets"],
                examples: [
                    "What GitLab issues are assigned to me?",
                    "List my open GitLab issues",
                    "Show my assigned GitLab tickets",
                ],
                briefing: true),
            ConnectorToolSpec(
                name: "listGitLabProjects",
                title: "List GitLab projects",
                description: "Lists the current user's GitLab projects by recent activity, not merge requests and not issues.",
                request: ConnectorRequestSpec(
                    path: "/api/v4/projects",
                    query: [
                        ConnectorSlot("membership", "true"),
                        ConnectorSlot("order_by", "last_activity_at"),
                        ConnectorSlot("per_page", "15"),
                    ]),
                list: ConnectorListSpec(
                    line: "{path_with_namespace,name_with_namespace,name}[[ ({visibility}, last activity {last_activity_at})]]",
                    requiredField: "name",
                    limit: 15,
                    header: "GitLab projects by last activity",
                    empty: "No GitLab projects found."),
                keywords: ["gitlab", "gitlab projects", "gitlab repositories", "gitlab repos", "gitlab my projects"],
                examples: [
                    "What are my current GitLab projects?",
                    "List my GitLab repositories",
                    "Which GitLab projects were active recently?",
                ],
                briefing: true),
        ])
}
