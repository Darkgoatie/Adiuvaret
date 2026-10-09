# Decision 013: Connectors for popular tools

Status: proposed, 2026-10-09. Needs the user's yes on the network rule below before any token-based connector ships.

## What a connector is

A connector gives the assistant a few tools for one outside app. It is built from the pieces that already exist: a `ToolDescriptor` with a permission tier, a catalog entry (decision 009), an executor behind `PolicyGate`, and a row in the Integrations screen (task 22). It adds no new way to run code. Each connector can be switched off on its own, and the kill switch stops all of them.

Rules every connector follows:
- Read tools are read-only tier. Anything that writes or sends needs approval and Undo where the service allows it.
- Content from a connector is untrusted data, like a web page. It can never change permissions.
- Secrets live in the Keychain, never in SwiftData, logs or the diagnostics file.
- The Integrations screen shows what the connector can read, what it can change, and where data goes.

## Sorted by effort

Easy (no account, no new network path): built with an iOS system API or a file the user picks.
- Obsidian and any Markdown folder: the user picks the vault folder once (security-scoped bookmark). Read, search, create and append to notes. No network at all. Works with iCloud Drive and Files providers.
- Contacts: CNContactStore, read-only lookup of a person's phone, email and birthday.
- Shortcuts: run a named shortcut through the `shortcuts://` scheme with approval. This reaches Todoist, Notion, Things and anything else the user already automated.
- Email drafts: compose a draft in the system mail sheet. The user presses send. Works with Gmail, iCloud or any account set up in Mail.
- Google Calendar: needs no connector. iOS Calendar already holds Google accounts added under Settings, Calendar, Accounts, so EventKit reads and writes them. The work is showing which account each event comes from and letting the user choose a default calendar.

Medium (a token the user pastes, plain REST, a new network exception):
- Notion (internal integration token), Todoist (API token), GitHub (fine-grained token, issues and notifications).
- Each needs the Keychain store, a host allowlist for that service only, and a short explanation that the request leaves the phone.

Hard (OAuth, reviews or a server):
- Gmail read and search. Google marks Gmail read access as a restricted scope. A private test app works for up to 100 named users, a public one needs a security assessment. It also needs OAuth in a web sheet and token refresh.
- Google Drive and Docs, Slack, Microsoft 365: OAuth and admin consent.
- Apple Notes: no public API. The share sheet and Shortcuts are the only paths.

## Network rule (needs the user's yes)

Decision 011 allows one network exception: model downloads. Medium connectors would add a second: calls to a service the user connected, to that service's host only, with the user's own token. Chats and memory are never sent. The connector list in Settings shows each allowed host.

## Order

1. Connector framework (task 44) first: protocol, Keychain store, Integrations rows, per-connector switch, tests.
2. Obsidian folder (45), Contacts (46), Shortcuts (47), email draft (48), calendar accounts (49) are independent after 44.
3. Notion, Todoist and GitHub wait for the network rule answer.
4. Gmail waits until the user decides whether the app stays private (OAuth in testing mode is enough) or goes public.
