# Decisions

Append only. Newest at the bottom. Detail for each lives in docs/decisions/NNN-*.md.

| # | Date | Decision | Reason | Replaces |
|---|------|----------|--------|----------|
| 1 | 2026-10-07 | Track work in docs/spec (SPEC/TASKS/HANDOFF) alongside the brief's docs/decisions | Resumable across sessions and sub-agents | - |
| 2 | 2026-10-07 | Fonts: Google Sans + Google Sans Flex app-wide, Archivo Black only for chat title above chat bar | User choice; all OFL, bundled | - |
| 3 | 2026-10-07 | Phase 1 uses local models only (no cloud) | User choice; cloud stays Phase 3 | - |
| 4 | 2026-10-07 | Adopt UI Build Brief; M5 deferred under local-only | User brief | - |
| 5 | 2026-10-07 | Learnable user-taught skills proposed (data only, policy-gated); scope pending | User request | - |
| 6 | 2026-10-07 | Design direction: plain native iOS, green accent, warm neutrals | User choice after direction roll | - |
| 7 | 2026-10-07 | Storage: SwiftData (Apple native) for all in-app data, in Packages/Persistence | User request; replaces GRDB leaning | - |
| 8 | 2026-10-07 | Chat requests use ReasoningLevel.deep on iOS 27+ behind REASONING_API | User request | - |
| 9 | 2026-10-07 | Tool catalog + per-message routing; reply session gets only the matched tools | User request | - |
| 10 | 2026-10-07 | Learning model adapted from Hermes: bounded facts, searched skill playbooks, FTS5 chat search, 8192-token budget (accepted: auto-save facts with Undo, skills now, index both sides) | User request | - |
| 11 | 2026-10-07 | Local MLX models (8 mlx-community models) downloadable on request; chat only; model switch per chat. Replaces the Phase 3 default of decision 003 | User request | - |
| 13 | 2026-10-09 | Connectors for popular tools: easy ones (Obsidian folder, Contacts, Shortcuts, mail draft, Google Calendar via iOS accounts) first; token and OAuth ones wait for the network rule | User request | proposed |
| 12 | 2026-10-08 | Web tools: in-app WKWebView driven by openWebsite, lookAtPage, actOnPage; code-enforced site allow list, approvals for risky clicks, no password typing | User request (ios-web-agent walkthrough) | - |
| 16 | 2026-10-12 | Integrations are an icon grid; apps from one company (Google) share a menu, Apple apps stay separate; logos are simple-icons marks (CC0) and SF Symbols, not copied app icons | User request | - |
| 17 | 2026-10-12 | Files in chat: documents are read to text in code for every model; pictures go only to models that can view them; generated files are plain-text formats only, shown as a card with a share button | User request | - |
| 18 | 2026-10-12 | General skill system: one provider-neutral SkillRegistry (builtin, user, learned, imported) behind a single skill_use entry (find, use). Apple gets it as a tool; MLX and Cloud get the same find/use run in code. Skills are text, never raise permissions. Playbooks name tools; names are checked against the catalog and connector switches; imported skills are untrusted | User request | accepted |
