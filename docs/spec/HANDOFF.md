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

## Next
33, then kill switch (task 23), 34, 21, 19.
