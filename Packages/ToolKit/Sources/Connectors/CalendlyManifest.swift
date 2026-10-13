import Foundation

public enum CalendlyManifest {
    public static let manifest = ConnectorManifest(
        id: "calendly",
        title: "Calendly",
        category: "Calendly",
        symbol: "calendar",
        brandAsset: "brand-calendly",
        brandRGB: [0.0, 0.45, 0.85],
        reads: "Your Calendly profile, event types, and active scheduled events.",
        changes: "No changes. Read-only.",
        networkNote: "The list endpoints require a full Calendly user URI (https://api.calendly.com/users/...) from /users/me.",
        host: "api.calendly.com",
        auth: .bearer,
        tokenHelp: "Create a Personal Access Token in Calendly and grant users:read, event_types:read, and scheduled_events:read.",
        tools: [
            ConnectorToolSpec(
                name: "getCalendlyProfile",
                title: "Get Calendly profile",
                description: "Gets the current Calendly user profile, including the canonical user URI needed by other Calendly tools.",
                request: ConnectorRequestSpec(path: "/users/me"),
                list: ConnectorListSpec(
                    line: "{name|80} <{email}>[[ — {timezone}]] ({uri})",
                    requiredField: "uri",
                    limit: 1,
                    header: "Calendly profile rows",
                    empty: "Could not parse the Calendly profile response."),
                keywords: [
                    "calendly profile",
                    "calendly current user",
                    "calendly user uri",
                    "calendly account",
                    "calendly me"
                ],
                examples: [
                    "Show my Calendly profile",
                    "Get my Calendly user URI",
                    "Who am I in Calendly?"
                ],
                briefing: true),
            ConnectorToolSpec(
                name: "listCalendlyEventTypes",
                title: "List Calendly event types",
                description: "Lists Calendly event types for one user URI. This is event-type configuration, not scheduled meetings.",
                arguments: [
                    ConnectorArg("user", guide: "Full Calendly user URI from getCalendlyProfile, for example https://api.calendly.com/users/AAAAAAAAAAAAAAAA.", maxLength: 200, required: true)
                ],
                request: ConnectorRequestSpec(
                    path: "/event_types",
                    query: [
                        ConnectorSlot("user", "{user}"),
                        ConnectorSlot("active", "true"),
                        ConnectorSlot("count", "20"),
                        ConnectorSlot("sort", "name:asc")
                    ]),
                list: ConnectorListSpec(
                    itemsKey: "collection",
                    line: "{name|90} ({slug|40})[[ — {duration} min]]",
                    requiredField: "uri",
                    limit: 20,
                    header: "Calendly event types",
                    empty: "No Calendly event types were returned for that user URI."),
                keywords: [
                    "calendly event types",
                    "calendly meeting types",
                    "calendly event type list",
                    "calendly booking types",
                    "calendly event templates"
                ],
                examples: [
                    "List my Calendly event types",
                    "Show Calendly event types for my user URI",
                    "What meeting types do I have in Calendly?"
                ],
                requires: ["getCalendlyProfile"],
                briefing: true),
            ConnectorToolSpec(
                name: "listCalendlyScheduledEvents",
                title: "List Calendly scheduled events",
                description: "Lists active scheduled Calendly events for one user URI. This is booked events, not event type templates.",
                arguments: [
                    ConnectorArg("user", guide: "Full Calendly user URI from getCalendlyProfile, for example https://api.calendly.com/users/AAAAAAAAAAAAAAAA.", maxLength: 200, required: true)
                ],
                request: ConnectorRequestSpec(
                    path: "/scheduled_events",
                    query: [
                        ConnectorSlot("user", "{user}"),
                        ConnectorSlot("status", "active"),
                        ConnectorSlot("count", "10")
                    ]),
                list: ConnectorListSpec(
                    itemsKey: "collection",
                    line: "{name|90} — {start_time} to {end_time} ({status})",
                    requiredField: "uri",
                    limit: 10,
                    header: "active Calendly scheduled events",
                    empty: "No active Calendly scheduled events were returned for that user URI."),
                keywords: [
                    "calendly scheduled events",
                    "calendly meetings",
                    "calendly upcoming events",
                    "calendly booked events",
                    "calendly event schedule"
                ],
                examples: [
                    "List my active Calendly scheduled events",
                    "Show my upcoming Calendly events",
                    "What meetings are scheduled in Calendly?"
                ],
                requires: ["getCalendlyProfile"],
                briefing: true),
        ])
}
