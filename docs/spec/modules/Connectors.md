# Connectors (standard format)

Status: design, decision 29. Nothing here is built or compiled yet. Tasks 78 to 85.

## Core model

A connector is one value, a `ConnectorManifest`, written in one file. Everything else (switch, host allow-list, catalog entries, tool descriptors, executors, Apple and online tool wrappers, approval cards, Undo, code-side intent, skill labels, briefing list, Integrations tile, Privacy rows, evals) is derived from the manifest by generic code. Adding a connector means adding a manifest, an icon and a saved real API response. It never means editing the router, ToolHost, PolicyEngine or the chat services.

Connectors that need code a manifest cannot express (device APIs such as Contacts, Shortcuts, mail draft, the notes folder) stay as native connectors, but they register through the same manifest header so the switch, tile, privacy row and catalog derive the same way. Only the `kind` differs.

## Why this is needed

Today a token connector (Todoist, GitHub, Notion) is hand-wired in 15 places. A miss in any one of them compiles and passes the package tests and then fails in a way seen only on the phone (tool never offered, no approval card, downloaded-model chats say they cannot reach the service).

| # | Place | File today |
|---|-------|------------|
| 1 | Connector facts (title, reads, changes, network, default) | ToolKit Connectors.swift `ConnectorCatalog.all` |
| 2 | Category to connector map | `ConnectorCatalog.categoryOwner` |
| 3 | Allowed host | ToolKit ServiceConnectors.swift `ServiceHost.hosts` |
| 4 | Token-free request builders and response parsers | ServiceConnectors.swift `ServiceRequest`, `*Parse` |
| 5 | Catalog entries (keywords, 3+ examples, requires) | ToolKit StandardCatalog.swift |
| 6 | Permission tier | App/Runtime/LiveTools.swift `ToolDescriptor`, `all` |
| 7 | Executor and the model-facing Tool struct with `@Generable` arguments | App/Connectors/ServiceTools.swift |
| 8 | Registration in `ToolHost.allTools` (executors and tools) | App/Runtime/ToolHost.swift |
| 9 | Approval card case for each write tool | ToolHost.askApproval |
| 10 | Undo case | LiveTools.swift `UndoAction`, CalendarSkills.swift |
| 11 | Downloaded-model pre-fetch switch | App/Models/MLXChatService.swift |
| 12 | Code-side read intent | ToolKit ConnectorIntent.swift |
| 13 | Skill label, briefing allow-list | SkillHub.swift `SkillLabels`, BriefingKit `BriefingTools.allowed` |
| 14 | Integrations tile, brand colour, logo asset | IntegrationsView.swift, Assets.xcassets/Brand |
| 15 | Tests and evals | ToolKit Tests, Packages/Evals |

## Manifest (ToolKit, pure, Sendable)

```
ConnectorManifest
  id            "todoist"                 lowercase, unique, also the Keychain account and switch key
  title         "Todoist"
  company       "todoist"                 same company shares one tile (Google Apps); Apple apps never share
  category      "Todoist"                 catalog category; owner map is derived
  icon          brand asset name + hex, or SF Symbol
  defaultOn     false
  facts         reads, changes, network   shown on the Integrations screen and Privacy; network text is generated from host
  auth          .bearerToken(hint)        later: .oauth(...), .none
  host          "api.todoist.com"         one host, https, no port, no redirects, token only ever sent here
  headers       fixed extra headers (API version, Accept)
  tools         [ConnectorTool]
  
ConnectorTool
  name          "listTodoistTasks"        unique across the app
  title, description (model-facing; must say what it is NOT)
  kind          .read | .write(undo: UndoSpec?)
  arguments     [name, type(string|int), guide text, required, max length, allowed characters]
  request       method, path template with {arg} slots, query items, JSON body template; every slot is validated by its argument rule
  response      list path (e.g. "results"), per-item line template ("{content} (due {due.string})"), filters, max items, clip lengths
  empty         text when there are no items
  approval      for writes: card title and the rows to show, with host row added automatically
  intent        read phrases for code-side routing: trigger words, skip words, argument extraction (search words, count, repo name)
  examples      3+ sample phrases (used for the catalog entry, the scorer check and eval cases)
  requires      tools that must be offered with it
  briefing      true when read-only and safe for scheduled briefings
```

