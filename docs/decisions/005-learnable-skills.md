# 005 Learnable skills (proposed, not yet scoped)

Requested by the user 2026-10-07: the assistant should learn new skills such as mail extensions and custom access to a university panel (user wording: "uni panel access and management"). These are not built in; the user teaches them during use. It should also keep general knowledge of the user as memory.

Design constraints that follow from earlier decisions:
- A skill is data (instructions, parameter schema, steps that call built-in tools), never downloaded code. App Store review forbids executing downloaded code.
- A skill cannot raise its own permission tier. Each step still goes through PolicyGate; skill-produced writes need approval unless the user grants it.
- Skill content and anything fetched through a skill is untrusted for injection purposes.
- Credentials for any account go in the Keychain, never in the model context or the skill text.
- 8192-token context (4096 floor): only 3-5 relevant skills are loaded per request; skill text must be short.
- Teaching flow: the user demonstrates or describes, the model drafts a skill, the user reviews and saves it; skills are listed, editable and deletable (same screen family as Memory).

Conflicts with the main brief, which lists as out of scope for v1: MCP client, HTTP connector builder, shell/filesystem automation, and reading Mail (draft-only). Reading mail or logging into a university panel would need exactly those. Needs a user decision on scope and phase before any build.

Open questions for the user:
1. Which phase: Stage 1 or later?
2. What does "uni panel" mean concretely (university student portal, which site)? Access by web login, API, or something else?
3. Mail: read access through IMAP/Gmail API as a skill, replacing draft-only?
