import Foundation

/// Sentry (sentry.io SaaS) as a token connector manifest.
public enum SentryManifest {
    public static let manifest = ConnectorManifest(
        id: "sentry", title: "Sentry", category: "Sentry", symbol: "exclamationmark.triangle",
        brandAsset: "brand-sentry", brandRGB: [0.21, 0.18, 0.35],
        reads: "Your Sentry organizations and unresolved issues.",
        changes: "Nothing. This connector is read-only.",
        networkNote: "Self-hosted Sentry is out of scope; this connector only calls sentry.io REST API /api/0.",
        host: "sentry.io",
        auth: .bearer,
        tokenHelp: "Create a Sentry user auth token with org:read, project:read and event:read scopes.",
        tools: [
            ConnectorToolSpec(
                name: "listSentryOrganizations", title: "List Sentry organizations",
                description: "Lists organizations visible to the Sentry token. Not issues.",
                arguments: [ConnectorArg("search", guide: "Optional words to filter Sentry organizations by name.", rule: .words, maxLength: 60, truncates: true)],
                request: ConnectorRequestSpec(path: "/api/0/organizations/"),
                list: ConnectorListSpec(line: "{slug,id|60} — {name|90}[[ ({status.name,status.id|20})]]",
                                        requiredField: "slug", filterArgument: "search", filterField: "name", limit: 25,
                                        header: "Sentry organizations", empty: "No Sentry organizations were returned.",
                                        emptyFiltered: "No Sentry organizations matched '{value}'."),
                keywords: ["sentry", "sentry organizations", "sentry orgs", "sentry workspace", "sentry account orgs"],
                examples: ["List my Sentry organizations", "What Sentry orgs can this token access?", "Show Sentry workspaces"],
                briefing: true),
            ConnectorToolSpec(
                name: "listSentryIssues", title: "List unresolved Sentry issues",
                description: "Lists unresolved issues for one Sentry organization slug. Not organization listing.",
                arguments: [ConnectorArg("organization", guide: "Sentry organization slug, for example 'the-interstellar-jurisdiction'.", rule: .identifier, maxLength: 80, required: true)],
                request: ConnectorRequestSpec(path: "/api/0/organizations/{organization}/issues/",
                                              query: [ConnectorSlot("query", "is:unresolved"),
                                                      ConnectorSlot("limit", "15")]),
                list: ConnectorListSpec(line: "{shortId,id} — {title,metadata.title|100}[[ ({level|12}, last seen {lastSeen})]][[ in {project.slug,project.name|30}]]",
                                        requiredField: "id", limit: 15,
                                        header: "unresolved Sentry issues", empty: "No unresolved Sentry issues were returned for that organization."),
                keywords: ["sentry", "sentry issues", "sentry unresolved issues", "sentry errors", "sentry issue list"],
                examples: ["List unresolved Sentry issues for organization the-interstellar-jurisdiction", "Show Sentry issues in org acme", "What unresolved Sentry errors are in organization darkgoatie"],
                requires: ["listSentryOrganizations"],
                briefing: true),
        ])
}
