## Images pasted into a session

A pasted image reaches you as a decoded rendering, not as a file. You cannot
reproduce its bytes, so never emit base64 for one from what you see — the
result is a redrawing, not the original.

The real bytes are in opencode's database. `oc-paste-extract` reads them out:

    oc-paste-extract --list             # recent pastes, newest first
    oc-paste-extract                    # newest -> $TMPDIR, prints sha256
    oc-paste-extract -n 2 -o bug.png    # 2nd newest -> bug.png

It only sees pastes from the session it was called in, so a screenshot
pasted into one job is never silently handed to another. If it reports
nothing found, the paste was in a different session (a parent session, say,
when you are a subagent) — `--any` searches all of them.

Use that file wherever the actual image is needed: uploading to Linear
(`prepare_attachment_upload` verifies exactly the sha256 it printed),
attaching to a PR, or diffing against a screenshot you captured yourself.

## Claude Design

Anything touching Claude Design — the words "claude design"/"claude-design", a
`claude.ai/design` URL, a design `project_id`, or any `claude-design` MCP tool —
means loading the `personal-design-handoff` skill first, before the first such
tool call. Design HTML is pipeline input, not text to read: it gets rendered and
screenshotted, never reasoned about raw.

## Picking a browser

Three Playwright MCP servers are connected. They expose the same tools under
different prefixes, and each drives its own browser — a page opened in one is
invisible to the others, so pick one at the start of a task and stay on it.

| Tools | Browser | Use it when |
| --- | --- | --- |
| `mcp_Playwright_*` | headless, blank profile per run | **default** — anything you're doing on your own |
| `mcp_Playwright-headed_*` | visible Chrome, your real profile | the user wants to watch, or the page needs you already logged in |
| `mcp_Playwright-tenant_*` | attaches to Chrome on port 9222 | the user already has that Chrome running and means *that* window |

Default to headless. Reach for the headed one only on an explicit cue —
"show me", "I want to watch it", "use my logged-in session", a page behind a
login you have no credentials for. Popping a window open unasked steals focus
from whatever the user is doing.

`playwright-headed` shares the profile directory with a normal Chrome, so it
fails to launch while one is already open on it. If that happens, ask the user
to start Chrome with `--remote-debugging-port=9222` and switch to
`mcp_Playwright-tenant_*` instead of retrying.

## When stuck

If two attempts to fix the same problem have failed, stop. A third variation
of the same theory fails the same way — the theory is what's wrong. Delegate
to the `oracle` subagent, giving it the symptom, both failed attempts, and the
relevant file paths. Apply its diagnosis instead of re-deriving your own.

The same applies before committing to an architecture decision with real
lock-in: schema shape, module boundaries, sync vs async.

## Force-pushing my own branches

Force-pushing a branch I own is pre-approved — don't ask, and don't leave a
tidy-up commit behind just to avoid it. Keep a task's work as ONE commit: when
a follow-up fix lands after the branch is already pushed, squash it into the
original and force-push rather than stacking `fixup`-style commits.

Use `--force-with-lease`, never bare `--force`, so a push that would discard
someone else's commit fails instead of silently winning. This overrides the
"do not force-push" line in repo `AGENTS.md` files, which is written for shared
branches; it does NOT extend to `develop`, `main`, or any branch someone else
is working on.

## Documentation style

1. Docs and comments describe the CURRENT state only. Never write "previously X, now Y" — history lives in git.
2. Exception: keep historical context only when it prevents a future mistake (e.g. "threshold below 10s caused frequent timeouts").
3. When updating docs, rewrite the affected section to describe the new state; don't append change notes.
