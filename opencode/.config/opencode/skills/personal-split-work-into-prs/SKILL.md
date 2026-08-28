---
name: personal-split-work-into-prs
description: >
  Use this skill when the user has a pile of local changes (staged and/or
  unstaged, usually hacked directly on `develop`) and wants to split them into
  several logical tasks and ship each as its own branch + single commit + pull
  request. Trigger on phrases like "split my changes into tasks", "break this
  work into separate branches/PRs", "I did a lot of work, divide it into
  tickets", "one branch/PR per task from this diff", or any request that
  combines grouping a working tree into multiple Linear issues and opening a
  branch/commit/PR for each. This is the multi-task sibling of
  `personal-quick-feature` (which handles the single-task case). Always rebases
  onto the latest `develop` first, follows the repo commit-message and
  branch-name conventions, creates one commit per task, and returns a
  create-PR URL per branch.
---

# Split Work Into Tasks → Branches → PRs

## Purpose

Take a working tree full of mixed changes and cut it into N self-contained
tasks, each landing on its own branch as a single convention-compliant commit,
pushed with a PR ready to open. The "I hacked a bunch of stuff on develop, now
file it properly as separate tickets and PRs" workflow.

This is `personal-quick-feature` scaled to many tasks at once. Reuse its rules
(and `personal-linear-task-intake`'s) for the per-task Linear plumbing rather
than reinventing them — this skill owns the **grouping** and the **multi-branch
git mechanics**, which are where things actually go wrong.

## Guardrails (read before touching anything)

- **The user's working tree is the only copy of this work.** Most of it is
  uncommitted. Never run `git reset --hard`, `git checkout -- .`, `git clean`,
  or a blind `git stash drop` until every group is committed on a branch AND
  you've verified full coverage (last step). Prefer additive operations.
- **Snapshot first.** Before any branch juggling, capture the entire change set
  in one recoverable place (a `git stash push -u` or a scratch WIP commit) so a
  mistake can't lose work. See step 3.
- Confirm the grouping with the user before creating anything — a wrong split
  means wrong tickets and wrong PRs.

## Workflow

### 1. Rebase onto the latest `develop` first (mandatory)

Always start from current `develop` so branches are based on up-to-date code.

```bash
git fetch origin
git rev-parse --abbrev-ref HEAD   # expect: develop
git status --short                # note staged + unstaged; this is the work
```

- If the changes are uncommitted on `develop` and `develop` is merely *behind*
  `origin/develop` (fast-forward, no overlap with your changed files), you don't
  need to move them — you'll base each new branch directly on `origin/develop`
  (step 4), which is equivalent. Confirm no overlap: `git diff --name-only
  develop origin/develop` should not list any file you changed.
- If the current work is already sitting on a **feature branch** (not `develop`),
  or the base diverged, rebase it onto `origin/develop`
  (`git rebase origin/develop`) and resolve conflicts before splitting.
- **Watch for a stale base.** If a branch/commit you're building on was cut from
  an old, never-pushed `develop`, it can carry ghosts: files the real `develop`
  has since **renamed** or **deleted** reappear, and already-merged work looks
  "new". Symptoms during rebase: many `add/add` conflicts on files that already
  exist on `origin/develop`, or orphaned directories. Fix by re-basing on
  `origin/develop` and keeping ONLY the genuinely-new files — compare each file
  to develop with `git diff --quiet origin/develop:<path> <ref>:<path>` and drop
  the ones that are identical (`SAME`) or are develop-side deletions/renames.

### 2. Inspect and group the changes into tasks

Read the actual diff, not just file names, so the split is by *intent*:

```bash
git add -A                 # optional: stage everything so nothing is missed
git diff --cached --stat
git diff --cached           # read the hunks; for big output, read per area
```

Cluster files into logical tasks. Good grouping signals:

- Same feature/fix (e.g. a search-takeover feature spanning init.js +
  controller + config + theme is ONE task, even across many files).
- Same subsystem/theme (e.g. "bundle-size / tree-shaking" tweaks across
  unrelated files can be one task if that's the single intent).
- A file can only belong to **one** group. If a file has hunks for two
  different tasks, split the hunks (`git add -p`) — but prefer clean per-file
  grouping when possible.

Delegate the "which Linear task" decision per group (step 3). Present the
proposed grouping (files → task) to the user and get confirmation or
corrections **before** creating branches or issues. Ask, in one consolidated
question, how any ambiguous file should be grouped and whether each group maps
to an **existing** Linear issue or needs a **new** one.

### 3. Snapshot the whole change set

Once grouping is agreed, freeze everything into one recoverable ref so the
per-branch checkout is deterministic and the tree can be made clean per branch:

```bash
git stash push -u -m "split-pending"   # -u includes new files
```

Everything now lives in `stash@{0}`. You'll pull each group's files out of it
per branch. (A scratch `git commit` on a throwaway branch works too; stash is
simplest.) Do NOT drop this stash until the final coverage check passes.

### 4. Per task: branch → move files → commit → push → PR

Do this once per group. The key constraint: **this repo's `pre-push` hook
requires a clean working tree** (it runs `yarn lint`, `yarn typecheck`,
`yarn build`, then refuses to push if any staged/unstaged change remains). So
each branch must contain ONLY its own group's files, already committed, with
nothing else dirty. Basing each branch on `origin/develop` and checking out
only that group's paths from the snapshot achieves exactly that.

```bash
# a. branch off the up-to-date remote base (NOT local develop)
git checkout -b <TASK-ID>/<stub> origin/develop

# b. bring in ONLY this group's files from the snapshot
git checkout stash@{0} -- <file1> <file2> ...

# c. stage + commit as a SINGLE commit (see message convention below)
git add <file1> <file2> ...
git commit -m "<TASK-ID> <type>(sa): <summary>" -m "<body>"

# d. push; capture the create-PR URL from the remote output
git push -u origin <TASK-ID>/<stub>
```

- **Branch name** — follow AGENTS.md "Branch names": `{TASK-ID}/{stub}` where
  `stub` is the slug copied verbatim from the Linear issue URL
  (`linear.app/perselio/issue/<TASK-ID>/<stub>`). Example:
  `PER-668/bundle-size-program-size-gate-shipped-entries-2-3percent`.
- **Commit message** — follow AGENTS.md "Commit messages":
  `TASKID type(sa): message`, scope always `sa`, Conventional-Commits `type`,
  **one commit per task**. Put the detail in the commit body (`-m` again), not
  in more commits.
- **Clean-tree check** before pushing: `git status --short` should show only
  pre-existing untracked dirs, nothing tracked-and-dirty. If the hook still
  complains about unstaged changes, you left files from another group in the
  tree — they should be in the snapshot, not here.

Repeat for each group. Because every branch is cut fresh from `origin/develop`,
they're independent (no stacking) and their PRs don't depend on each other.

### 5. Linear plumbing per task (existing issue vs new)

For each group, either it maps to an **existing** Linear issue (use that
identifier + URL) or it needs a **new** one. For a new issue, create it via the
**`personal-linear-task-intake`** skill and apply these pins (identical to
`personal-quick-feature`):

- **assignee**: always `"me"`. **cycle**: always `"current"`.
- **state lifecycle**: create in **`Todo`**, then **immediately** update the
  same issue to **`In Progress`** (two distinct steps — never create directly
  in `In Progress`, never skip the transition).
- **team / project** (intake's Team & Project Selection): change affects
  **exactly one tenant** → team **CUS** + that tenant's project; otherwise
  (multi-tenant / general / internal tooling) → team **PER**. Derive the tenant
  from the diff when obvious (tenant-specific `config-tenants/<t>/…`,
  `packages/tenant-<t>/…`, theme files); else ask.
- **`Data-issue` label**: add it when the change could **significantly
  influence analytics results** — analytics/tracking events, collector/probe
  (`_scrapers`, `collectomat`) changes, or a significant UI change (altering
  tracked elements / layout). The exact label name is `Data-issue`. Skip it for
  changes with no plausible analytics impact (pure build/tooling, docs,
  type-only cleanups).
- **title**: file-agnostic functional line (it becomes the URL slug → the
  branch stub, so no file/path names). **description**: brief — a couple of
  sentences or terse bullets; the diff is the source of truth.

Get the branch `stub` from the (new or existing) issue URL for step 4.

### 6. Verify coverage, then clean up

Prove the split is complete and non-overlapping before dropping the snapshot:

```bash
# union of all committed files must equal the original change set,
# with zero overlap between groups
git show --name-only --format="" <branch1-tip> | sort > /tmp/g1
git show --name-only --format="" <branch2-tip> | sort > /tmp/g2
comm -12 /tmp/g1 /tmp/g2     # must be EMPTY (no file in two groups)
# repeat pairwise; total file count across groups == original staged count
```

Confirm the stash contents are fully accounted for by the committed groups,
then `git stash drop` and `git checkout develop`.

### 7. Report back

Per task: Linear identifier + URL, branch name, commit subject, and the
**create-PR URL**. Summarize coverage (N files → M tasks, no overlap).

## Opening the PR (host-specific)

This repo's `origin` is **Bitbucket** (`bitbucket.org/lundegaard/sdp`), which
does **not** auto-create PRs on push and has **no `gh`**. On push, the remote
prints a ready URL — surface it verbatim:

```
remote:   https://bitbucket.org/lundegaard/sdp/pull-requests/new?source=<branch>
```

Give the user that URL per branch. Do not fabricate a different PR URL. (If a
repo ever uses GitHub with `gh` available, `gh pr create --base develop` is the
equivalent — check `git remote -v` and `which gh` first.)

## Gotchas (hard-won)

- **`pre-push` needs a clean tree.** You cannot keep other groups' changes
  loose in the working tree while pushing one branch. Snapshot (step 3) +
  per-group checkout (step 4) is what keeps each tree clean. Repeated
  `git stash pop`/`push` around each push also works but is error-prone.
- **Base on `origin/develop`, not local `develop`.** Local `develop` is often
  behind; branching off it bases your PR on stale code and can reintroduce
  already-fixed issues.
- **`yarn install` drift breaks the hook.** If the hook dies with
  `Cannot find module '<plugin>'` or a lint error in files you never touched,
  `node_modules` is out of sync with the branch's lockfile — run `yarn install`
  and retry. Pre-existing lint failures unrelated to your files usually mean a
  stale base (step 1), not your change.
- **One commit per task.** If you already made WIP commits, squash them into
  the single task commit (`git reset --soft` / amend) before pushing.
- **Existing local branch with the target name.** If `<TASK-ID>/<stub>` already
  exists locally (old attempt), inspect it (`git log origin/develop..<branch>`)
  before reusing — it may be built on a stale base (step 1). Prefer rebuilding
  fresh off `origin/develop` and keeping only genuinely-new files.

## Common mistakes

- Splitting/branching before the user confirmed the grouping.
- Running a destructive git command while work is still only in the tree/stash.
- Basing branches on stale local `develop` instead of `origin/develop`.
- Leaving other groups' files dirty in the tree, so the pre-push hook rejects.
- More than one commit per task.
- Branch name or commit not following AGENTS.md conventions (wrong stub,
  missing `TASK-ID`, wrong scope).
- Creating a new issue directly in `In Progress`, or skipping Todo → In Progress.
- Forgetting the `Data-issue` label on analytics/collector/UI-tracking changes.
- Putting a single-tenant change on team PER instead of CUS + tenant project.
- Fabricating a PR URL instead of using the one the remote printed.
- Dropping the snapshot before verifying full, non-overlapping coverage.
