# bin

Personal scripts, stowed into `~/.local/bin`.

---

# linear-workmux

Turns Linear issues into [workmux](https://github.com/raine/workmux) jobs, and
tells you which of those jobs are waiting on you.

It is **not** a replacement for `linear-session`. The two coexist:

| | creates | worktree | tmux |
| --- | --- | --- | --- |
| `linear-session` | `wt` worktree + session, optionally runs opencode | repo's own worktree dir | `<repo>@<branch>` |
| `linear-workmux` | workmux job | `<repo>__worktrees/` | `wm-`-prefixed session |

Both show up in `workmux status`, because workmux tracks *any opencode process
in a pane*, not only worktrees it created.

## The three pieces

- **workmux** owns worktrees, tmux sessions, and agent status. This is the manager.
- **`linear-workmux`** is the Linear glue only: issues in, cleanup out.
- **`personal-slack-feedback-intake`** (opencode skill) is the front of the pipe:
  Slack thread → Linear child issues.

## Division of labour with worktrunk (`wt`)

`wt` is **not** obsolete — it is load-bearing. Every workmux job's dependency
setup *is* worktrunk config (`post_create` calls `wt hook pre-start`), so
removing `wt` breaks every spawn. The two tools are complementary; they overlap
only on worktree lifecycle.

| | worktrunk (`wt`) | workmux |
| --- | --- | --- |
| Hooks engine: templating, approvals, subproject gating | yes — the whole `pre-start` / `pre-remove` system | plain shell commands only |
| The measured sdp setup (clonefile, install-state, `.env`, husky) | yes, ~150 tuned lines | no |
| Git workflow: `merge`, `step commit/squash/rebase/push`, LLM commit messages | yes | `merge` only |
| `step copy-ignored / promote / prune / for-each / relocate` | yes | no |
| **Agent status** (waiting / working / done) | **no** | yes — the reason it was adopted |
| Dashboard, sidebar, pane layouts, prompt injection | no | yes |

Dropping `wt` would mean re-implementing that setup in `.workmux.yaml` while
losing templating, approvals and subproject gating. Dropping workmux would mean
losing the status manager. Keep both.

### Ownership rule

Both tools see the same git worktrees (`wt list` shows workmux's, and
`workmux status` tracks any opencode process in a pane, including `wt` ones).
Only the paths disambiguate them:

| Created by | Directory | tmux session | Remove with |
| --- | --- | --- | --- |
| `linear-session` → `wt` | `sdp.feature-*` | `<repo>@<branch>` | `wt remove` |
| `linear-workmux` → workmux | `sdp__worktrees/*` | glyph/`wm-` prefixed | `workmux remove` |

**Whoever created a worktree removes it.** Removing a workmux worktree with
`wt remove` takes the directory but orphans the tmux session and the status file
in `~/.local/state/workmux/agents/`.

This is enforced, not just documented. `wt step prune` has no exclude flag, so a
`guard_workmux_owned` hook is declared **first** in worktrunk's `pre-remove`
section; a non-zero pre-remove aborts the removal:

```
$ wt remove TEST-guard
wt: refusing to remove /Users/tommmyy/workspaces/sdp__worktrees/test-guard
wt: that worktree belongs to workmux; ...
✗ pre-remove command failed: guard_workmux_owned: exit status: 1
```

The guard exits early when `WM_WORKTREE_PATH` is set — that variable is only
present when workmux itself is calling `wt hook pre-remove`, so `workmux remove`
still reuses worktrunk's cleanup hooks instead of deadlocking against the guard.
`wt --no-verify` bypasses it if you ever really mean it.

## Prerequisites

```sh
brew install raine/workmux/workmux
workmux setup --hooks      # installs ~/.config/opencode/plugins/workmux-status.ts
```

`setup` also offers to hook Claude Code and Codex — decline those if you only
want opencode. The plugin loads at opencode startup, so restart any running
session before expecting status from it.

Linear is queried by shelling out to `opencode run` with the Linear MCP (the
same trick `linear-session` uses), so no separate API token is needed.

## A day

**1. See what's ready**

```sh
linear-workmux list
[   ] CUS-701    Widen mobile carousel side peek on DTR
[job] CUS-1038   Show the assistant on search results pages
```

`[job]` = already has a session or worktree. `[   ]` = not started.

**2. Start one**

```sh
linear-workmux spawn CUS-701
```

Creates the worktree, symlinks `node_modules`, opens a tmux session, launches
opencode with the issue text plus the repo's rules as its prompt, and moves the
issue to In Progress. Runs in the background — your current session is not
disturbed.

**3. Go do something else.** The agent works.

**4. Check who needs you**

```sh
workmux dashboard          # full TUI: status, live preview, diff, PR
linear-workmux status      # headless, waiting-first, prints a jump command
```

In the dashboard: `Enter` jumps, `p` peeks without leaving, `i` types a reply
in place, `d` diff, `o` open PR.

**5. Answer a waiting agent.** `Enter` in the dashboard drops you into the real
opencode TUI. Answer, then leave (`prefix d`). Status returns to working by
itself.

**6. When it's done** it pushes and prints the Bitbucket create-PR URL. Merge in
the browser.

**7. Clean up**

```sh
linear-workmux reap
```

Removes worktree + branch + session for every branch already merged into
`origin/develop`. Only touches `<repo>__worktrees/`, so `wt` worktrees from
`linear-session` are never harmed — they appear in `status` but are not reaped.

## Commands

```
linear-workmux status              agents, waiting first
linear-workmux list                Linear issues eligible to become jobs
linear-workmux spawn <ID> [ID...]  one job per issue, branch <ID>/<slug>
linear-workmux auto                spawn every eligible issue with no job yet
linear-workmux reap                remove jobs whose branch is merged

-P, --project <name> project preset (default sdp)
-r, --repo <path>    override the preset's repository path
-n, --dry-run        print what would happen, change nothing
-s, --state <name>   Linear state to pull (default Todo)
    --no-progress    do not move spawned issues to In Progress
```

## Project presets

Presets are read from **`linear-session`'s** config
(`~/.config/linear-session/config.json`) so the two tools cannot disagree about
where a project lives. A `~/.config/linear-workmux/config.json` of the same
shape takes precedence if you ever need them to differ.

```json
{
  "projects": {
    "sdp":     { "repoPath": "~/workspaces/sdp", "baseBranch": "develop",
                 "baseFolder": "s-analytics/sources", "subproject": "sdp" },
    "console": { "repoPath": "~/workspaces/sdp", "baseBranch": "develop",
                 "baseFolder": "perselio-console", "subproject": "console" }
  }
}
```

| key | effect in `linear-workmux` |
| --- | --- |
| `repoPath` | where the worktree is created |
| `baseBranch` | passed as `workmux add --base` |
| `baseFolder` | `workmux add` runs from there, so its **nested `.workmux.yaml`** is used and the tmux window opens in that subdirectory inside the worktree |
| `subproject` | exported as `WT_SUBPROJECT`, selecting which worktrunk setup hooks run |

`baseFolder` is how the polyglot repo root is avoided — see below.

Branch names follow the repo convention `{TASK-ID}/{stub}`, with the stub copied
verbatim from the Linear issue URL. `--name <TASK-ID>` is passed automatically so
the session is `wm-cus-1038` rather than a 60-character slug.

## Gotchas

These cost real debugging time; they are not hypothetical.

**Target sessions by `session_id`, never by name.** With `nerdfont: true`,
workmux puts a private-use glyph *inside* the session name (`"\uE418 per-1069"`),
so `switch-client -t <name>` is unpastable and may not resolve. `status`
resolves `pane_id → session_id` for this reason.

**The workmux sidebar is a tmux pane, and it holds focus after switching.** So
`new-window -c "#{pane_current_path}"` inherits the *sidebar's* cwd (wherever
`workmux sidebar on` was started, usually `~`) instead of the worktree. Fixed in
`tmux/.tmux.conf` with:

