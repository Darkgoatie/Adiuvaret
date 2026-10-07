# Adiuvaret: Build Brief for Coding Agent

You are the lead engineer building **Adiuvaret**, an iPhone app. This document is your complete product and engineering brief. Read all of it before writing code. Where the brief says "verify", check current Apple documentation and library sources instead of relying on memory, because these APIs change quickly.

---

## 0. How to work

1. **Work in phases** (Section 14). Finish and test one phase before starting the next. At the end of each phase, summarize what was built, what was deferred, and what you verified.
2. **Do not invent APIs.** If you are unsure whether a framework call exists or how it behaves, say so, look it up, and write a small spike to confirm it before building on it.
3. **Ask before making irreversible or product-level decisions** that this brief does not settle. For small technical choices, decide, document the decision in `docs/decisions/` (one short file per decision), and move on.
4. **Prefer boring, testable code.** Protocol-driven design, dependency injection, no singletons for core services, no force unwraps in production paths.
5. **Everything consequential goes through the policy engine** (Section 7). This is the most important architectural rule in the project.
6. **Write tests as you go**, especially for the policy engine, tool-call parsers, context builder, and memory pipeline.
7. **Keep a running `docs/ARCHITECTURE.md` and `docs/VERIFIED_FACTS.md`.** The second file records every platform fact you confirmed (API availability, limits, entitlements) with the date and source.

---

## 1. Product summary

**Adiuvaret** is a private, on-device-first AI personal assistant for iPhone. It uses **Apple Intelligence (the Foundation Models framework)** as the default brain, with optional upgrade tiers: **downloadable MLX models** that run on the phone, and **cloud models** (Claude, GPT, and others) via the user's own API key. The assistant can **take actions** (calendar, reminders, contacts, drafts, in-app notes), **remember important facts**, and deliver **scheduled briefings**.

**Thesis:** "A private assistant that lives on your iPhone, handles your day, and remembers what matters. It runs on-device by default, and you can upgrade its brain when you want."

You are building an agent **harness**, not a model. Adiuvaret owns the agent loop, memory, tools, permissions, and routing. Models are swappable brains behind one interface.

### Locked decisions

| Decision | Choice |
|---|---|
| Platform | iPhone only for v1 (architect so iPad and Mac can be added later) |
| Audience | General consumers (not developers) |
| Core use case | Personal assistant: calendar, reminders, notes, messages |
| Model tiers in v1 | Apple Intelligence (default), MLX downloads, cloud via BYO key |
| Proactivity | Reactive, plus scheduled briefings and reminders |
| Business model | Free core, paid Pro for advanced models |
| Language | English first; keep all strings localizable from day one |
| Input | Text-first (voice is out of scope for v1) |
| Sync | Single device for v1 (keep the data layer sync-ready) |

### Explicitly out of scope for v1

Local server tier (Ollama/LM Studio/Hermes over LAN), Mac companion app, Bonjour/Tailscale pairing, MCP client, HTTP connector builder, shell or filesystem automation, iCloud sync, Health and Photos integration, voice input and output, managed "credits" proxy for cloud models, iPad and Mac targets. Do not build these, but do not make them hard to add.

---

## 2. Core principles

1. **Local-first and private by default.** Nothing leaves the device unless the user has enabled a cloud provider and approved the data being sent.
2. **Model-agnostic.** One provider protocol, many backends.
3. **Human-in-the-loop for anything consequential.** Read actions run freely. Write actions follow permission tiers. Irreversible or external actions always need approval.
4. **Context-window-aware.** The on-device Apple model has a small context window. The harness must compensate with context engineering instead of pretending the limit does not exist. Verify the current limit in Phase 0 and record it.
5. **Honest about iOS limits.** Do not build features that rely on APIs iOS does not provide (see Section 8).
6. **Consumer-grade UX.** No jargon on primary screens. Advanced settings live in an "Advanced" area.

---

## 3. Technology stack

- **Language and UI:** Swift 6 (strict concurrency), SwiftUI. Minimum iOS version: the lowest version that supports the Foundation Models framework (verify). Structure code so a macOS target can be added later.
- **Apple frameworks:** FoundationModels, App Intents, EventKit, Contacts, CoreLocation, WeatherKit, MapKit, NaturalLanguage, UserNotifications, BackgroundTasks, StoreKit 2, Network, Security (Keychain).
- **MLX:** MLX Swift packages (MLXLLM, MLXLMCommon and related; verify current package names and APIs).
- **Storage:** SQLite via GRDB (or SwiftData if you can justify it; decide in a decision doc). Memory embeddings stored locally with a simple on-device vector index.
- **Networking:** URLSession with async streaming (SSE) for cloud providers.
- **Testing:** XCTest or Swift Testing, plus a replayable trace harness (Section 12).
- **Modularity:** Use Swift Package Manager local packages for separable modules (see Section 4).

