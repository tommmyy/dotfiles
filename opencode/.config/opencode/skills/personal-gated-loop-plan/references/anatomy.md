# Anatomy of a gated agentic loop (the distilled pattern + WHY)

Read this before scaffolding a non-trivial loop. Every element earns its place; the
WHY matters more than the shape, because you'll adapt the shape per domain.

## Mental model

A **plan** becomes a **loop over items**. Each item is pushed through a **linear phase
state machine**. Between phases sit **gates** — exit-code scripts that are the sole
authority on whether a step may run and whether its result is accepted. Durable
`state` + `journal` + `trajectory` make the loop **resumable, auditable, and
regression-safe** across sessions, `/compact`, and hand-offs to other agents/humans.

The whole point: **remove trust from the loop.** The model is smart but forgetful and
optimistic; gates make progress verifiable and backslide impossible.

## The 12 invariants (with WHY)

1. **Gates decide, not the model.** Each transition runs a script that exits non-zero
   on fail. WHY: "looks done" is the #1 source of silent breakage; a machine check is
   reproducible and un-foolable. Only the final `report` script's exit 0 is
   authoritative pass.
2. **Never start an item from red.** A prereq gate asserts the verification oracle +
   any hard check are green on HEAD before mutation. WHY: makes every regression
   attributable to exactly one item; without it you can't tell who broke what.
3. **Resume from state, not memory.** Session step 1 = read `state.json` + newest
   `journal.md` + `git log`. WHY: context windows compact; chat memory is lossy; the
   files are the source of truth so any agent can pick up mid-campaign.
4. **One `in_progress` at a time** per worker. Parallelize only mutually-independent
   items; shared/core items land SOLO with a full re-scan. WHY: two workers editing a
   shared surface shift each other's gate results non-deterministically.
5. **Attempt budget (default 3/phase), then escalate.** WHY: bounded retries stop the
   model burning the session re-trying a doomed approach; the human unblocks with
   context the model lacks (intent, missing access, a design call).
6. **Mutation scope per phase** (`none|artifact|source|golden|…`), enforced. WHY: a
   discovery/verify phase must not edit source; scoping catches accidental churn and
   keeps diffs reviewable.
7. **Verification oracle + the diff asymmetry.** VERIFY runs the domain oracle (tests /
   golden-master / typecheck / schema / smoke). **Behavior-changing items** need a
   regression test (red-first for bug fixes) + the oracle diff must equal a *signed
   expected delta*; **refactor/type-only items** must produce an **EMPTY** oracle diff.
   WHY: the empty diff IS the proof nothing broke; the signed delta is the proof the
   only thing that changed is what you intended. Build the oracle BEFORE the loop
   (phase P0) whenever the plan changes behavior.
8. **Ratcheted metric with `--check`.** A monotonic progress number (error count,
   census, coverage) whose `--check` exits 1 on any regression, wired into pre-push/CI.
   WHY: lets the loop run unattended without backsliding; it's the campaign's guardrail.
9. **Append-only journal, newest-first, one entry per reusable root cause.** WHY: the
   same gotcha recurs across items; a searchable log means it's solved once. Never
   rewrite history; never fork a second journal.
10. **Trajectory (append-only jsonl) from every gate.** WHY: an audit trail of gate
    runs / blocks / repair attempts for debugging the loop itself and for `status`.
11. **Schemas validate every JSON artifact.** WHY: a malformed artifact silently
    corrupts downstream phases; parse-time validation fails fast at the producer.
12. **Progressive disclosure.** SKILL.md routes; per-phase references load on demand.
    WHY: keeps the always-in-context surface small and the model focused on one phase.

## Phase state machine

```
pending → <phase-1> → <phase-2> → … → <verify> → <ratchet-check> → <signoff?> → committed → done
                                   │
                     (gate fail → repair ≤N/phase → else ESCALATE to human)
```

- Entry to phase P requires: all upstream phases `pass`, budget `≤ N`, prereq green.
- The agent prints a machine-checkable **preflight line** before editing, e.g.:
  `LOOP_PREFLIGHT: setup=pass prereq=<oracle> item=<id> phase=<p> upstream=<status> budget=<n>/N mutation=<scope>`

## The per-item loop (generic)

