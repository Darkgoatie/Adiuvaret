# 009 Tool catalog and per-message routing

Every message first goes through a routing step: a small on-device request (guided generation, `ToolRoute`) decides whether a tool is needed and writes 3-6 search words. The words and the message are searched against the catalog (descriptions, keywords, examples) in ToolKit. The best matches plus their required tools (max 4) become the only tools in the reply session, and the reply continues with them. Messages that need no tool get a tool-free session, which also saves context.

Why: Apple advises 3-5 tools per request and a small model picks badly from many. New tools (reminders list now; notes, contacts, mail later) are added by one catalog entry and are not limited to calendar.

Costs and limits: one extra model call per message (latency not yet measured); the session is rebuilt whenever the chosen tool set changes, with history seeded from the last 12 messages; if the router call fails the app searches the user's message alone.