---

## 4. Repository and module structure

```
Adiuvaret/
  App/                      # SwiftUI app target, composition root
  Packages/
    AdiuvaretCore/          # domain models, protocols, shared types
    AgentRuntime/           # orchestrator, context builder, task store
    PolicyEngine/           # permissions, sensitivity labels, egress rules
    ModelProviders/         # AppleFM, MLX, Anthropic, OpenAICompatible adapters
    ToolKit/                # tool definitions and native executors
    MemoryKit/              # extraction, storage, retrieval, consolidation
    BriefingKit/            # schedules, notification payloads, generation
    ModelLibrary/           # curated MLX catalog, download manager, self-test
    Persistence/            # database, migrations, Keychain wrapper
    Evals/                  # eval suite, trace recorder, replay harness
    DesignSystem/           # shared SwiftUI components
  docs/
    ARCHITECTURE.md
    VERIFIED_FACTS.md
    decisions/
  Tests/
```

Dependencies flow downward: App depends on everything, `AdiuvaretCore` depends on nothing. `PolicyEngine` must not depend on any model provider.

---

## 5. System architecture

```
SwiftUI app (iPhone)
  Chat · Approvals · Memory · Briefings · Models · Privacy · Activity log
        │
  Agent Runtime
  Orchestrator · Context builder · Policy engine · Task store · Trace log
        │
  ┌────────────────┬──────────────────┬─────────────────┐
  │ Model Router   │ Tool Layer       │ Memory Layer    │
  │ Apple FM       │ EventKit         │ SQLite          │
  │ MLX            │ Contacts         │ + embeddings    │
  │ Cloud          │ App Intents      │ Encrypted       │
  │                │ Shortcuts        │                 │
  └────────────────┴──────────────────┴─────────────────┘
```

---

## 6. Model layer

### 6.1 Tiers

| Tier | Backend | Where it runs | Privacy | Use |
|---|---|---|---|---|
| 0 (default) | Apple Foundation Models | On-device | Fully local | Routing, summarizing, extraction, short tool calls, memory writing |
| 1 | MLX models from Hugging Face | On-device | Fully local | Offline use, longer context, user-chosen models, fallback if Apple Intelligence is unavailable |
| 3 | Cloud APIs (Claude, GPT, OpenRouter, etc.) | Provider servers | Data leaves the device | Hardest tasks, best tool-use reliability |

(Tier 2, the local server, is reserved in the enum but not implemented in v1.)

The UI must always show which tier produced a message or tool call, with a plain-language privacy label: **"Stays on your iPhone"** or **"Sent to <Provider>"**.

### 6.2 Provider protocol

Every backend implements one protocol and exposes a capability profile so the router and context builder can adapt:

```
ModelProvider
  id, displayName, tier
  capabilities:
    contextWindow
    supportsToolCalls
    toolCallFormat   (native | hermesTags | openAIJSON | anthropicBlocks)
    supportsVision
    supportsStructuredOutput
    measuredTokensPerSecond
    costPerMTok          (cloud only)
    toolReliabilityScore (from self-test)
  generate(messages, tools, schema) -> AsyncStream<ModelEvent>
    ModelEvent = textDelta | toolCall | structuredResult | usage | error
```

### 6.3 Adapters

- **Apple FM adapter.** Maps tool definitions to the framework's `Tool` conformances and uses `@Generable` for structured output. **Critical:** Apple's framework runs its own tool-calling loop inside a session. Wrap every tool executor so each call routes through the policy engine regardless of which backend triggered it. Never let the framework call a tool that bypasses policy.
- **MLX adapter.** Wraps MLX Swift. Apply each model's chat template and parse tool calls out of generated text, using per-family parsers (Hermes-style `<tool_call>` tags, Qwen, Llama, etc.). Parsers are pluggable and unit-tested against recorded outputs.
- **OpenAI-compatible adapter.** Covers OpenAI, OpenRouter, and any compatible endpoint with a custom base URL.
- **Anthropic adapter.** Dedicated adapter for the Messages API and its tool-use block format, with streaming.
- A Gemini adapter is optional later (reachable via OpenRouter in the meantime).

