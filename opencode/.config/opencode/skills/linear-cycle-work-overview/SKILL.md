---
name: linear-cycle-work-overview
description: >
  Use this skill whenever the user asks for an overview, summary, recap, slide prep,
  retrospective input, or report of their completed work in the current Linear cycle,
  especially when they mention done tasks, current cycle, CUS, PER, PRs, pull requests,
  slide deck, HTML, PDF, Marp, or want the result saved into `private.plans/`. This skill
  verifies issues by assignee and `completedAt` window, enriches them with local git / PR
  context, and can emit both technical notes and slide-ready Markdown / Marp files.
---

# Linear Cycle Work Overview

Build an accurate current-cycle work overview for the current user across Linear teams `CUS` and `PER`, then optionally save it as Markdown and a Marp slide deck.

## Purpose

This skill exists because broad Linear list queries can be incomplete or misleading for this workflow. The safe version is:

1. identify the active cycle window for both target teams
2. verify candidate issues individually
3. filter strictly by assignee and `completedAt`
4. enrich with local git / PR history
5. present a concise work summary in the form the user wants

## Default Scope

Unless the user asks otherwise, use this exact filter:

- assignee: current Linear user (`me`)
- teams: `customer success` / `CUS` and `dev` / `PER`
- issue status: completed / done
- time filter: `completedAt` must fall inside the current cycle window of the issue's team

Do not include issues that are merely in the cycle but not completed in the active cycle window.

## Tooling

Prefer these tools:

- `linear_get_user`
- `linear_list_teams`
- `linear_list_cycles`
- `linear_get_issue`
- `linear_list_issues` only as a helper, not as the sole source of truth
- local `git` via shell for PR and merge enrichment

Do not use Playwright for this workflow unless the user explicitly asks for browser automation.

## Workflow

### 1. Resolve the user and active cycles

1. Read the current Linear user with `linear_get_user(query="me")`.
2. Resolve both target teams:
   - `customer success` / `CUS`
   - `dev` / `PER`
3. Read each team's current cycle with `linear_list_cycles(type="current")`.
4. Capture:
   - team id
   - cycle id
   - cycle number and title
   - `startsAt`
   - `endsAt`

Treat `startsAt` and `endsAt` as the canonical cycle window for filtering `completedAt`.

### 2. Gather candidate issue ids

Because the generic Linear list endpoint may miss known issues, use a layered approach.

Start with Linear queries, but do not stop there if the result looks incomplete.

Good sources for candidate ids:

- `linear_list_issues` scoped by team, assignee, project, or recent update window
- local git history in the active repository:
  - merge commits mentioning `CUS-123` / `PER-456`
  - branch names containing Linear ids
  - direct commits mentioning Linear ids

Useful shell patterns:

```bash
git log --all --oneline --decorate --extended-regexp --grep='CUS-[0-9]+|PER-[0-9]+'
git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin
```

Extract unique `CUS-*` and `PER-*` ids from those sources.

If the user names specific issues as a correction, immediately include them in the candidate set and validate them first.

### 3. Validate every candidate issue individually

For every candidate id, call `linear_get_issue` and keep it only if all are true:

- `assignee` is the current user
- `statusType` is `completed`
- `team` is `customer success` or `dev`
- `completedAt` exists
- `completedAt` falls within that team's current cycle window

Reject issues that fail any of those checks, even if they appear in git history.

This individual validation step is mandatory.

### 4. Build the verified issue set

Return a final verified set split by team:

- `CUS` issues
- `PER` issues

Sort by `completedAt` descending unless the user asks for a different ordering.

For each issue, keep:

- id
- title
- team
- project
- completedAt
- issue url
- branch name
- labels
- brief implementation note

## Git / PR Enrichment

After the verified set is known, enrich it from local git.

### What to look for

- merged PR lines like `Merged in feature/CUS-123-... (pull request #6200)`
- direct issue commits on feature/fix branches
- branch-specific changes that never produced a visible merge marker on the current branch

Useful shell patterns:

```bash
git log --all --oneline --decorate --grep='CUS-123\|PER-456'
git show --stat --format=medium <commit>
git show --unified=20 <commit> -- <path>
```

### Enrichment rules

1. Prefer merged PR numbers when visible.
2. If no merged PR is visible, fall back to local branch commit evidence.
3. Do not overclaim details when the commit title and issue title do not line up cleanly.
4. When evidence is ambiguous, describe the item as a tracking repair / rollout update / config change at a high level instead of inventing specifics.

## Output Modes

Choose based on user request.

### 1. Slide-friendly summary

Use this when the user says they will make slides or wants a presentation outline.

Structure:

- verified issue count
- high-level themes
- grouped accomplishments
- short impact statements

Keep bullets short. Focus on outcomes more than implementation detail.

### 2. Technical summary

Use this when the user wants engineering detail.

Structure:

- scope used for filtering
- verified count by team
- grouped work areas
- per-issue notes with PR references where known
- caveats / uncertainty notes

### 3. Manager-facing summary

Use this when the user wants a simpler narrative.

Structure:

- what shipped
- why it mattered
- tenant / product impact
- a few representative examples

## Saving Files

If the user asks to save the output, prefer `private.plans/` in the current repo.

### File naming

If both teams share the same visible current cycle number, use:

- `private.plans/cycle-<n>-technical-work-overview.md`
- `private.plans/cycle-<n>-technical-work-overview.marp.md`

If the cycles differ between `CUS` and `PER`, make that explicit:

- `private.plans/cus-cycle-<n>-per-cycle-<m>-technical-work-overview.md`
- `private.plans/cus-cycle-<n>-per-cycle-<m>-technical-work-overview.marp.md`

### Markdown notes file

The technical notes file should contain:

- scope used
- verified issue count
- grouped sections by theme
- per-issue notes
- PR / git references where known
- caveats

### Marp deck file

Do not save a long prose note and expect Marp to paginate it. Create a real slide deck.

Requirements:

- include Marp frontmatter
- use `---` slide separators
- keep slides short enough to fit
- prefer one theme per slide

Recommended frontmatter:

```yaml
---
marp: true
theme: default
paginate: true
size: 16:9
title: Cycle <n> Technical Work Overview
---
```

Recommended slide set:

1. title
2. delivery summary
3. completed issue list
4. tenant rollout
5. search / reco work
6. experimentation / rollout controls
7. tracking / analytics
8. shared platform work
9. key outcomes

## Accuracy Rules

- Do not trust one broad `linear_list_issues` query as the final answer if it conflicts with known issue evidence.
- If the user gives examples of missing issues, use them as a signal that the initial issue set is incomplete.
- Keep the final answer grounded in verified `linear_get_issue` results.
- Separate verified facts from inferred implementation details.
- Call out caveats when a PR title, merge marker, or commit message is inconsistent.

## Response Template

When replying in chat, prefer this shape:

### Verification

- scope used
- cycle window(s)
- verified count by team

### Overview

- high-level themes
- grouped accomplishments

### Details

- per-issue or per-theme technical notes
- PR references where available

### Files

- saved file paths, if any

## Example Triggers

- "look into my done tasks in linear in the current cycle and create me an overview"
- "summarize my CUS and PER work from this cycle"
- "prepare a slide-friendly recap of my completed Linear issues"
- "save my current cycle work overview into private.plans and make a Marp version"
- "include PR information in the cycle summary"
