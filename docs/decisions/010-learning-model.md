# 010 How Adiuvaret learns (adapted from the Hermes agent design)

Status: accepted 2026-10-07 with the user's answers below. Supersedes the scope of task 36 and extends task 19.

## What is kept from Hermes

1. No fine-tuning. Learning is text the app stores and puts in front of the model.
2. Bounded state with hard caps, so the prompt never grows without limit.
3. Progressive disclosure: only a small index is always visible, full playbooks load when a request matches.
4. Local keyword search over past conversations.
5. A fixed assembly order for every request.

## What changes, and why

Apple's on-device model has a context of 8192 tokens. Hermes spends about 4,300 tokens before the conversation starts (3,000 of them on the skill index). Here that would leave almost nothing. So the same ideas run with a much smaller budget, and the index is searched in code, not pasted into the prompt.

Budget for one request (tokens, approximate):

  Persona and safety rules, fixed in code (SOUL)      about 200
  Known facts about the user (MEMORY + USER merged)   about 200   (max 8 facts, 200 characters each)
  Chosen tools (3 to 4, about 45 each)                about 180
  Matched skill playbooks (max 2)                     about 250   (max 400 characters each)
  Past-chat snippets, only when asked                 about 150   (max 3 snippets, 160 characters each)
  Tool results                                        dynamic, capped per tool
  Conversation (last 12 messages)                     the remainder, at least 5,000

The skill and tool indexes are never in the prompt. The router step (decision 009) searches them in code and loads only the matches. That is Hermes' Level 0 and Level 1 with the lookup moved out of the model.

## Mapping

  SOUL.md           A fixed instruction string in code. Not editable by the model or by learned text.
  MEMORY.md + USER.md   One list of short facts (MemoryRecord). Retrieval picks the relevant ones for each message
                        (MemoryMath.relevant). Capped at 40 facts, 200 characters each.
  Skill files       SkillRecord: title, when-to-use description, keywords, playbook text (max 400 characters).
  index.json        Built in memory from the records. Searched with the same engine as the tool catalog.
  load_skill(id)    Done by the router. Matching playbooks are added to the reply session instructions.
  Level 2 assets    Not used in Stage 1.
  SQLite FTS5       A separate small SQLite file with an FTS5 table over user and assistant messages, kept in step
                    with chat saves. SwiftData cannot do full-text search. FTS5 in the iOS system SQLite is expected
                    but must be verified on a device before building on it.
  session_search    A searchPastChats tool in the catalog. Read-only. Returns snippets with chat title and date.

## How learning happens

Facts:
  1. After a turn that contained a stated personal fact, a guided-generation step proposes at most one fact.
  2. The fact is saved automatically and a toast shows "Remembered: <fact>" with Undo (user answer 1). The Memory screen can edit or delete it later.
  3. Duplicates are dropped (MemoryMath.isDuplicate). Memory screen lists, edits and deletes facts.
  4. A remember tool also exists so the user can say "remember that ..." directly. It is a reversible write: approval card plus Undo.

Skills:
  1. After a task that used two or more tools and succeeded, the app offers "Save this as a skill".
  2. The playbook text is built from the recorded steps (tool names and argument shapes, never values) plus a one-line
     description the user can edit. It is not free text written by the model.
  3. Skills are text only. They cannot add tools, raise a permission tier or switch off approvals. Every tool call
     still goes through PolicyGate.
  4. Skills have an on/off switch and a delete button in the Memory area.

## Safety rules

  - Every automatic save shows a toast with Undo and appears in the Memory screen. Skills are only saved after the user taps Save.
  - Learned text is placed after the fixed rules and labelled as user data. It is never treated as instructions that
    can override them.
  - Content read from the calendar, reminders or other apps is never saved as a fact or skill automatically.
  - When memory is full, the app tells the user and asks what to forget or merge. It never trims silently (Hermes
    auto-trims; here the user owns the data).
  - Diagnostics (decision 8) log counts and timings of memory and skill use, never the text.
  - Everything stays on the device, which keeps decision 003.

## Tasks created

  38  Diagnostics screen and log (done, in build 19)
  39  Memory store, retrieval and prompt assembly with the budget above (extends 19)
  40  Skills: store, match, offer-to-save from a successful run (replaces the scope of 36)
  41  Past-chat search: FTS5 index and searchPastChats tool

## Answers (2026-10-07)

  1. Facts are saved automatically, with an Undo toast.
  2. Skills are built now, together with memory (tasks 39 and 40 run in one pass). They still need a tap on Save, because a skill changes how requests are handled.
  3. Past-chat search indexes the user's messages and the assistant's replies.