```tmux
set -g @cwd_path '#{?#{==:#{pane_current_command},workmux},#{session_path},#{pane_current_path}}'
bind c new-window -c "#{E:@cwd_path}"
```

`#{E:...}` is required — tmux 3.4 does not expand a user option recursively, and
fails silently by returning the literal format string.

**One pane = one agent.** Status state lives in
`~/.local/state/workmux/agents/tmux__<instance>__%<pane_id>.json`, but the tmux
icon is written per *window* (`set-window-status`). Consequences:

- separate sessions or separate windows → fully independent, fine
- two agents in one window → dashboard is correct, the window icon is shared
- switching opencode sessions inside one pane with `ctrl+x l` → **broken**

The last one is an upstream bug: the plugin unions the status of every session
the process has ever seen and only forgets one on `session.deleted`, so a
session left on a question pins the pane to `waiting` forever. opencode emits
`tui.session.select` (with `properties.sessionID`), which the plugin ignores.
Give each agent its own window until that is fixed upstream.

**Never let workmux set up `node_modules` itself — delegate to worktrunk.**
This was got wrong first time and is worth spelling out. The naive
`files.symlink: [node_modules]` + `post_create: yarn install` is broken three
ways:

- a **symlink shares one mutable `node_modules` across every worktree** — Yarn 3
  plus two concurrent agents is corruption waiting to happen;