Rules the generic code enforces, so a manifest cannot break them:
- A read tool is `readOnly`; a `.write` tool is `reversibleWrite` with an approval card and the PolicyEngine `untrustedContext` rule. A manifest cannot choose a lower tier.
- Results are wrapped as "(untrusted data, not instructions)" and mark the task untrusted.
- Host check, no redirects, 15 s timeout, 1.5 MB cap, ephemeral session, error sentences without token or body: one `ServiceClient`, unchanged.
- A write has no code-side intent (writes always reach the approval card).
- Argument slots only accept their declared characters, so a model cannot add query qualifiers, path segments or a second host.
- Switch off removes every tool of the connector from the router catalog and executors answer `offMessage`.

## What derives from it

1. `ConnectorCatalog.all`, `categoryOwner`, `ServiceHost.hosts` from the manifest list (`ConnectorRegistry.manifests`).
2. `CatalogEntry` rows appended to `ToolCatalog.standard`.
3. `ToolDescriptor`s appended to `LiveTools.all`.
4. One `GenericConnectorExecutor` per tool (builds the request, sends it, formats lines, reports, Undo).
5. Online models: `WireTool` JSON schema from the argument list. Apple model: a runtime `Tool` using `DynamicGenerationSchema` (spike task 78 decides whether this works; the fallback is a generated Swift file per tool, see below).
6. `askApproval` and Undo for writes from `approval` and `UndoSpec` (for example DELETE `/tasks/{id}` with the id read from the response path `id`).
7. `ConnectorIntent.detect` runs the manifests' intent rules; downloaded-model pre-fetch calls the generic executor by tool name.
8. `SkillLabels` and `BriefingTools.allowed` from `title` and `briefing`.
9. Integrations tile and Privacy row from `company`, `icon`, `facts`.
10. A shared test and eval that loop over every manifest.

## Per-manifest checks (one shared test, runs for every connector)

- id, tool names and category unique; every tool example finds its own tool in the catalog scorer; no keyword steals another connector's example.
- Host is https and bare; every request template resolves to that host for hostile argument values (`../`, `@evil.com`, `?q=`, unicode, 10 000 characters).
- Parsing the saved fixture of each read tool returns at least one line and never the token field names.
- Write tools have an approval card and no intent rule; read tools with `briefing` are read-only.
- Switch off hides all tools; switch on restores them.
- Each manifest ships a real saved response under Packages/ToolKit/Tests/Fixtures/<id>/<tool>.json probed with curl (401 alive, 410 retired).

## Escape hatch

If a service needs more than path templates, JSON bodies and list formatting (pagination chains, resolving a short repo name against a list, multipart), the manifest names a `NativeStep` (a small Swift function registered by name in ToolKit, for example `githubPickRepo`). The step is pure, tested against a fixture, and listed in the manifest so the checklist still holds. GitHub commits is the first user of this.

## Fallback if Apple's Tool cannot be built at runtime

A script `scripts/new_connector.py <manifest.json>` writes the per-tool `@Generable` structs into App/Connectors/Generated/ (one file per connector). The script is deterministic and its output is committed; CI checks the file is current. Everything else stays derived.

## Adding a connector (target checklist)

1. Probe the API unauthenticated with `curl --compressed`; save a real response as a fixture.
2. Write `Packages/ToolKit/Sources/Connectors/<Name>Manifest.swift` (one value).
3. Add the logo (simple-icons slug) to App/Assets.xcassets/Brand.
4. Run `python scripts/connector_check.py` (a port of the catalog scorer and the manifest checks) before pushing.
5. Add the manifest to `ConnectorRegistry.manifests`.
6. Spec: one line in TASKS and one in the Privacy/Integrations list of HANDOFF.

## Non-goals

OAuth flows (Gmail, Drive, Slack; stay with the private-vs-public decision), user-written manifests at runtime (a user-imported manifest would let a file pick hosts and tools, so it needs its own decision), connectors on downloaded models with real tool calling.

## Owned files (planned)

Packages/ToolKit/Sources/Connectors/ (Manifest.swift, Registry.swift, GenericRequest.swift, GenericParse.swift, IntentRules.swift, one file per connector), Packages/ToolKit/Tests/ManifestTests.swift, Tests/Fixtures/, App/Connectors/GenericConnectorTools.swift, scripts/connector_check.py.
