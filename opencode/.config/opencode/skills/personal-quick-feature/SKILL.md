---
name: personal-quick-feature
description: >
  Use this skill when the user wants to turn currently staged git changes into a
  Linear issue and then start a feature branch for them. Trigger on phrases like
  "create a linear task based on the staged files", "make a ticket from my staged
  changes and branch off", "turn my staged diff into a linear issue + branch",
  or any request that combines inspecting staged work, opening a Linear issue,
  and starting a branch named after that issue. Always assigns the issue to the
  current user and the current cycle, and only creates the branch when on
  `develop`.
---

# Quick Feature: Staged Changes → Linear Issue → Branch

## Purpose

Capture work that is already `git add`-ed into a Linear issue, then spin up a
feature branch (named after the issue) so the staged changes move onto it. The
"I hacked something on develop, now file it and branch off" workflow.

## Workflow

### 1. Inspect staged changes

Run `git diff --staged --stat` and `git diff --staged`. If nothing is staged,
first fall back to staging everything with `git add -A`, then re-run
`git diff --staged --stat`. Only if there is still nothing to stage (clean tree)
do you stop and tell the user there's nothing to file — don't invent a task.
Read the hunks (not just file names) to understand the change — but the
description must stay brief (see step 3), not a hunk-by-hunk retelling.
While reading the hunks, also judge whether the change could significantly
affect analytics results — analytics/tracking events, changes to a
collector/probe, or a significant UI change (this feeds the `Data-issue`
label in step 3).

### 2. Check the base branch early

Run `git rev-parse --abbrev-ref HEAD`. Remember whether it is `develop`. If it
is **not** `develop`, warn now: the issue can still be created, but the branch
step (step 5) will be skipped.

### 3. Create the Linear issue via `personal-linear-task-intake`

Delegate issue creation to the **`personal-linear-task-intake`** skill — follow
its intake flow and field requirements; do not restate them here. This skill
pins three fields (assignee, cycle, state) and derives two (title, description):

- **assignee**: always `"me"`.
- **cycle**: always `"current"`.
- **state**: always **create with `"Todo"`** (never leave it on the team's
  default, e.g. Backlog).
- **title**: derive from the staged diff — one line describing the change,
  in plain functional terms. Do NOT include file or path names (e.g. write
  "Fix precart back button" not "Fix precart back button (critical.scss)") —
  the title becomes the Linear URL slug, which becomes the branch name (step 5),
  so a file name here leaks into the branch name too.
- **description**: brief and to the point. A short summary of what changed and
  why (a couple of sentences, or a few terse bullets if there are genuinely
  distinct changes). Do NOT list the files touched, do NOT restate the diff
  hunk by hunk, do NOT pad with headings for a small change. Keep it minimal;
  the diff is the source of truth for detail.
- **labels**: if the change could significantly influence analytics results —
  analytics events, changes to a collector/probe, or a significant UI change
  (e.g. altering elements that are tracked) — add the `Data-issue` label. Skip
  it for changes with no plausible analytics impact.

`team` and `project` follow intake's **Team & Project Selection** rule:
single-tenant change → team CUS + that tenant's project; general/multi-tenant
change → team PER. If the diff makes the tenant scope obvious (e.g. a
tenant-specific config/theme file, or an issue key like `CUS-722` referenced
in context), derive both without asking. Otherwise ask the user which tenant
it affects (or confirm it's general) in one consolidated question, and in
that same message present the derived **title** and **description** for
confirmation so the user can correct them in the same turn. Capture the
returned issue **identifier** and **url**.

### 4. Move the issue Todo → In Progress

VERY IMPORTANT: the issue must **first** be created in `Todo` (step 3), then
**immediately** updated to `In Progress` here. Do these as two distinct steps —
create as `Todo`, then right away flip it to `In Progress`. Do not create the
issue directly in `In Progress`, and do not skip this transition.

Call `linear_save_issue` with the captured issue `id` and `state: "In Progress"`.

### 5. Create the branch (only on `develop`)

If step 2 found the branch is `develop`, derive the branch name from the issue
URL by taking everything after `/issue/`:

**Example:**
Input URL: `https://linear.app/perselio/issue/CUS-694/gate-exponea-session-id-on-cookie-consent`
Branch name: `CUS-694/gate-exponea-session-id-on-cookie-consent`

Then run `git checkout -b <branch-name>`. Branching off `develop` carries the
staged changes onto the new branch (still staged) — do not commit unless asked.

If the current branch is **not** `develop`, skip this step and clearly report
that the branch was not created and which branch you're on.

> Prefer parsing the URL over Linear's suggested `gitBranchName` — the requested
> format is `<IDENTIFIER>/<slug>`, not `<user>/<identifier>-<slug>`.

### 6. Report back

- Issue identifier + URL.
- Branch name and whether it was created or skipped (with reason if skipped).

## Common mistakes

- Filing an issue when nothing is staged.
- Creating the issue directly in `In Progress`, or skipping the
  Todo → In Progress transition — always create as `Todo` first, then
  immediately update to `In Progress` (step 4).
- Restating intake rules instead of deferring to `personal-linear-task-intake`.
- Using `gitBranchName` from Linear instead of `<IDENTIFIER>/<slug>` from the URL.
- Letting a file/path name slip into the issue title (and thus the branch name)
  — keep titles file-agnostic, per step 3.
- Creating the branch when not on `develop`.
- Committing the staged changes — this workflow only stages/moves them.
- Bloating the description: listing touched files, retelling the diff hunk by
  hunk, or adding Problem/Fix/Files headings for a small change. Keep it brief.
- Skipping the `Data-issue` label when the diff touches analytics events, a
  collector/probe, or makes a significant UI change with tracking impact.
