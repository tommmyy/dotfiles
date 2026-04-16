---
name: code-review-pr
description: >
  Review a pull request with multiple review lenses.
  Use when the user asks to review a PR, review branch changes against main,
  or perform a multi-perspective code review for an open pull request.
---

# Pull Request Review

Run a pragmatic PR review focused on real findings.

## Goal

Review all changes in the current branch relative to its base and surface only high-value findings.

## Default Behavior

- Review the full branch diff against the base branch, not just the latest commit.
- Ignore files under `spec/` and `reports/` unless the user explicitly asks to include them.
- Prefer reviewing the checked-out branch locally.

## Workflow

1. Determine scope.
   - Inspect git status, branch name, recent commits, and diff summary against the base branch.
   - Use the repository's default base branch if obvious; otherwise prefer `main`, then `master`, then ask.

2. Gather project guidance.
   - Read relevant `README.md`, `AGENTS.md`, `CLAUDE.md`, and `constitution.md` files.

3. Summarize the branch.
   - Identify major behavioral changes, risky files, tests, contracts, and infrastructure changes.

4. Run multiple review lenses in parallel.
   - Use the same lenses as the local review skill.
   - If custom agents are not directly invocable, emulate each lens through `task` prompts.

5. Filter findings.
   - Report only issues tied to changed lines or behavior introduced by the PR.
   - Exclude low-confidence and low-impact issues.

6. Deliver the review.
   - If the user asked for a written review, return findings in-chat.
   - If the user explicitly asked to comment on GitHub, use the available GitHub tooling.
   - If inline PR comments are requested but GitHub CLI or equivalent tooling is unavailable, say so clearly and provide the comments in a ready-to-post format.

## Output Format

Use this structure unless the user requested GitHub comments:

```markdown
[findings first]

- High: `path/to/file:12-24` - concise explanation of the concrete risk and likely consequence.
- Medium: `path/to/file:45-52` - concise explanation.

[if needed]
Open questions

- Question or assumption that affects confidence.

[optional]
Change summary

- Brief summary of the branch.
```

## Comment Format

When producing inline-comment-ready text, use:

```markdown
High: [brief title]

`path/to/file:12-24`

[evidence and likely consequence]
```

Keep comments brief and specific.

## Important Notes

- Do not post PR comments unless the user asked for that outcome.
- Do not review unchanged legacy issues unless the PR clearly makes them relevant.
- Prefer precision over coverage; a few strong findings are better than many weak ones.
