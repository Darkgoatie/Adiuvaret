# Handoff

Updated: 2026-10-07, after build 0.2.0 (13)

## State
Stage 1 is running. Live chat on Apple's on-device model, calendar read (date ranges resolved in code), reminder create with approval and Undo, Markdown rendering, drawer with real chat history, chats saved with SwiftData. TestFlight latest: 0.2.0 (13). Tasks 16, 17 and 18 are in progress, waiting for device results. Tasks 12-15 and 30-32 done.

## Release
GitHub Actions workflow `testflight.yml` (runner xcode-27, Xcode 27.0, cloud signing). Trigger: `gh workflow run testflight.yml -R Darkgoatie/Adiuvaret -f upload=true`. Build number = highest ASC build for MARKETING_VERSION + 1 (FIRST_BUILD in the workflow for a new version). Secret ASC_KEY_P8 is set in the repo. The WSL VM remains for local package tests and simulator builds only. Only build when the user says so.

## Rules from the user
Impeccable before UI. Apple docs only for local-model work (docs/apple/). Native SwiftData for storage. No self-verifying screenshots: ship to TestFlight and wait for results. Sub-agents use gpt-5.3-codex. Commit after each change, short subject.

## Open
- Device results for builds 12 and 13 (Markdown, drawer, chat restore, calendar older than a week).
- iPhone iOS version (decides task 35). Decision 005 scope (task 36).
- Known gaps: kill switch and Open in Reminders not wired; no TTFT logging; Pro locked rows undecided.

## Built since build 13 (not yet on TestFlight)
- Task 33: model context restored from saved chats (last 12 messages), chat rename (long-press), store reopen test.
- Task 23: global kill switch (AppSettings + shared PolicyEngine), Settings screen toggle, banner in every chat.
- Task 34: ToolKit package + skills: readCalendar with search, findFreeTime, createEvent, moveEvent, deleteEvent. Event handles e1, e2. Undo for create and move; delete confirmed, no Undo.
- 35 tests pass on the VM (policy 13, design 3+4, persistence 5, toolkit 10); app compiles.

## Tool routing (task 37)
Catalog in Packages/ToolKit, router in App/Runtime/ToolRouter.swift, session rebuilt per tool set in LiveChatService. 52 package tests pass; app compiles. Open: extra latency per message, router accuracy on device, approval cards for future write tools.

## Next
Wait for the user to say build, then device results. After that: 21 (activity log), 19 (memory), 22 (integrations), 35 (reasoning, needs iOS version), 36 (needs user).

## Skill system (decision 18, tasks 55-61)
Built; compile check green on Xcode 27 (run 38322855528, 25 skill tests, signed export, not uploaded). Packages/SkillKit (AgentSkill, SkillRegistry, BuiltinSkills, SkillImport, SkillMigration, SkillIntent/SkillCall). App: SkillRegistryHub (shared registry, one-time migration of skills.json), SkillHub (match, offer, save), SkillTools (skill_use for Apple), SkillsView under Memory. MLX and Cloud: matched skill body is injected and its read-only tools run in code; models can also reply `skill_use: <id>`. Cloud sees only web-only skills. Device check pending.

## Browser agent on TUMOnline (2026-10-13)
Device report 1: "Check my TUM Calendar" after sign-in answered from the iPhone calendar. Cause: "calendar" blocked the browse intent and the router ignored an open page. Fix a03c38f (task 68), in build 10; build 10 had to be added to the Internal TestFlight group by API (task 71).
Device report 2: the agent looped Looked at page / Close. Cause: the listing only held elements in view and uncovered; the Calendar link was not listed. Fix be7f6d3 and fcc4043 (task 69): `find` searches the whole page by label, off-screen matches are marked, an identical listing triggers a repeat notice.
Site notes (decision 20, task 67, 59cd81f): click labels per host kept on the phone and shown on the next openWebsite.
Open: a link behind an open overlay is still skipped; the model could ignore the repeat notice (a hard stop after N identical steps is the stricter option); TUMOnline's real markup was never seen. Swift for 67 to 69 is compiled for the first time by the next Xcode Cloud run.

## Tasks 20, 21, 26, 70 and the Privacy screen (2026-10-13)
Built, committed, not compiled and not pushed. Order of commits: c087116 site notes screen, 116a8f2 activity log, c29873c privacy screen, 0c745db notes and tasks, 7932086 evals.
- 70: Settings > Site notes lists click routes per host; SiteNoteStore.shared is used by WebSession and the screen.
- 21: PolicyGate takes an optional observer; ToolHost passes one that writes an ActivityEntry. Advanced > Activity log shows them. No arguments or results are stored.
- Privacy: Settings > Privacy reads live state (providers connected, source per category, connector switches, strict web, kill switch) and has five erase buttons.
- 20: SavedItem store in ToolKit; tools saveItem (reversibleWrite, approval card, Undo) and findSavedItems; Advanced > Notes and Tasks with a Send to Reminders swipe. The catalog wording was tuned in a Python port of the scorer so every example still finds its own tool.
- 26: Packages/Evals with 64 cases, EvalsTests, and Settings > Testing > Evals. The package is a new library in Package.swift and project.yml.
Open: every Swift file here compiles for the first time in the next Xcode Cloud run; the catalog test and the new package tests run only on a runner. Nothing was tested on the phone. The blueprint in Obsidian does not mention these screens yet.

## Standard connector format (2026-10-13)
Designed, not built: decision 29, docs/spec/modules/Connectors.md, tasks 78 to 85. Core model: one ConnectorManifest per connector, everything else derived. Order: 78 spike, 79, 80, 81, 82, 83 (migrate the three existing), 84, 85. Open: whether the Apple model accepts runtime tool schemas (task 78). Needs the user's yes on the core model before code. Catalog scorer port: scratch catsim.py. Nothing compiled; tasks 20, 21, 26, 70 and Privacy still await run 13.
Connector build started: 78 decided (generated files). Packages/ToolKit/Sources/Connectors has ConnectorManifest (types), ConnectorEngine (requests, list formatting, approval rows, intent, undo) with ConnectorValidator, TodoistManifest as the first value. ConnectorManifestTests compare the manifest output with the hand-written Todoist code. ServiceHost.hosts now merges registry hosts. Not compiled; Todoist is not yet switched over. Next: GitHub and Notion manifests (GitHub commits needs the NativeStep), then 82.
Six token manifests added (task 86, 8794ae0): Slack, Discord, Figma, Monday, GitLab, Bitbucket, registered in ConnectorRegistry. Engine itemsKey now walks dotted paths and array indexes. Bitbucket's saved repo fixture is a 404 error page (public listing no longer answers), so its parse test uses a doc-derived payload; Slack's top-level `matches` workaround was removed in favour of messages.matches. Nothing compiled; no manifest is reachable from chat yet, that needs tasks 82 to 84. OAuth apps (task 87) wait on a user decision.
Eight more manifests registered (task 88): Linear, Asana, ClickUp, Airtable, Sentry, Vercel, Dropbox, Calendly. Engine: a single object under itemsKey is one item (Calendly profile), line fields index arrays. Not done: filterFields, Airtable field previews, keys containing dots. Airtable shows ids only. Nothing compiled; none reachable from chat until tasks 82 to 84.
