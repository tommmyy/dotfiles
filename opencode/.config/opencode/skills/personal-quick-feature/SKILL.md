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
stop and tell the user there's nothing to file — don't invent a task. Read the
hunks (not just file names); they are the source for the issue title/description.

### 2. Check the base branch early

Run `git rev-parse --abbrev-ref HEAD`. Remember whether it is `develop`. If it
is **not** `develop`, warn now: the issue can still be created, but the branch
step (step 4) will be skipped.

### 3. Create the Linear issue via `personal-linear-task-intake`

Delegate issue creation to the **`personal-linear-task-intake`** skill — follow
its intake flow and field requirements; do not restate them here. This skill
only pins two fields and derives two:

- **assignee**: always `"me"`.
- **cycle**: always `"current"`.
- **title / description**: derive from the staged diff (title describes the
  change; description summarizes problem + fix and names the files touched).

So the only fields to ask the user for are the ones intake requires that can't
be derived or pinned. Capture the returned issue **identifier** and **url**.

### 4. Create the branch (only on `develop`)

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

### 5. Report back

- Issue identifier + URL.
- Branch name and whether it was created or skipped (with reason if skipped).

## Common mistakes

- Filing an issue when nothing is staged.
- Restating intake rules instead of deferring to `personal-linear-task-intake`.
- Using `gitBranchName` from Linear instead of `<IDENTIFIER>/<slug>` from the URL.
- Creating the branch when not on `develop`.
- Committing the staged changes — this workflow only stages/moves them.
