---
name: personal-team-context
description: >
  Durable knowledge store for Tomáš's team vocabulary — who the colleagues are,
  what internal shorthands mean (tenant codes like `pft`/`kzd`/`sps`, product
  nicknames like "FAB", "touchpoint", "precart"), and decisions already agreed in
  chat. Load this skill whenever a message contains an unexplained internal
  shorthand, a colleague's name, a tenant abbreviation, or a product nickname;
  whenever the user says "remember this", "note that X means Y", "add to the
  glossary", "who is X", "what does X mean"; and at the start of any workflow
  that ingests raw team communication (Slack/Teams screenshots, pasted threads,
  meeting notes). Also load before asking the user a clarifying question — the
  answer may already be here.
---

# Team Context: persistent glossary

## Purpose

Stop re-asking the same questions. Every time the user explains an internal
term, that explanation gets written here so the next session already knows it.

The user is **Tomáš Konrády** (Slack `@tom`). Everyone else named in chat is a
colleague unless stated otherwise.

## The data file

All knowledge lives in **`glossary.md`** next to this file. Read it in full —
it is small by design. Never duplicate its content into another skill; link to
it instead.

## Rules

1. **Read before asking.** Before you ask the user "what does X mean", grep
   `glossary.md`. Asking a question already answered there is the failure mode
   this skill exists to prevent.
2. **Append, never rewrite.** New entries go at the end of their section with a
   `<!-- learned YYYY-MM-DD -->` marker. Do not reflow or "tidy" existing
   entries — the diff should show only what you added.
3. **Only record what the user confirmed.** Never write an inferred meaning as
   fact. If you guessed, either ask, or file it under `## Open questions` with
   the guess marked `(unconfirmed)`.
4. **Conflicts are escalated, not silently resolved.** If a new answer
   contradicts an existing entry, show the user both and ask which wins. Then
   replace the old line and add `<!-- superseded YYYY-MM-DD: was <old> -->`.
5. **Verify code-facing claims against the repo.** A mapping like
   `FAB = ZoeCopilotFabV0` must resolve to a real path. Confirm with a grep
   before writing it, and store the path so the next session can jump straight
   there.
6. **Don't store secrets.** No tokens, credentials, customer PII, or salary/HR
   talk. Vocabulary and technical mappings only.
7. **Keep it a glossary, not a diary.** Durable facts (who/what/where) belong
   here. Per-task state belongs in that task's artifact (e.g.
   `private.plans/…`).

## When the user teaches you something

Trigger phrases: "X means Y", "that's our tenant", "he's from …", "remember
this", "add that to the glossary".

Action: append the entry, then confirm in one line what you stored and where.
Do not narrate the whole file back.

## Sections in `glossary.md`

| Section | Holds |
|---|---|
| `## People` | Colleagues, their role, how they show up in chat |
| `## Tenants` | Shorthand → package path → live domain |
| `## Product vocabulary` | Nicknames → real component/concept + repo path |
| `## Agreed decisions` | Things already settled in chat, with date + source |
| `## Open questions` | Unconfirmed guesses awaiting the user's answer |

## Common mistakes

- Asking a question whose answer is already in `glossary.md`.
- Writing an inferred meaning as if the user confirmed it.
- Reformatting the whole file so the diff hides the one real change.
- Storing task status/progress here instead of vocabulary.
- Recording a component name without checking it exists in the repo.
