import Foundation

/// Bitbucket Cloud as a token connector manifest.
public enum BitbucketManifest {
    public static let manifest = ConnectorManifest(
        id: "bitbucket", title: "Bitbucket", category: "Bitbucket", symbol: "arrow.triangle.branch",
        brandAsset: "brand-bitbucket", brandRGB: [0.0, 0.45, 0.85],
        reads: "Your Bitbucket repositories and open pull requests.",
        changes: "Nothing. This connector is read-only.",
        networkNote: "Bitbucket repository/workspace access tokens are scoped and sent as Bearer tokens.",
        host: "api.bitbucket.org",
        auth: .bearer,
        tokenHelp: "Paste a Bitbucket repository or workspace access token. Atlassian docs show these tokens are used as 'Authorization: Bearer <token>'; this keeps access scoped and avoids requiring your account email in the token field.",
        tools: [
            ConnectorToolSpec(
                name: "listBitbucketRepos", title: "Bitbucket repositories",
                description: "Lists repositories available through a Bitbucket token, sorted by last update. Not pull requests.",
                request: ConnectorRequestSpec(path: "/2.0/repositories", query: [
                    ConnectorSlot("role", "member"),
                    ConnectorSlot("sort", "-updated_on"),
                    ConnectorSlot("pagelen", "15"),
                ]),
                list: ConnectorListSpec(itemsKey: "values", line: "{full_name}[[ ({language|20})]][[ updated {updated_on}]]",
                                        requiredField: "full_name", limit: 15,
                                        header: "Bitbucket repositories",
                                        empty: "No Bitbucket repositories were returned for this token."),
                keywords: ["bitbucket", "bitbucket repos", "bitbucket repositories", "bitbucket projects", "bitbucket workspace repos"],
                examples: ["What Bitbucket repos do I have?", "Show Bitbucket projects", "Which repositories are in Bitbucket workspace atlassian?"],
                briefing: true),
            ConnectorToolSpec(
                name: "listBitbucketPullRequests", title: "List Bitbucket pull requests",
                description: "Lists open pull requests for one Bitbucket repository. Requires workspace and repository slug, and is not a repository list.",
                arguments: [
                    ConnectorArg("workspace", guide: "Workspace slug, for example 'atlassian' or your team slug.", rule: .identifier, maxLength: 80, required: true),
                    ConnectorArg("repo", guide: "Repository slug, for example 'my-repo'.", rule: .identifier, maxLength: 80, required: true),
                ],
                request: ConnectorRequestSpec(path: "/2.0/repositories/{workspace}/{repo}/pullrequests", query: [
                    ConnectorSlot("state", "OPEN"),
                ]),
                list: ConnectorListSpec(itemsKey: "values",
                                        line: "#{id} {title|100}[[ by {author.display_name,author.nickname|30}]][[ ({source.branch.name} → {destination.branch.name})]][[ updated {updated_on}]]",
                                        requiredField: "title", limit: 20,
                                        header: "open Bitbucket pull requests",
                                        empty: "No open Bitbucket pull requests were returned for that repository."),
                keywords: ["bitbucket", "bitbucket pull requests", "bitbucket prs", "bitbucket open pr", "bitbucket reviews"],
                examples: ["List open Bitbucket pull requests for workspace atlassian repo atlaskit-mk-2", "Show Bitbucket PRs for workspace myteam repo mobile-app", "Which open PRs are in Bitbucket repo darkgoatie adiuvaret"],
                requires: ["listBitbucketRepos"],
                briefing: true),
        ])
}