```
1. SELECT     next item from state.json (backlog order / leverage). Mark in_progress,
              set resume.item, declare its target metric cells + touched surfaces.
2. PREPARE    ensure the oracle covers the touched surface (add coverage if missing);
              baseline it green on the untouched tree.
3. TEST       write/expand the regression test pinning intended behavior (red-first for
              a bug fix). Refactor-only: assert the contract/shape.
4. CHANGE     do the work. mutation=source. Prefer changes that DELETE debt (measure it).
5. VERIFY     oracle green + tests green + diff asymmetry holds (empty | signed-delta) +
              any live smoke.
6. METRIC     ratchet --check: target dropped, nothing regressed.
7. SIGNOFF    if contract/behavior/wide-cascade → recorded human sign-off before commit.
8. COMMIT     scoped Conventional Commit; update state.json; append journal.md; ratchet
              --write-baseline. Clear resume.item.
9. REPORT     report exit 0 = DONE. Loop.
```

## Durable state — file shapes

### state.json
```json
{
  "updatedAt": "<iso>",
  "phase": "<current-workstream-or-null>",
  "resume": { "item": "<id-or-null>", "action": "<free-text next step>" },
  "metric": { "name": "<error-count|census|…>", "baseline": 0, "current": 0 },
  "items": {
    "<id>": {
      "status": "pending|in_progress|blocked|cleared|done",
      "phase": "<phase>",
      "attempts": 0,
      "commit": null,
      "note": "<one-line durable summary>"
    }
  }
}
```

### journal.md (append-only, newest first)
```
# <name> journal
Append-only. One entry per reusable root cause. Newest first.

## <date> — <item/bucket> — <short title>
- Symptom: <signal + where>
- Root cause: <why>
- Fix: <what changed, file:line>
- Blast radius: <downstream items that moved for free>
```

### <root>/<name>-backlog.md (the WHAT)
Enumerate items with stable ids, cited sources (point back at the plan/journal),
leverage order, per-item target metric cells + touched surfaces, and a
behavior-vs-refactor tag.

### .trajectory.jsonl (append-only)
One JSON object per gate run: `{ "ts", "item", "phase", "gate", "exit", "note" }`.

## Gate script contract

Each gate script (mirror an exemplar like collectomat's `scripts/*.mjs`):
- Input: `--item=<id>`, `--phase=<p>`, plus flags (`--check`, `--write-baseline`, `--json`).
- Exit 0 = pass, non-zero = fail (the loop halts / repairs on non-zero).
- Emits JSON (machine-readable) on `--json`; human summary otherwise.
- Appends a line to `.trajectory.jsonl` on every run.
- Never mutates source; a gate is read-only except for its own artifact.

Common scripts: `check-setup`, `check-preflight`, `progress` (state machine +
attempt counter), `<oracle>` (tests/golden/typecheck runner + `--check`/`--update`),
`<metric>` (`--check`/`--write-baseline`), `validate-*` (schema/test/signoff),
`final-report` (authoritative pass).

## Oracle design cheatsheet

- **Refactor / type-only campaigns** → oracle = existing tests + a characterization
  (golden-master) net; the diff-asymmetry (empty vs signed delta) is the safety proof.
- **Behavior/feature campaigns** → oracle = new+existing tests; red-first for fixes.
- **Type campaigns** → oracle = `tsc` green + a weakness census (casts/any/nocheck).
- Determinism ≠ mocks. If mocking is banned or unrepresentative (real integrations,
  live sites), get determinism from HOW you assert, not from faking inputs:
  - **Assert CONTRACTS/invariants, never volatile content** — structure, counts within a
    range, required parts present, event NAME+SHAPE+count, zero errors. Real content
    changes every run; a contract holds regardless.
  - **Make the per-item oracle a DIFFERENTIAL** — run baseline (pre-change) and candidate
    (post-change) back-to-back under the SAME live conditions and diff the normalized
    contract. Same-contract = safe; contract-delta = exactly your intended change.
  - **Handle flake explicitly** — retry transient errors (retryable ≠ fail); a real
    violation must reproduce on retry. Pin the config knobs you DO control (cookies,
    viewport) — that's config, not a mock.
  - Scope the oracle to the CRITICAL path only (revenue/analytics/high-exposure);
    exclude decorative/low-value surfaces so the net stays fast and non-flaky.
  Deterministic fixture/mock oracles are fine when representative; otherwise prefer the
  contract+differential approach above.
- Build the oracle as **phase P0** whenever behavior can change — a redesign without a
  net turns "improvement" into "silent regression."

## Anti-patterns (seen and avoided in the exemplars)

- Ratchet only tracks non-zero buckets → a cleared item regressing 0→N slips the gate.
  Fix: full-board scan after any shared-surface change; pin cleared items at 0 too.
- Wrapping a now-void call in an arrow to "fix" a type → changes WHEN a side effect
  fires = runtime regression. Preserve timing; fix the type, not the schedule.
- Silencing with `any` / `@ts-nocheck` / broad casts → moves debt, doesn't remove it.
  The metric must count these so the loop can't "progress" by hiding.
- Starting the loop before the oracle exists → you can't prove anything is safe.