### 6.4 Router and escalation

Every request starts on Apple Intelligence when it is available. The escalation ladder is **Apple, then MLX, then cloud**.

1. Tier 0: the Apple model classifies the task (simple, tool-heavy, long context, hard reasoning) via a guided-generation schema and attempts it if it fits.
2. Tier 1: if the user has a downloaded MLX model that passed its self-test and the task needs more context or capability, use it.
3. Tier 3: cloud only if the user enabled a provider, and only after the consent rules in Section 9.

**Escalation triggers:** context overflow, schema or tool-call failures after N retries, loop detection, an explicit "Think harder" button, or a per-chat model override.

**Escalation modes (global setting, overridable per chat):**
- **Ask first** (default): "This needs a stronger model. Send to Claude? Here is what will be shared."
- **Auto within allowed providers:** user pre-approves specific providers.
- **Local only:** cloud hard-disabled.

**Fallbacks:** if a higher tier is unreachable (offline, rate limit, bad key), fall back down the ladder with a visible banner. **Never silently fall up into the cloud.**

### 6.5 Apple Intelligence unavailability

Apple Intelligence will not exist on all devices, regions, or languages, and must be enabled by the user. Detect availability at launch. If unavailable, the first-run flow offers a fallback: a small curated MLX model (free tier allowed for this one fallback case, decision doc required) or a cloud model. Verify current availability rules and record them.

---

## 7. Agent runtime and policy engine

### 7.1 Agent loop

Build context, call model, if a tool call is returned then check policy, execute or request approval, append the observation, repeat until done or a budget is hit.

- **Budgets:** max steps, wall-clock timeout, token cap, and (for cloud) cost cap per task.
- **Loop detection:** detect repeated identical tool calls and abort or escalate.
- **Error recovery:** retry with the error in context, then escalate a tier (subject to consent), then ask the user.
- **Task store:** persisted tasks that can pause for approval and resume.
- **Trace log:** every step (prompt, tool call, result, model, tier, tokens) stored locally and viewable in the activity log. Cloud payloads are logged so the user can see exactly what was sent.

### 7.2 Context builder (high priority)

Per-model token budgets are required, because context limits range from a few thousand tokens (Apple, small MLX) to hundreds of thousands (cloud).

- **Small-window models:** compact system prompt, **3 to 6 relevant tools only** (selected by a first-pass router using embeddings or classification), top-k memories under a strict token budget, and a rolling conversation summary.
- **Large-window models:** richer memory injection, the full tool catalog, more history.
- **Handoff packets:** when escalating mid-task, the smaller model produces a compact task state (goal, steps done, tool results, open questions) so the stronger model continues without the full transcript. Handoff packets pass through the privacy filter (Section 9).
- **Prompt template registry:** versioned prompt variants per model family. Do not use one prompt for all models.

### 7.3 Policy engine

The **policy engine, not the model, makes all permission decisions.** It is a standalone module with no dependency on model providers and has exhaustive unit tests.

**Tool definition fields:** name, description, JSON schema, permission tier, side-effect level, sensitivity classification of its outputs, and an executor.

**Permission tiers:**
1. **Read-only:** auto-run.
2. **Reversible write:** auto-run only if the user opted in (per tool or per chat), otherwise confirm. Always provide Undo where possible.
3. **Irreversible or external** (send, delete, post, anything leaving the device): always confirm, with a clear preview of exactly what will happen.

**Also required:**
- Scoped grants ("allow reminder creation for this chat").
- A global kill switch that stops all tool execution.
- Rate limits on tool calls per task.
- **Prompt-injection defense:** tool outputs and user data (calendar event text, contact notes, shared content, web content) are tagged **untrusted**. Untrusted content can never by itself cause a tier 2 or 3 action to run without confirmation.
- **Scheduled runs never take write actions** without the user present.
- Secrets (API keys) live in the Keychain and are never placed in model context.

---

## 8. Tool layer: the personal assistant surface

Tools are defined once and serialized for each backend (native `Tool` conformance for Apple FM, JSON schema for MLX and cloud).

**Be honest about iOS limits.** There is no public API to read Messages or Apple Notes. Do not attempt private APIs.

