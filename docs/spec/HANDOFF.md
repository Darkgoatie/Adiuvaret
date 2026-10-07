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
