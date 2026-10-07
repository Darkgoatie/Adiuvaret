# Adiuvaret spec

Core model: Adiuvaret is an agent harness on iPhone where every model (Apple FM, MLX, cloud) is a swappable brain behind one provider protocol, and every tool call from any of them passes through a provider-independent policy engine before it executes. (unconfirmed)

## Goal
Private, on-device-first personal assistant for iPhone: chat, calendar/reminders/contacts/in-app notes actions, memory, scheduled briefings. Full product brief: docs/BRIEF.md (authoritative for product scope).

## Non-goals (v1)
Local server tier, Mac companion, MCP client, HTTP connector builder, shell/filesystem automation, iCloud sync, Health/Photos, voice, credits proxy, iPad/Mac targets. Reading Messages/Mail/Apple Notes (no public API).

## Constraints
- Swift 6 strict concurrency, SwiftUI, SPM local packages per docs/BRIEF.md section 4. Min iOS = lowest with FoundationModels (to verify, expected 26.0).
- Dependencies flow down; AdiuvaretCore depends on nothing; PolicyEngine depends on no provider.
- Build and device testing happen on the Mac (halit@192.168.0.102); this Windows repo is the source of truth, synced via git.
- Apple Intelligence requires a supported device (iPhone 15 Pro or newer). Real-device spikes need one.

## Glossary
- Tier: 0 Apple FM, 1 MLX, 2 reserved (local server), 3 cloud.
- Policy engine: sole authority on whether a tool call runs, asks, or is denied.
- Untrusted: any content originating from tool output or user data rather than the user's typed turn.
- Handoff packet: compact task state passed when escalating tiers.

## Existing docs
- docs/BRIEF.md: full product and engineering brief.
- docs/VERIFIED_FACTS.md: confirmed platform facts with date and source.
- docs/ARCHITECTURE.md: current architecture.
- docs/decisions/: one file per technical decision (indexed in docs/spec/DECISIONS.md).

## Open questions
- [ ] Confirm the core model sentence above. (user)
- [ ] Which physical iPhone is available for Phase 0 device spikes (model, iOS version, Apple Intelligence enabled)? (user)
- [ ] Apple Developer account / team ID and bundle ID com.halit.adiuvaret OK? (user)
- [ ] Git remote: private GitHub repo or local only? (user)
- [ ] GRDB vs SwiftData. (agent, decision doc; leaning GRDB for encryption via SQLCipher and sync-ready schema)
- [ ] Embeddings: NLEmbedding vs bundled small model. (agent, after spike)

## Spikes
| Unknown | Result | Numbers | Date |
|---|---|---|---|
| FM tool loop + EventKit on device, real context limit, tools that fit | | | |
| FM tool calls can be wrapped so policy runs first | | | |
| MLX Swift on iPhone: memory ceiling, tok/s, parse reliability (2-3 models) | | | |
| Anthropic + OpenAI-compatible SSE streaming with tool use | | | |
| Notification + open-to-generate briefing; BG task reliability; FM in background | | | |
| Apple Intelligence availability detection + unavailable path | | | |

## Baseline
No code yet. Filled after task 2.
| Metric | Value | Command |
|---|---|---|
| Tests passing | | scripts/smoke.sh |
| Build time | | |
| ERROR lines, standard run | | |
| FM time to first token | | |