| Capability | v1 implementation | Tier |
|---|---|---|
| Calendar | Read, create, edit events via EventKit | Read: auto. Write: confirm |
| Reminders | Full read and write via EventKit | Read: auto. Write: auto if opted in, else confirm |
| Contacts | Lookup via Contacts framework | Read: auto |
| Notes | **In-app notes and tasks store** owned by Adiuvaret. Apple Notes only via user-chosen Shortcuts | Own store: auto. Shortcuts: confirm |
| Messages | **Draft only**: prefill the compose sheet; the user taps Send. Cannot read messages | Always confirm |
| Mail | **Draft only**: compose sheet. Cannot read mail | Always confirm |
| Location, weather, maps | CoreLocation, WeatherKit, MapKit | Read: auto |
| Shortcuts | Run user-chosen shortcuts (extensibility escape hatch) | Confirm |
| Clipboard | Read, user-initiated | Read: auto |
| Memory tools | Save, update, search, delete memory | Save: auto (visible), delete: confirm |

Deferred: Health, Photos, Files access, web browsing and search (v2 candidates).

**Entry points (App Intents are critical for a consumer assistant):** Siri and Shortcuts via App Intents (ask Adiuvaret, add to notes, run briefing), Action Button, Lock Screen and Home Screen widgets, and the share sheet.

Permissions for Calendar, Reminders, Contacts, and Location are requested **in context**, the first time a feature needs them, with a short explanation screen first.

---

## 9. Privacy and cloud-egress rules

This is a core product area. Build it carefully.

- **Sensitivity labels:** every memory, note, file snippet, and tool result carries a label (public, personal, sensitive). Sensitive categories (health, finance, contact details of others, credentials) are **excluded from cloud context by default**. The user can allow categories explicitly.
- **Outbound preview:** before the first cloud call in a chat, and optionally every call, show exactly what will be sent (messages, injected memories, tool outputs). A "View payload" option appears in the activity log.
- **Redaction pass:** an on-device step masks emails, phone numbers, addresses, and account numbers before sending, with a reversible mapping kept locally.
- **Memory writes from cloud turns:** the **local** model extracts memories, never the cloud model.
- **Local only switch:** one global toggle that hard-disables cloud.
- **Provider data-policy notes:** a short summary per provider with a link to the source, and a note that provider terms change.
- **Audit log:** record which provider saw which data. Exportable.
- **Keys:** Keychain only. Never in logs, prompts, or backups.
- **No telemetry by default.** Crash reporting, if added, is opt-in and content-free.

---

## 10. Memory system

**Types:** working (current conversation plus rolling summary), episodic (compressed summaries of past sessions), semantic facts (durable structured facts), procedural (preferences and saved workflows).

**Categories for v1:** people, preferences, routines, ongoing projects.

**Pipeline:**
1. After each exchange, the **on-device model** extracts candidate memories via guided generation (a `@Generable` struct: fact, category, confidence, sensitivity).
2. Dedupe and merge against existing memories.
3. Store in the database with an embedding (use the NaturalLanguage framework or a small bundled model; decide in a decision doc).
4. At query time, retrieve top-k relevant memories and inject them under the model's token budget.
5. Periodic consolidation compresses old episodic memories.

**User control (non-negotiable):**
- A friendly **"What I know about you"** screen: browse, search, edit, delete.
- "Why do you remember this?" shows provenance linking to the source conversation.
- Sensitive categories require explicit opt-in.
- Encrypted at rest.
- Export memories on request.
- Free tier cap on stored memories (default 100, configurable constant). Pro raises or removes the cap. Never block export or deletion.

---

## 11. Briefings and reminders (iOS constraints apply)

iOS **does not let you run an agent on a schedule.** Background execution is OS-controlled, and running an on-device model in the background is constrained by memory, thermal, and power limits (verify what Foundation Models allows in the background and record it).

