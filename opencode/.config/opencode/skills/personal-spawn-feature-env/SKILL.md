---
name: personal-spawn-feature-env
description: >
  Use this skill when the user wants to spawn a new tmux session from a Linear task,
  create a dedicated git worktree with worktrunk, and optionally launch opencode to
  implement the task immediately. Trigger on requests like "spawn a tmux session for
  this Linear issue", "create a worktree from CUS-123", "start working on this ticket",
  "open this Linear task in opencode", or "make a separate feature env for this issue".
---

# Spawn Feature Env

Run `linear-session`. Do not hand-roll `tmux` + `wt` — a second implementation drifts.

```bash
linear-session [-i] [-P <preset>] [-p "<guidance>"] [-f <slug>] [-b <prefix>] [-s <session>] [-r <path>] <ISSUE-ID>
```

| flag | meaning |
| --- | --- |
| `-i`, `--implement` | launch `opencode` in the session |
| `-P`, `--project` | preset from `~/.config/linear-session/config.json` |
| `-p`, `--prompt` | extra implementation guidance |
| `-f`, `--feature-name` | override the branch/session slug |
| `-b`, `--branch-prefix` | force `feature`\|`fix`\|`chore` |
| `-s`, `--session-name` | override the tmux session name |
| `-r`, `--repo-path` | repo to run `wt` in (default: current) |

Pass the identifier only (`CUS-123`). The script fetches title, description,
labels and URL; derives the branch prefix from labels and the slug from the
issue URL; resolves branch collisions; applies preset `baseBranch`/`baseFolder`/
`subproject`; switches to an existing session instead of clobbering it; builds
the `-i` prompt from title + description; and moves the issue Todo/Backlog →
In Progress.

It attaches (or `switch-client` when already inside tmux) and exits, so it is
the last thing you run. Report the session and branch it printed.

## Rules

- Only override `-b`/`-s`/`-f` when the user explicitly asks; the derived values are canonical.
- Never move an issue to Done — the user owns that transition.
- Requires `opencode`, `tmux`, `wt`, `git`; the script checks and fails loudly.
- Source: `~/dotfiles/bin/.local/bin/linear-session`. Fix behaviour there, not here.
