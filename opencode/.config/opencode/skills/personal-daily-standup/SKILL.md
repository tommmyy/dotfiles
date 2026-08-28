---
name: personal-daily-standup
description: >
  Generate a Czech stand-up ("SU") summary of what the user did today (or a given day)
  from local git history, grouped BY PROJECT/TENANT first. Use this skill whenever the
  user asks "co jsem dnes dělal", "quick info", "co mám na standup", "standup", "SU",
  "daily", "shrnutí dne", "what did I do today", "summary for standup", or asks to
  rewrite such a summary into Czech / regroup it by project. Also trigger when the user
  wants yesterday's or a specific day's work recapped for a team meeting. Reads git
  commits + working tree, maps each commit to its tenant/project via touched paths, and
  emits a short telegraph-style Czech bullet list ready to paste into chat.
---

# Daily Standup (SU) Summary

Produce the few lines the user reads out at stand-up. Output is Czech by default, telegraph
style, **project first**, business-readable — no SHAs, no branch names, no file paths unless
the user asks.

## Why the shape matters

Stand-up listeners track work by *product/tenant*, not by ticket ID or branch. A list ordered
by commit time forces everyone to re-sort in their head, and the same tenant appearing three
times reads as three separate topics. So the bullet key is always the project; issue IDs ride
along inside the bullet as provenance.

## Workflow

### 1. Collect the raw material

```bash
bash <skill-path>/scripts/collect-standup.sh                  # default window: yesterday 12:00 -> now
bash <skill-path>/scripts/collect-standup.sh '2026-08-07 12:00'  # or any git --since expression
```

**Window is yesterday noon → now**, not "today". Stand-up covers everything since the
previous day's lunch, so afternoon work that was already reported yesterday morning is
still in scope for today's — and work committed late yesterday would otherwise vanish
from every stand-up. After a weekend or a day off the window is empty or thin; widen it
to the last working day's noon (`'friday 12:00'`) and say so in the closing line rather
than reporting an empty day.

It prints, per commit: time, subject, and the **tenant/project codes derived from touched
paths** (`packages/tenant-<code>`, `config-tenants/<code>`), plus uncommitted work and
unpushed branches. Derive the project from paths, not from the commit subject — subjects
lie (a `pft` commit can also touch `pftsk`, and a ratchet commit names no tenant at all).

**Uncommitted work is stand-up content, and it is not only in the current directory.**
With one worktree per task (worktrunk / `personal-spawn-feature-env`), a whole day can go
into a feature worktree without a single commit — `git status` in the repo you happen to
be standing in would show none of it. The script therefore walks `git worktree list` and
reports every dirty tree with its branch, derived projects, and **last touched** mtime:

- Include a dirty tree only if its `last touched` falls inside the window. Old worktrees
  are long-lived scratch dirs (a stale `?? newgen-demo/` from three months ago is not news).
- Map it to a task ID via the branch name (`feature/CUS-829-assistant-widget` → CUS-829),
  and to a project via the printed `projects:` line.
- Report it as in-progress — `rozděláno` / `rozpracováno` — not as shipped.

Two ways the path heuristic misleads, both easy to spot:

- **Too many projects** — a commit listing 10+ tenants is a shared/`tenant-common` change
  that merely rippled into every tenant's config. Key it by the tenant the issue is
  actually about (subject line, branch name), or by `napříč` if it genuinely is.
- **No projects** — build/size-baseline/tooling commits touch no tenant path. Attach them
  to the tenant whose feature caused them (a `pftsk` baseline ratchet belongs with the
  `pft / pftsk` bullet), otherwise `infra`.

If the script's repo assumptions don't fit (monorepo elsewhere, different tenant layout),
fall back to `git log --all --since=... --author="$(git config user.email)"` plus
`git show --stat` and map projects by whatever the repo's product boundary is.

### 2. Group

- One bullet per project/tenant. Merge every issue for that project into that one bullet.
- Sibling tenants that shipped the same change collapse into one key: `pft / pftsk`.
- Commits touching no product (tooling, CI, shared libs, size baselines) go into a final
  bullet keyed `napříč` or `infra` — unless the change only exists to serve one tenant
  (e.g. a size-baseline ratchet caused by that tenant's feature), in which case it belongs
  in that tenant's bullet as a trailing clause.
- Order bullets by weight: the project with the most/biggest work first.
- A dirty worktree inside the window gets a normal project bullet like any other work,
  ending in `— rozděláno`. Don't demote a full day of uncommitted work to a footnote in
  the closing line just because it has no commit yet.

### 3. Write it in Czech

Translate the engineering change into what it *does for the shop*, not what the diff did.
"re-enable behind a split" → "znovu zapnuté … za splitem". Keep each bullet to one sentence,
drop articles and filler, keep the issue ID.

Template:

```
**Standup – <D. M.>**

- **<projekt>** – <TASK-ID>: <co se změnilo, česky, telegraficky>.
- **<projekt>** – <TASK-ID>: <…>.

<stav odevzdání>. Blokace: <žádné | co blokuje>.
```

Closing line reports reality from the script: everything pushed vs. N větví nepushnutých vs.
rozdělaná práce ve stromu. Never write "vše pushnuto" without having seen it.

### 4. Offer the next step, don't assume it

If the user asks for English, a longer technical version, or a paste into Linear/Slack, adapt.
Default is the short Czech list above.

## Example

Input (from the script): 5 commits — CUS-858 ×4 touching `packages/tenant-pft` +
`tenant-pftsk` (one of them a size-baseline ratchet), CUS-183 touching `tenant-sxssk`,
CUS-819 touching `tenant-alt`, CUS-903 touching `tenant-sti`, CUS-902 touching `tenant-atx`.

Output:

```
**Standup – 11. 8.**

- **pft / pftsk** – CUS-858: články ve vyhledávání (našeptávač i SERP bez výsledků),
  v idle panelu přesunuté pod doporučené produkty, v postranním sloupci 5 populárních
  kategorií; ratchet size baseline.
- **sxssk** – CUS-183: kurátorovaný dotaz na populární články v idle panelu.
- **alt** – CUS-819: znovu zapnuté „mohlo by se vám líbit" na detailu produktu, jen desktop, za splitem.
- **sti** – CUS-903: hodnocení na kartě srovnané s nativní kartou (proužek nad cenou).
- **atx** – CUS-902: odstraněná vedlejší cena v BGN z product boxu.

Vše na 4 větvích, pushnuto. Blokace: žádné.
```

Note what the example does *not* contain: commit hashes, branch names, "feat/fix" types,
file counts. Those are audit trail, not stand-up.