**Design: "prepare on open, notify on schedule."**
1. At the scheduled time, a **local notification** fires with a lightweight, template-based payload (for example today's event count and top reminders, pulled directly from EventKit with no LLM).
2. Tapping the notification opens the app, which generates the **full AI briefing** immediately using the on-device model.
3. Optionally attempt **best-effort background pre-generation** via `BGAppRefreshTask` or `BGProcessingTask`. **Never depend on it.**
4. Expose a briefing **App Intent** so users can create a Shortcuts personal automation for a more reliable automatic trigger.

**v1 briefing types:** morning briefing, end-of-day wrap-up, and user-defined recurring "check X" prompts. A briefing is a saved prompt plus a schedule, run through the same agent loop with **read-only tools by default**. Free tier gets a limited number of schedules (default 2, configurable constant). Pro gets more.

---

## 12. Evaluation and quality

- **Eval suite:** start with 30 tasks in Phase 1 and grow to 50 or more. Categories: tool selection, argument accuracy, multi-step tasks, refusal of unsafe actions, prompt-injection resistance, memory extraction quality.
- **Trace recorder and replay harness:** recorded agent runs can be re-executed against a different model or prompt version to compare results and catch regressions.
- **Model scorecards:** per model, track tool accuracy, speed, and (for cloud) cost. Use scores to drive "recommended model" suggestions.
- **Targets:** tool-call success rate above 90% on the fixed suite for the default configuration. Time to first token under 1 second on-device (record measured values; adjust targets based on Phase 0 data).
- Run evals in CI on any change to prompts, parsers, the context builder, or the policy engine.

---

## 13. Free vs Pro

**Free**
- Apple Intelligence chat and agent
- All native personal-assistant tools
- Memory (capped) with the full memory browser
- Limited scheduled briefings
- Approval flow, undo, and activity log
- Fallback model if Apple Intelligence is unavailable

**Pro** (StoreKit 2 subscription with free trial; price is a configuration value, not hardcoded)
- Cloud providers (BYO key) with budgets and live cost display
- MLX model library and downloads
- Higher or unlimited memory cap and more scheduled briefings
- Escalation ladder, "Think harder," per-chat model overrides
- Privacy dashboard extras (outbound preview controls, redaction, audit export)

The paywall appears **at the moment of need** (when the user tries to add a cloud provider or download an MLX model) with a clear value statement. Entitlement checks must live behind one `Entitlements` service so gating is easy to change.

### 13.1 Consumer packaging of advanced tiers

- **MLX:** do not ship a raw Hugging Face browser as the main experience. Offer **3 to 5 curated models** with plain labels ("Fast," "Balanced," "Smarter, needs a newer iPhone"). Device-fit filtering is automatic based on device RAM (label: Runs well, Tight, Won't fit). Keep "paste a repo ID" in Advanced.
  - Resumable background downloads, integrity checks, Wi-Fi-only default, storage dashboard with easy deletion, license shown before download, Hugging Face token support (Keychain) for gated models.
  - Load one model at a time, unload on memory warnings, warm up lazily, warn on thermal pressure.
  - **Post-download self-test:** a small built-in eval (tool-call and JSON-format prompts) producing a "tool reliability" score. Models that fail remain usable for plain chat only.
  - Model weights are data, never code. Do not download or execute code alongside weights.
  - Verify iPhone memory limits and whether the increased-memory-limit entitlement is appropriate.
- **Cloud:** guided setup per provider (short walkthrough, paste key, test connection). Support **OpenRouter** as the easiest single-key option. Fetch model lists dynamically from provider endpoints where possible. Per-provider monthly budget, per-task cost cap, live token and cost display, warning before expensive runs, and prompt caching where supported.

---

## 14. UX specification

**Screens:**
1. **Chat:** streaming responses, inline action cards ("Added 'Call mom' to Reminders for 6 PM" with Undo), expandable tool details, model and privacy badge per message, "Think harder" button (Pro).
2. **Approval sheet:** precise preview of the action, with Approve, Edit, and Deny.
3. **Briefings:** schedules and previews.
4. **Memory:** "What I know about you."
5. **Models:** Apple status, downloaded MLX models, cloud providers, scorecards, test buttons (Pro features gated).
6. **Privacy dashboard:** local-only switch, escalation mode, categories allowed for cloud, spend this month, "what did the cloud see" log.
7. **Activity log:** full trace.
8. **Settings and Advanced.**

**First run:** zero setup with Apple Intelligence (or the fallback path), a permissions primer that requests access in context, and one example task completed within about a minute. Advanced models are offered later as optional "upgrade" steps.

**Quality bar:** full VoiceOver and Dynamic Type support, Dark Mode, reduced motion respect, localizable strings, and haptics on confirmations.

---

## 15. Roadmap and acceptance criteria

### Phase 0: Feasibility spike (about 3 weeks)

Build throwaway spikes and report findings in `docs/VERIFIED_FACTS.md`:
- Foundation Models tool loop with EventKit tools on a real device. Measure the real context limit, latency, and how many tools fit.
- MLX Swift on iPhone: memory ceilings, tokens per second, tool-call parse reliability for 2 to 3 small models.
- Anthropic and OpenAI-compatible streaming and tool-use prototypes.
- Briefing delivery prototype: notification plus open-to-generate, and measured background-run reliability.
- Confirm Apple Intelligence availability checks and the unavailable-device path.

**Exit criteria:** a written go/no-go summary with measured numbers, and a list of any plan changes the data requires.

### Phase 1: Free MVP (about 10 to 12 weeks)

Chat UI, Apple-only router, provider protocol (with Apple adapter), policy engine with tests, Calendar, Reminders, Contacts, in-app notes, location and weather tools, approval and undo, basic memory with browser, activity log and trace recorder, App Intents and Siri, onboarding and in-context permissions, initial 30-task eval suite.

**Acceptance:** all tier-2 and tier-3 actions are blocked without approval (tested), prompt-injection test cases pass, no tool executes outside the policy engine, memory is viewable, editable, and deletable.

### Phase 2: Briefings and polish (about 6 to 8 weeks)

Scheduled briefings (notification-first design), widgets, Shortcuts integration, memory consolidation, accessibility pass, TestFlight beta.

**Acceptance:** briefings work reliably with the app closed to the "notification with template payload" level, and generate the full AI briefing on open.

### Phase 3: Pro tier (about 10 to 12 weeks)

Cloud adapters (Anthropic, OpenAI-compatible, OpenRouter), consent flow, sensitivity labels, outbound preview, redaction, privacy dashboard, budgets and cost display, curated MLX manager with self-tests, full escalation ladder, StoreKit 2 paywall and entitlements.

**Acceptance:** cloud never receives data without the configured consent path (tested), sensitive-labeled items never appear in cloud payloads by default (tested), a user can run fully local with cloud hard-disabled, and downgrade fallbacks show banners and never silently escalate.

### Phase 4: Launch (about 4 to 6 weeks)

Localization infrastructure and review, App Review preparation (privacy nutrition labels, model-download disclosure, permission rationale text), pricing experiments, performance and battery tuning, public launch.

---

## 16. Risks to design around

| Risk | Required mitigation |
|---|---|
| Apple Intelligence unavailable for some users | Availability detection plus fallback onboarding |
| Tiny on-device context, flaky tool use | Tool subsetting, guided generation, retries, escalation, curated task templates |
| iOS background limits | Notification-first briefings, honest UX copy |
| iPhone memory kills when loading MLX models | Device-fit labels, one model at a time, memory-warning unload, conservative defaults |
| MLX tool-calling varies by model | Per-family parsers, self-test scoring, chat-only mode for failing models |
| Prompt injection via calendar, contacts, shared content | Untrusted tagging, policy engine outside the model, confirm-by-default |
| Cloud data leaks | Sensitivity labels, local-only mode, outbound preview, ask-first default |
| Cost surprises from agent loops on cloud | Per-task caps, loop detection, budgets, live cost |
| Cloud API changes | Dynamic model lists, versioned adapters, replay tests |
| App Store review | Approval UX, weights as data only, no dynamic code execution, accurate privacy labels |
| Weak free-to-Pro conversion | Paywall at moment of need, memory and briefing limits as secondary levers |

---

## 17. Engineering conventions

- Swift 6 strict concurrency enabled. Use actors for stateful services (model manager, memory store, task store).
- Every external service (model providers, EventKit, Keychain, notifications) sits behind a protocol with a test double.
- Structured logging with redaction. Never log prompts, memory contents, or keys outside the user-visible activity log.
- Database migrations are versioned and tested. Keep the schema sync-ready (stable IDs, updated-at timestamps, soft deletes where useful).
- Feature flags for Pro features and experimental tiers.
- Constants for free-tier limits, price, and budgets live in one config file.
- All user-facing strings go through localization. No hardcoded English in views.
- Keep commits small and phase-scoped, with clear messages.

---

## 18. Unresolved items (use these defaults, flag them in your phase summary)

1. **Pricing:** price is unspecified. Build with a StoreKit configuration file and a placeholder monthly and annual product.
2. **Languages:** English only for launch. Keep localization-ready.
3. **Voice:** deferred.
4. **iCloud sync:** deferred, but keep the data layer sync-ready.
5. **Team size and timeline:** assume a small team. Timelines above are estimates, so adjust after Phase 0 data.

---

## 19. First actions

1. Create the repository skeleton from Section 4 and the docs folder.
2. Start Phase 0. Begin with the Foundation Models plus EventKit spike on a real device, because it determines how much of the plan holds.
3. Produce `docs/VERIFIED_FACTS.md` with the findings, then post the Phase 0 go/no-go summary and wait for confirmation before starting Phase 1.
