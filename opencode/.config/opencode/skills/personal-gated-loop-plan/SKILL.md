---
name: personal-gated-loop-plan
description: >
  Turn a PLAN into a durable, self-driving agentic loop with phases, exit-code
  gates, an append-only journal, resumable state, a trajectory log, an attempt
  budget, a verification oracle, and a ratcheted progress metric. Use this whenever
  the user wants to convert a multi-step plan/campaign/migration/refactor/burndown
  into a gated loop, scaffold a "command-router" workflow skill, or asks for
  "phases and gates", "journal + state", "agentic loop", "gated loop", "make this
  resumable / survive compaction", "attempt budget", "ratchet", "characterization
  net before refactor", or "an orchestrator prompt that drives the loop". Also
  trigger when a conversation has produced a plan and the user says "codify this
  pattern", "make a skill for that", or "we do this often — turn it into a loop".
  Produces a gated-loop SKILL.md + orchestrator prompt + state/journal/backlog +
  gate-script contracts. Complements personal-skill-creator (which handles generic
  authoring/eval); this owns the specific PLAN→gated-loop architecture.
---

# PLAN → gated agentic loop scaffolder

You keep building the same shape: a plan executed as a **loop of items, each pushed
through fixed phases, where an exit-code gate — not the model's word — decides whether
a step may run and whether the result is accepted**, with durable `state` + `journal`
so it survives `/compact` and hand-offs. This skill turns any plan into that shape.

Exemplars in the wild to imitate: `sa-collectomat-tenant` (per-phase gates + schemas +
3-attempt budget + trajectory), `sa-typecheck-burndown` (per-item loop + journal +
ratchet), `sa-typecheck-strengthen` (safety-net oracle + weakness census + inverted
rule). Read `references/anatomy.md` for the distilled invariants and WHY each exists.

## When to reach for this (vs alternatives)

- Use THIS when the work is a **repeated loop over many similar items** (packages,
  tenants, files, migrations, bugs) that must be **verifiable, resumable, and
  regression-safe**, and the user wants gates rather than trust.
- Use `personal-skill-creator` when the goal is authoring/evaluating a skill in
  general (trigger tuning, evals, benchmarks). You can chain: scaffold here, then
  optimize the description there.
- Skip both for a one-shot task with no repetition and no resume need.

## The scaffolding workflow

Work through these; don't skip the interview — a loop with the wrong unit-of-work or
a missing oracle is worse than no loop.

### 1. Capture the plan + run the design interview

If the conversation already contains the plan, extract answers first, then confirm the
gaps. Resolve these SEVEN decisions (they parameterize everything downstream):

1. **Unit of work (the "item").** What repeats? (package, tenant, file, bug, migration
   step.) Everything loops over this. Pick the smallest independently-shippable unit.
2. **Phases.** The linear state machine each item passes through
   (`pending → … → done`). One `in_progress` at a time. Name 4–9 phases.
3. **Gates.** Between which phases does an exit-code check run, and what does each
   assert? Every gate is a script that exits non-zero on fail and appends to the
   trajectory. Name the mutation scope per phase (`none|artifact|source|golden|…`).
4. **Verification oracle.** The domain-specific "did we break anything / is this
   correct" check the VERIFY gate runs — tests, a golden-master/characterization net,
   a typecheck, a schema validation, a live smoke. **If the plan changes behavior,
   the oracle usually must exist BEFORE the loop starts** (build it as phase P0).
5. **Ratcheted metric.** The monotonic progress number with a `--check` that fails on
   backslide (error count, weakness census, coverage, TODO count). Wire it into
   pre-push/CI so the loop can't regress silently.
6. **Escalation triggers.** When must the loop STOP and ask the human? (attempt budget
   exhausted, contract/behavior change, oracle disagreement, ambiguous intent.)
7. **Storage root + artifacts.** Where durable state lives (`tools/<name>/` or
   `.<name>/`) and which JSON artifacts + schemas each phase writes.

Offer sensible defaults (3-attempt budget, `report exit 0` = authoritative pass,
cores-solo/independent-items-parallel) and let the user override.

