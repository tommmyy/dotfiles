# OpenCode Code Review Port

This is an OpenCode-native port of the `context-engineering-kit` `code-review` plugin.

## Included

- `skills/code-review/SKILL.md`
- `skills/code-review-local/SKILL.md`
- `skills/code-review-pr/SKILL.md`
- reviewer agents in `agents/`

## Main Differences From The Claude Plugin

- OpenCode uses skill triggering rather than `/code-review:...` slash commands.
- The port is written around OpenCode tools and subagents.
- PR commenting is optional and depends on available GitHub tooling.

## Suggested Usage

- Ask for "review local changes" to trigger `code-review` in local mode.
- Ask for "review this PR" or "review branch changes" to trigger `code-review` in PR mode.

The legacy split skills are still present, but `code-review` is now the main entrypoint.

## Review Style

- Findings first
- High-signal only
- File and line references required
- No code edits unless explicitly requested
