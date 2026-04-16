---
name: code-review-local
description: >
  Review local uncommitted changes with multiple review lenses.
  Use when the user asks to review local changes, review staged or unstaged work,
  run a code review before commit, or perform a multi-perspective review of the current diff.
---

# Local Code Review

Run a pragmatic, multi-perspective review of local uncommitted changes.

## Goal

Review the current worktree diff and report only meaningful findings in a code review style.
Prioritize bugs, regressions, security issues, contract risks, and missing test coverage over style nits.

## Default Scope

- Review both staged and unstaged changes.
- Ignore files under `spec/` and `reports/` unless the user explicitly asks to include them.
- Focus on changed lines first, then read surrounding code only when needed to verify impact.

## Workflow

1. Inspect the current change set.
   - Use git status and diff summary commands to understand scope.
   - If there are no local changes, tell the user and stop.

2. Gather project guidance.
   - Look for relevant `README.md`, `AGENTS.md`, `CLAUDE.md`, and `constitution.md` files.
   - Include the root `README.md` plus README files near modified files when relevant.

3. Build a concise change summary.
   - Identify changed files.
   - Note whether each file has staged changes, unstaged changes, or both.
   - Note which parts appear risky: auth, data writes, contracts, concurrency, tests, migrations, infra.

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

6. Produce a review-first result.
   - Findings come first, ordered by severity.
   - Every finding must include file path and line reference.
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
