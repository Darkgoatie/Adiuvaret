# Tasks

Status: pending | in progress | done | needs-fix | reverted
Phase 0 only. Phase 1+ tasks are written after the go/no-go summary is approved.

| # | Task | Module | Files | Depends | Acceptance check | Budget | Effort | Status | Attempts | Commits | Cost |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Repo skeleton, docs, spec | - | docs/, Packages/, App/ | - | User has seen SPEC.md and TASKS.md | | S | in progress | 1 | | |
| 2 | Xcode project + empty packages build on Mac; smoke script | App, all | App/, Packages/, scripts/smoke.sh | 1 | `scripts/smoke.sh` builds for iOS sim and runs 1 test, 0 errors, time recorded in SPEC baseline | | M | pending | 0 | | |
| 3 | Verify platform facts (min iOS, FM API surface, availability API, context size, BG rules, MLX package names, memory entitlement) from Apple docs/sources | docs | docs/VERIFIED_FACTS.md | 1 | Each fact has date + source URL | | M | pending | 0 | | |
| 4 | Spike: FM availability check + unavailable path | spikes | spikes/fm-availability/ | 2,3 | On device and on unsupported sim, screen shows correct availability reason | | S | pending | 0 | | |
| 5 | Spike: FM session with 2 EventKit tools (read events, create reminder) wrapped by a stub policy gate | spikes | spikes/fm-eventkit/ | 4 | On device: "what's on today" lists real events; "remind me X" hits the gate and only writes after Approve; logged latency + TTFT | | M | pending | 0 | | |
| 6 | Spike: measure FM context limit and how many tools fit before failure | spikes | spikes/fm-eventkit/ | 5 | Table of tool count vs success and token count at overflow error in VERIFIED_FACTS | | M | pending | 0 | | |
| 7 | Spike: MLX Swift with 2-3 small models on device | spikes | spikes/mlx/ | 2,3 | Per model: peak memory, tok/s, tool-call parse success over 10 prompts | | L | pending | 0 | | |
| 8 | Spike: Anthropic + OpenAI-compatible SSE streaming with one tool round-trip (key from env/Keychain, never committed) | spikes | spikes/cloud/ | 2 | Streamed text and parsed tool call for both APIs in sim log | | M | pending | 0 | | |
| 9 | Spike: briefing notification with EventKit template payload + open-to-generate; BGAppRefreshTask attempt log | spikes | spikes/briefing/ | 5 | Notification fires with app killed; tap generates FM briefing; BG run count over 3 days recorded | | M | pending | 0 | | |
| 10 | Phase 0 go/no-go summary | docs | docs/PHASE0_SUMMARY.md | 4-9 | Summary with measured numbers and plan changes, approved by user | | S | pending | 0 | | |

STOP
