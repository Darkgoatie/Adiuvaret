# SkillKit

Core model: a skill is a named, searchable block of instructions; every model, whatever its provider, reaches skills through one skill_use entry backed by one registry.

## Responsibility
Skill schema, SkillRegistry (builtin, user, learned, imported), term-ranked find, validation, JSON persistence of added skills.

## Not responsible
Running tools (ToolKit, PolicyEngine), permissions, UI, network. A skill never raises a permission.

## Interface
- Skill: id, name, description, keywords, examples, body (max 1200 chars), allowedTools [String], requires [connector], version, source, enabled, untrusted.
- SkillRegistry.register(_:) throws on duplicate id, empty body, unknown tool name.
- find(query, limit) returns id, name, description only. use(id) returns the body of an enabled skill.
- Only the index line enters a prompt; a body loads after selection (8192-token window).

## Invariants
- Same registry call on every provider; adapters differ only in how the call is triggered.
- Disabled skill is neither found nor used. Skill naming a hidden connector tool does not expose it.
- Logs carry ids and counts, never bodies.

## Dependencies
ToolKit tool names (by interface), ConnectorCatalog.visible.

## Owned files
Packages/SkillKit/

## Tests
Pure package tests, run on the GitHub Actions package step.