### 2. Choose what to BUILD NOW vs specify as CONTRACT

You rarely implement all gate scripts up front. Decide per script: build it now
(cheap, unblocks the first item) or specify its **contract** (inputs, exit codes, JSON
output, trajectory append) as a P1 "build the harness" backlog item. The burndown/
strengthen skills specify most scripts as contracts and build them in an early phase —
that's fine and often preferable when the user asked for "a plan/skill, don't run
anything."

### 3. Emit the artifacts

Copy the templates and fill them in (replace every `<…>` placeholder):

| Output | From template | Purpose |
| --- | --- | --- |
| `<skill-name>/SKILL.md` | `assets/SKILL.template.md` | The router: gates, invariants, phase machine, DoD |
| `<skill-name>/prompts/run-loop.md` | `assets/orchestrator-prompt.template.md` | The driver a human pastes to run the loop autonomously |
| `<root>/<name>-backlog.md` | (author from the plan) | The WHAT — enumerated items with ids, cited sources, leverage order |
| `<root>/state.json` | `references/anatomy.md` §State schema | Resume pointer + per-item status. Seed with all items `pending` |
| `<root>/journal.md` | `references/anatomy.md` §Journal | Append-only, newest-first. Seed with the header + entry template |
| `<root>/schemas/*.schema.json` | (author per artifact) | Validate every JSON artifact |
| gate scripts (build-now ones) | `references/anatomy.md` §Gate script contract | exit-code + JSON + trajectory append |

Keep SKILL.md < 500 lines; push deep domain detail into `references/` and load
per-phase (progressive disclosure). Match the host repo's conventions (read its
`AGENTS.md`; e.g. this repo wants telegraphic, dense, min-token prose and Conventional
Commits).

### 4. Seed one item and dry-run on paper

Walk a single item through every phase, naming the exact gate command and its
pass/fail at each step. This surfaces missing gates, wrong mutation scopes, and an
absent oracle before any code runs. Fix the templates, not just the instance.

### 5. Wire the ratchet LAST

Only after an item can go green end-to-end, add the metric's `--check` to
`.husky/pre-push` (or CI) next to the hard verification. The ratchet is what makes the
loop safe to leave running.

## Non-negotiable invariants to bake into every loop (the WHY is in anatomy.md)

- **Gates decide, not the model.** Every phase transition is an exit-code script that
  logs to the trajectory. "Looks done" is never done — only `report exit 0` is.
- **Never start an item from red.** A prereq gate confirms the tree/oracle is green on
  HEAD before touching anything, so a regression is always attributable to the item.
- **Resume from state, not chat memory.** First action every session: read `state.json`
  + newest `journal.md` + `git log`. State files are the source of truth after compact.
- **One `in_progress` at a time** per worker; parallelize only mutually-independent
  items; widely-shared/core items run SOLO.
- **Attempt budget (default 3/phase)** → then escalate to the human. No thrashing.
- **Behavior changes need a regression test + human sign-off; type/refactor-only
  changes need an EMPTY oracle diff** — that asymmetry is what proves "nothing broke."
- **Append-only journal, newest-first, one entry per reusable root cause** — so the
  same gotcha is never rediscovered.
- **Progressive disclosure**: SKILL.md is the router; per-phase references load on
  demand.

## Output to the user

After scaffolding, summarize: the seven decisions as resolved, the file tree created,
what's build-now vs contract, and the exact first command to run (usually
`<skill> run` or the prereq/P0 gate). Then offer to (a) implement the build-now gate
scripts, or (b) hand off to `personal-skill-creator` to tune the description triggers.

## Reference + templates

- `references/anatomy.md` — the distilled pattern: every invariant with its WHY, the
  state/journal/trajectory schemas, the gate-script contract, the phase state machine,
  the ratchet + oracle design. Read before scaffolding a non-trivial loop.
- `assets/SKILL.template.md` — gated-loop SKILL.md skeleton.
- `assets/orchestrator-prompt.template.md` — loop-driver prompt skeleton.
