# Learning (Skills)

Core model: a Skill is a taught procedure stored as data: instructions plus the generic tools and approved hosts it uses. The agent writes it after it has done the task once with the user watching; nothing in a Skill is executable code that the app downloads.

## Words
- Workflow: today's skill (decision 18): a named playbook of existing tool names. Renamed only; SkillKit types keep their names until a later cleanup, the UI, strings and docs say Workflow.
- Skill: the new thing in this file.

## Teaching flow
1. The user sends documentation (URL, file, pasted text) or just a goal ("send this to my Slack", "restart my server").
2. With only a goal the agent researches: searchWeb, openWebsite, readText. Documentation is untrusted text.
3. The agent does the task with the generic tools. Every write shows its approval card, as today.
4. After a successful run it offers Save as Skill (a card, like the Workflow offer). Saving needs a tap.
5. A saved Skill is found by term search like a Workflow; its short instructions enter the prompt only when it matches.

## Skill schema
id, name, description, keywords, instructions (max 1500 chars: base URL, auth style, the few endpoints or steps used, argument meanings, one example call), tools [generic tool names], hosts [approved hosts], credentials [slot names, values only in Keychain], source (taught, imported), untrusted (true if learned from a web page), version, enabled.

## Generic tools
- callAPI: host, method, path, query, JSON body. First use of a host asks the user to approve it (and to enter a token into the Keychain slot). Token is attached only to its approved host, no redirects, response size capped, never logged. GET runs automatically; POST, PUT, PATCH, DELETE always show an approval card with host, path and body.
- runScript: JavaScript in a JavaScriptCore context with no network, no file access and a time limit; for parsing, converting and calculating. Interpreted inside the app's own engine, so it is not downloaded native code (App Store 2.5.2). Result is text.
- makeDocument: existing generated-file path (decision 17), plain-text formats.
- sshRun (later task, needs an SSH library): host and key approved once, every command shows an approval card, destructive words raise the tier. Without it, server management goes through a provider API (Hetzner, DigitalOcean, Railway) with callAPI.
- Existing tools (calendar, notes, browser, connectors) stay available to a Skill through its tools list.

## Not responsible
Running native or downloaded executable code. Bypassing PolicyEngine: a Skill never raises a tier, and text read from docs or responses is untrusted context, so a write still needs the card.

## Invariants
- Hosts are only those the user approved; no built-in site list.
- Credentials never appear in a prompt, a Skill body, a log or a diagnostics line.
- Learned-from-web Skills are untrusted: using one calls markUntrusted.
- Skill instructions are searched in code; only matches enter the 8192 or 128000 token window.
- Learning needs a tool-calling online model. Apple and downloaded models can run a saved Skill only when its tools are available to them; MLX cannot call tools, so it cannot run Skills.

## Privacy
Documentation, requests and responses go to the online provider and to the approved host. Needs the first-use notice and a Privacy row for Skills (hosts, credential slots, erase).

## Open questions
- Which generic tools in round one (proposal: callAPI, runScript, makeDocument).
- sshRun: library choice and whether to ship at all.
- Whether a Skill may be promoted to a ConnectorManifest (typed tool, Undo) later.
- Sharing or importing Skills from others (always untrusted).

## Owned files (planned)
Packages/SkillKit (extend), Packages/ToolKit (CallAPI, ScriptRunner), App/Skills, App/Providers/ToolBridge (new tools).
