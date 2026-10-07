# Tasks

Status: pending | in progress | done | needs-fix | reverted
Phase 0 (3-10), then Stage 1 (12-29, local models only). Tasks 7 and 8 deferred to Phase 3. Every UI task loads the impeccable skill first. Stage 1 order: 3, 5, 6, 12-15 (can run before the device spikes finish), then 16 onward.

| # | Task | Module | Files | Depends | Acceptance check | Budget | Effort | Status | Attempts | Commits | Cost |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Repo skeleton, docs, spec | - | docs/, Packages/, App/ | - | User has seen SPEC.md and TASKS.md | | S | done | 1 | 379d62c | |
| 2 | Xcode project + empty packages build on Mac; smoke script | App, all | App/, Packages/, scripts/smoke.sh | 1 | `scripts/smoke.sh` builds for iOS sim and runs 1 test, 0 errors, time recorded in SPEC baseline | | M | done | 1 | see git log | |
| 3 | Verify platform facts (min iOS, FM API surface, availability API, context size, BG rules, MLX package names, memory entitlement) from Apple docs/sources | docs | docs/VERIFIED_FACTS.md | 1 | Each fact has date + source URL | | M | done | 1 | see git log | |
| 4 | Spike: FM availability check + unavailable path | spikes | spikes/fm-availability/ | 2,3 | On device and on unsupported sim, screen shows correct availability reason | | S | done | 1 | see git log | |
| 5 | Spike: FM session with 2 EventKit tools (read events, create reminder) wrapped by a stub policy gate | spikes | spikes/fm-eventkit/ | 4 | On device: "what's on today" lists real events; "remind me X" hits the gate and only writes after Approve; logged latency + TTFT | | M | done | 1 | build 2 device run | |
| 6 | Spike: measure FM context limit and how many tools fit before failure | spikes | spikes/fm-eventkit/ | 5 | Confirm contextSize==4096 on device; table of tool count (1-8) vs success and tokenCount(for: tools) in VERIFIED_FACTS | | M | done | 1 | build 2 report | |
| 7 | Spike: MLX Swift with 2-3 small models on device | spikes | spikes/mlx/ | 2,3 | Per model: peak memory, tok/s, tool-call parse success over 10 prompts | | L | deferred (Phase 3, decision 003) | 0 | | |
| 8 | Spike: Anthropic + OpenAI-compatible SSE streaming with one tool round-trip (key from env/Keychain, never committed) | spikes | spikes/cloud/ | 2 | Streamed text and parsed tool call for both APIs in sim log | | M | done | 1 | see git log | |
| 9 | Spike: briefing notification with EventKit template payload + open-to-generate; BGAppRefreshTask attempt log | spikes | spikes/briefing/ | 5 | Notification fires with app killed; tap generates FM briefing; BG run count over 3 days recorded | | M | pending | 0 | | |
| 10 | Phase 0 go/no-go summary | docs | docs/PHASE0_SUMMARY.md | 4-9 | Summary with measured numbers and plan changes, approved by user | | S | pending | 0 | | |
| 11 | Policy engine core: tiers, grants, kill switch, rate limit, scheduled-run and untrusted rules, PolicyGate as only executor path | PolicyEngine | Packages/PolicyEngine/, Packages/AdiuvaretCore/ | 1 | 13 Swift Testing cases pass on VM | | M | done | 1 | see git log | |
| 12 | Fonts + design tokens: bundle Google Sans, Google Sans Flex, Archivo Black with OFL files; run impeccable context, write PRODUCT.md/DESIGN.md; color/spacing/radius tokens, accent proposal | DesignSystem | Packages/DesignSystem/, App/ | 4 | Preview shows all three fonts, tokens in light/dark; sim build 0 errors | | M | done | 1 | see git log | |
| 13 | Core components (ModelPrivacyChip, MessageBubble, ToolProgressRow, ActionCard, ApprovalCard/Sheet, DraftCard, MemoryChip, SystemBanner, StatusBadge, EmptyState, SettingsRow) | DesignSystem | Packages/DesignSystem/ | 12 | Previews for every variant, light/dark, default and AX5 text size, screenshots reviewed | | L | done | 1 | see git log (components, Localizable.xcstrings) | |
| 14 | Chat shell in demo mode: header, thread with every message type, composer, quick actions, empty state; view model behind a protocol | App | App/Chat/ | 13 | Demo chat runs in sim; send, stop, approve flow works with mock data | | L | done | 2 | 7b385f5, 8dee45e | |
| 15 | Drawer + Route enum: slide-over, conversation list, footer, destination stubs | App | App/Navigation/ | 14 | Edge swipe and menu button open drawer; VoiceOver path works in sim | | M | done | 2 | adacee0, 8dee45e | |
| 16 | Thin end-to-end slice: AppleFM ModelProvider streaming into the chat shell (device) | ModelProviders | Packages/ModelProviders/, AgentRuntime/ | 15,6 | On iPhone: typed question streams a real answer, TTFT logged, TestFlight build | | L | in progress: device result pending (streaming); TTFT not logged | 1 | a7bf1d1, ad3ce39 | |
| 17 | ToolKit v1: calendar read, reminders create via PolicyGate and ApprovalCard; Undo | ToolKit, AgentRuntime | Packages/ToolKit/, AgentRuntime/ | 16,5 | On iPhone: 'what's on today' lists real events; reminder only written after Approve; Undo removes it | | L | in progress: device result pending (calendar ranges, Approve/Undo) | 3 | a7bf1d1, 38e5d24, 36dadc8 | |
| 18 | Persistence: SwiftData (decided), chats and messages store, migrations, tests | Persistence | Packages/Persistence/ | 15 | Chats survive relaunch; migration test passes | | M | in progress: save/restore built (a547a0c); model context restore, rename, migration test open | 1 | 7cb7299, a547a0c | |
| 19 | Memory: extraction via guided generation, dedupe, retrieval, Memory screen | MemoryKit | Packages/MemoryKit/, App/Memory/ | 17,18 | Stated fact appears in Memory screen, is used in a later chat, can be edited/deleted | | L | pending | 0 | | |
| 20 | Notes and Tasks store + screens, Send to Reminders | ToolKit, App | Packages/ToolKit/, App/Notes/ | 18 | Assistant creates a note; shows in list with provenance; task sent to Reminders | | M | pending | 0 | | |
| 21 | Activity log + trace recorder | AgentRuntime, App | Packages/AgentRuntime/, App/Activity/ | 17 | Every tool call appears with result and Undo where possible | | M | pending | 0 | | |
| 22 | Integrations overview/detail + permission primers (Calendar, Reminders, Contacts, Location, Notifications) | App | App/Integrations/ | 17 | Granted/denied/not-asked states shown correctly on device | | M | pending | 0 | | |
| 23 | Settings + kill switch + approvals preferences | App | App/Settings/ | 17 | Kill switch on: tool call blocked and chat shows it | | M | pending | 0 | | |
| 24 | Onboarding with Apple Intelligence check and example task | App | App/Onboarding/ | 22 | Fresh install reaches a completed example task in about a minute | | M | pending | 0 | | |
| 25 | App Intents (ask, add note) and share sheet | App | App/Intents/ | 20 | Siri/Shortcuts phrase opens a chat on device | | M | pending | 0 | | |
| 26 | Eval suite, 30 tasks incl. injection and refusal cases, replay harness | Evals | Packages/Evals/ | 17,21 | Suite runs on device, tool success rate recorded vs 90% target | | L | pending | 0 | | |
| 27 | Briefings: list, editor, notification with template payload, open-to-generate | BriefingKit | Packages/BriefingKit/, App/Briefings/ | 9,17 | Notification fires with app killed; tap generates briefing; no write tools offered | | L | pending | 0 | | |
| 28 | Widgets (Home/Lock) and Action Button | App | Widgets/ | 27 | Widgets show next event/briefing on device | | M | pending | 0 | | |
| 29 | Polish: accessibility audit, localization pass, haptics, long-chat performance | App | all | 26,28 | VoiceOver completes chat+approval; no hardcoded strings; no dropped frames streaming 500 messages | | L | pending | 0 | | |