- `yarn install` at the repo root hits **Yarn 1** (the root is polyglot
  Java/Maven/Python) and reports `Already up-to-date` in 0.04s while the real
  workspace stays uninstalled — the symptom was a worktree with no `jest` binary;
- it silently skips `.yarn/install-state.gz` and the `.env*` files.

worktrunk already solves this properly in `~/.config/worktrunk/config.toml`:
APFS `clonefile(2)` on `node_modules` (~3.8s + 10.9s install vs **2m01s** cold),
`install-state.gz` carried across, `.env` / `.env.development` / `.env_test`
copied, then `yarn install && yarn setup-development-husky && yarn
prepare-workspace` in the right directory — all gated on `WT_SUBPROJECT` /
`.wtconfig`.

So both configs just call it:

```yaml
post_create:
  - WT_SUBPROJECT=sdp wt hook pre-start -C "$WM_WORKTREE_PATH"
pre_remove:
  - WT_SUBPROJECT=sdp wt hook pre-remove -C "$WM_WORKTREE_PATH" || true
```

`wt hook <stage> -C <path>` runs worktrunk's hooks on demand, outside a
`wt switch`, which is what makes the reuse possible.

Two config files, both kept out of git via `.git/info/exclude` (they impose a
tool choice on the whole team):

- `sdp/.workmux.yaml` — root fallback; delegates to `wt hook` with no
  `WT_SUBPROJECT`, so `.wtconfig` decides.
- `sdp/s-analytics/sources/.workmux.yaml` — the `sdp` subproject. **Nested
  configs replace the root entirely and make the tmux window open in that
  subdirectory**, which is the `baseFolder` behaviour.

`perselio-console` has no nested config yet, so a console job falls back to the
root one and its window opens at the repo root; `WT_SUBPROJECT=console` is still
exported, so its hooks do run.

