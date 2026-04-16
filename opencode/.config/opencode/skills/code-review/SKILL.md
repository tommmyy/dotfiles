---
name: code-review
description: >
  Review local changes or pull request changes with multiple review lenses.
  Use when the user asks to review code, review local changes, review staged or unstaged work,
  review a branch or PR, or run a multi-perspective code review.
---

# Code Review

Run a pragmatic code review focused on meaningful findings.

## Goal

Review either local uncommitted changes or branch/PR changes and surface only high-value findings.

## Mode Selection

Choose the mode from user intent:

- **Local mode**: review staged and unstaged local changes.
- **PR mode**: review the current branch relative to its base branch.

If the user clearly says PR, branch, merge request, or compare-to-base review, use PR mode.
Otherwise default to local mode.

## Default Scope

- Ignore files under `spec/` and `reports/` unless the user explicitly asks to include them.
- Focus on changed lines first, then read surrounding code only when needed to verify impact.

## Workflow

1. Determine review scope.
   - Local mode:
     - inspect git status and diff summaries for both staged and unstaged changes
     - stop and tell the user if there are no local changes
   - PR mode:
     - inspect branch name, recent commits, and diff summary against the base branch
     - use the repo's obvious default branch when available; otherwise prefer `main`, then `master`, then ask

2. Gather project guidance.
   - Look for relevant `README.md`, `AGENTS.md`, `CLAUDE.md`, and `constitution.md` files.
   - Include the root `README.md` plus README files near modified files when relevant.

3. Summarize the change set.
   - Identify changed files.
   - In local mode, note whether each file has staged changes, unstaged changes, or both.
   - Note risky areas: auth, data writes, contracts, concurrency, tests, migrations, infra.

4. Run multiple review lenses in parallel.
   - Use parallel `task` calls when appropriate.
   - Prefer these lenses:
     - bug-hunter
     - security-auditor
     - code-quality-reviewer
     - contracts-reviewer when APIs, types, schemas, or data models changed
     - test-coverage-reviewer when code or tests changed
     - historical-context-reviewer for higher-complexity or high-risk changes
   - If custom agents are not directly invocable, emulate each lens by using `task` with the `review` or `general` subagent and a prompt that applies that lens explicitly.

5. Filter findings aggressively.
   - Report only issues a senior engineer would actually want called out.
   - Exclude pure formatting, linter-only issues, speculative concerns, and likely intentional behavior changes unless there is clear risk.
   - Prefer medium-and-up severity by default unless the user asks for exhaustive output.

6. Deliver the review.
   - Findings come first, ordered by severity.
   - Every finding must include file path and line reference.
   - In PR mode, if the user explicitly asked to comment on GitHub, use available GitHub tooling.
   - If GitHub commenting was requested but tooling is unavailable, provide ready-to-post comment text instead.
   - If no meaningful findings remain after filtering, say so explicitly.

## Output Format

Use this structure:

```markdown
[findings first]

- High: `path/to/file:12-24` - concise explanation of the concrete risk and likely consequence.
- Medium: `path/to/file:45-52` - concise explanation.

[if needed]
Open questions

- Question or assumption that affects confidence.

[optional]
Change summary

- Brief summary of what changed.
```

## Review Lens Guidance

### Bug Hunter

Look for logic errors, edge cases, bad state transitions, missing error handling, race conditions, and silent failures.

### Security Auditor

Look for authz/authn issues, injection risks, unsafe shell or file handling, secrets exposure, insecure defaults, and data leakage.

### Code Quality Reviewer

Look for unnecessary complexity, poor cohesion, misleading naming, duplication, and maintainability issues that create real risk.

### Contracts Reviewer

Look for breaking API changes, weak validation at boundaries, invalid states, schema drift, and unsafe type changes.

### Test Coverage Reviewer

Look for missing regression tests, missing edge-case tests, and changes that materially alter behavior without corresponding coverage.

### Historical Context Reviewer

Use git history only when it materially improves confidence, such as hotspots, recurring regressions, or code paths with prior fixes.

## Important Notes

- Do not make code changes unless the user asks for fixes.
- Use a code review mindset: findings first, brief summary second.
- Be explicit when something is a risk versus a certainty.
- When the diff is large, focus on the highest-risk files and skip low-value commentary.