## Added after Stage 1 start (user requests, 2026-10-07)

| # | Task | Module | Files | Depends | Acceptance check | Budget | Effort | Status | Attempts | Commits | Cost |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 30 | Release pipeline on GitHub (Xcode 27 runner, cloud signing, build number from ASC) | infra | .github/, scripts/next_build_number.py | 2 | Workflow run uploads a VALID build that reaches IN_BETA_TESTING | | S | done | 2 | 1819e5e, f917107, 71280c5, 687496d | |
| 31 | Markdown rendering for model replies | DesignSystem | Packages/DesignSystem/ | 14 | Bold, bullets, numbers render without raw markers; 4 tests pass | | S | done (device look unconfirmed) | 1 | 86fdab2 | |
| 32 | Drawer layout: fixed top, scrolling history, fixed Advanced/Settings; real chat list | App | App/Navigation/, App/Chat/ | 15 | Tapping a history chat reopens it; no separators | | M | done (device unconfirmed) | 2 | 3b53b47, 541e750 | |
| 33 | Finish persistence: rebuild model context from saved chat, rename chat, migration test | Persistence, App | Packages/Persistence/, App/Chat/, App/Runtime/ | 18 | Follow-up in a restored chat refers to earlier messages; test opens a v1 store with v2 schema | | M | pending | 0 | | |
| 34 | Calendar skills: find, search, free time, create (approval+Undo), move/delete (confirmation), conflicts | ToolKit | App/Runtime/, Packages/ToolKit/ | 17 | Each skill returns correct results on a seeded calendar in tests; create/move/delete need approval | | L | pending | 0 | | |
| 35 | Reasoning level behind compile guard (iOS 27 SDK) | ModelProviders | App/Runtime/ | 16 | Builds on Xcode 27.0; setting hidden below iOS 27 | | S | pending, needs user iOS version | 0 | | |
| 36 | Learnable skills scope (decision 005) | docs | docs/decisions/005 | - | User answers Stage 1 or later, uni panel meaning, mail reading vs draft-only | | S | pending, needs user | 0 | | |