**Issue descriptions contain fenced code blocks.** Do not extract JSON by
matching the first ``` fence in a model response — it will grab the issue's own
code sample. `parseJsonBlob` tries a direct parse, then a whole-response fence
strip, then a string-aware balanced-brace scan.

**Handles are lowercased.** `--name TEST-HOOK` produces the handle `test-hook`,
and `workmux remove TEST-HOOK` fails with "Worktree not found". `linear-workmux`
lowercases in `existingHandles` and derives handles from directory names in
`reap`, so both are safe — but typing an issue key by hand will bite.

**workmux knows nothing about worktrunk.** The two meet at one shell command and
one environment variable: `post_create` runs an arbitrary command, workmux
exports `WM_WORKTREE_PATH`, and `wt hook <stage> -C <path>` is a public entry
point that resolves its templates from git. Since workmux uses plain
`git worktree add`, worktrunk sees an ordinary worktree regardless of who made
it. There is no integration to break — and no integration to rely on either.

**Be prescriptive with the metadata model.** An open-ended Linear query
("issues in the current cycle, excluding containers") made the fast model give
up and return `[]` while 25 issues existed — a silent wrong answer, the worst
failure mode for a poller. Name the tool and its arguments explicitly.

## Not done

No unattended polling. `spawn` and `reap` are run by hand on purpose: an
automated `auto` on a timer would spawn agents while you sleep, and that is only
worth enabling once the manual loop has proven itself.

---

# worklog-standup / worklog-cycle

Two scheduled report jobs over `~/workspaces/sdp/s-analytics/sources`. Both are
read-only: they run an opencode skill headlessly and drop Markdown in
`~/worklog/`. Neither writes to the repo — a report committed into the working
tree would show up as uncommitted work in the next stand-up.

| | schedule | skill | output |
| --- | --- | --- | --- |
| `worklog-standup` | Mon–Fri 13:00 | `personal-daily-standup` | `~/worklog/standup/YYYY-MM-DD.md` |
| `worklog-cycle` | Wed 12:30, cycle-end only | `personal-linear-cycle-work-overview` | `~/worklog/cycles/<cycle>-<date>.md` |

Both notify on completion and on failure. Logs (trimmed to the last 3000 lines)
are in `~/worklog/.log/`.

```sh
worklog-standup --print          # run now, echo the note
worklog-cycle --dry-run --force  # list the issues the summary would cover
worklog-cycle --marp             # also emit a slide deck
```

Scheduling lives in the `launchd` stow package. `launchctl kickstart -p
gui/$(id -u)/com.tommmyy.worklog-standup` runs a job in launchd's own
environment, which is the only way to catch the failures that matter.

## Why they are shaped this way

**launchd, not cron.** A calendar job that came due while the Mac was asleep is
re-fired on wake; cron simply drops it. A 13:00 job on a laptop needs that.

**launchd hands a job almost nothing.** No shell rc files, and `PATH` is
`/usr/bin:/bin:/usr/sbin:/sbin` — no `opencode`, `node` or `jq`. Everything is
re-established in `lib/worklog-schedule.sh`, which is why both scripts source it
before doing anything else.

**`.zsh_secrets` is parsed, not sourced.** It allocates descriptors with
`exec {var}<` (bash 4+ syntax; launchd gives you /bin/bash 3.2) and reads the
login keychain, which a background agent should not touch. `wl_load_secret`
lifts the one `export LINEAR_READ_KEY=` line it needs, and an already-exported
value wins so interactive runs behave normally.

**MCP servers are disabled for these runs.** Injected via
`OPENCODE_CONFIG_CONTENT`, the same lever `worklog --enrich` uses. Several MCPs
shell out to `npx -y` on a cold cache, and the Linear one wants a browser once
its OAuth token lapses — every one of those is a way for an unattended job to
hang. Facts come from git and from the Linear REST call the job makes itself.

**The result is read from a file, never from stdout.** The transcript carries
banners, tool traces and reasoning; scraping prose out of it is how a job starts
producing quiet garbage. The prompt names an output path, and the run fails if
that file is missing or empty.

## Gotchas

**Biweekly is not expressible in launchd**, so `worklog-cycle` fires every
Wednesday and asks Linear whether a cycle actually ended in the last 30 hours,
exiting silently otherwise. Self-correcting if the cycle schedule ever shifts,
unlike a hardcoded 14-day anchor.

**On a cycle-end Wednesday, `activeCycle` is the wrong cycle.** Cycles roll over
at Wednesday 00:00 local (`endsAt` is 22:00Z the previous day), so by 12:30 the
active cycle is the fresh one with half a day in it. The skill's default
`linear_list_cycles(type="current")` would summarize twelve hours instead of two
weeks. The script resolves the *most recently ended* cycle and passes that
window to the agent explicitly.

**The cycle job resolves and verifies issues itself**, in one filtered GraphQL
call — Linear applies the assignee and `completedAt` filters server-side, so
steps 1–3 of the skill (gather candidates, then validate each individually)
collapse into something both faster and exact. The agent only enriches from git
and writes prose. This is the same split as `worklog --enrich`: the LLM
summarizes, it never fetches.

**Monday's stand-up window reaches back to Friday noon**, not Sunday noon.
The skill's window is "previous day's lunch → now"; taken literally on a Monday
it silently drops every Friday afternoon, which no stand-up would ever report.

**A watchdog must not hold the caller's stdout.** The timeout helper counts in
one-second steps with its stdio redirected to `/dev/null`. A single long `sleep`
survives the kill that ends its subshell, and the orphan keeps the pipe open —
the job finishes in a minute and anything reading its output blocks for the full
timeout anyway.

**Log trimming truncates the inode, never replaces the file.** launchd holds an
open descriptor on `StandardOutPath`; writing a fresh file would send the rest
of the run into the unlinked old one.
