# UI inventory

Source: the user's UI Build Brief (received 2026-10-07, companion to docs/BRIEF.md). This file indexes it and maps it to Stage 1. Per-screen states are added as screens are built. Impeccable skill is loaded before any UI work.

## Navigation
Chat is home. Left slide-over drawer (custom container, drag gesture, dimmed overlay, VoiceOver via menu button). Route enum for deep links and App Intents. Sheets: model switcher, per-chat settings, approvals, outbound preview, paywall, briefing editor.

## Milestones and Stage 1 scope (Stage 1 = local models only, decision 003)
| Milestone | Content | Stage 1 |
|---|---|---|
| M1 | DesignSystem tokens + components, chat shell, composer, drawer, demo mode | yes |
| M2 | ActionCard/Undo, ApprovalCard/Sheet, DraftCard, MemoryChip, Memory, Notes and Tasks, Activity log | yes |
| M3 | Integrations, Shortcuts picker, Settings, permission primers, first run | yes |
| M4 | Briefings list/edit/detail, reliability helper, widgets | yes (Phase 2 of main brief) |
| M5 | Models, cloud setup, MLX library, privacy dashboard, outbound preview, escalation, model switcher, paywall | deferred; only Apple Intelligence status shown |
| M6 | Accessibility audit, localization, haptics, long-chat performance | yes |

Stage 1 hides or omits: EscalationPrompt, cloud badge flows, outbound preview, Think harder, cloud/MLX rows (shown as Coming later at most), Local only switch as a toggle (the app is always local).

## Screens
Chat, Drawer, Notes and Tasks, Briefings (list, edit, detail), Integrations (overview, detail, Shortcuts picker), Memory, Models, Privacy, Activity log, Settings, Onboarding, Paywall.

## Cross-cutting states
AI unavailable/downloading, no permissions, permission denied, offline, model warming, hot/Low Power, approval timed out, undo expired, empty states (chats, memory, notes, briefings, activity), free-tier limit, generation stopped, kill switch active.

## Open conflicts with earlier decisions
- Brief says system fonts only; decision 002 says Google Sans, Google Sans Flex, Archivo Black (chat title).
- Brief says "work in order of Section 14" but the milestones are Section 16; using Section 16.
