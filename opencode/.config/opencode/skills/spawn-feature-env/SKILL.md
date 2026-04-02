---
name: spawn-feature-env
description: >
  Use this skill when the user wants to spawn a new tmux session from a Linear task,
  create a dedicated git worktree with worktrunk, and optionally launch opencode to
  implement the task immediately. Trigger on requests like "spawn a tmux session for
  this Linear issue", "create a worktree from CUS-123", "start working on this ticket",
  "open this Linear task in opencode", or "make a separate feature env for this issue".
---

# Spawn Feature Env

## Purpose

Create an isolated feature environment from a Linear issue by deriving a branch name,
spawning a detached tmux session, switching or creating a `wt` worktree, and optionally
starting `opencode` with a prompt built from the issue details.

## Dependencies

Required CLIs:

```bash
which tmux
which wt
which git
which opencode
```

Linear access is required when the user provides a Linear issue URL or identifier.

## Inputs

- `issue`: Linear issue identifier or URL, for example `CUS-123` or `https://linear.app/.../issue/CUS-123/...`
- `repo_path`: repository path to run `wt` in; default to the current repository
- `implement`: boolean; when true, launch `opencode` inside the new worktree
- `branch_prefix`: optional; default to `feature`. Use `fix` only when the user explicitly asks or the issue is clearly a bugfix.
- `session_name`: optional override for the tmux session name
- `extra_prompt`: optional extra implementation guidance from the user

## Steps

### 1. Load the Linear issue

If the user gave a Linear URL or issue id, fetch the issue first. Extract:

- identifier, for example `CUS-123`
- title
- description
- project, team, labels, and acceptance criteria when useful

Do not ask the user to restate the issue if Linear already has the information.

### 2. Derive branch and session names

Build a branch slug from the issue title:

- lowercase
- replace non-alphanumeric runs with `-`
- trim leading and trailing `-`
- keep it short and readable

Branch format:

```text
<branch_prefix>/<IDENTIFIER>-<slug>
```

Required branch naming:

- `feature/CUS-1-short-description`
- `fix/CUS-1-short-description`
- `chore/CUS-1-short-description`

Rules:

- `<IDENTIFIER>` must be the Linear issue id exactly, for example `CUS-1` or `PER-12`
- `<branch_prefix>` must be one of `feature`, `fix`, or `chore`
- infer `<branch_prefix>` from the Linear issue type first
- map Linear bug / fix / defect style issues to `fix`
- map Linear chore / maintenance / refactor / tooling / tech-debt style issues to `chore`
- map all other product or delivery work to `feature`
- only override the inferred prefix when the user explicitly asks for a different one
- `<slug>` should be a short kebab-case summary from the issue title

Examples:

- `feature/CUS-123-fix-login-timeout`
- `fix/PER-12-handle-empty-response`
- `chore/CUS-44-update-rspack-config`

When Linear does not expose a reliable task type field, infer from the issue title, labels, and description using the same mapping.

tmux session name must not contain `/`, so use:

```text
<identifier-lowercase>-<slug>
```

Examples:

- `cus-123-fix-login-timeout`
- `per-12-handle-empty-response`

If the session already exists, do not overwrite it silently. Ask whether to reuse it or create a different session name.

### 3. Build the opencode prompt when implementation is requested

If `implement` is true, compose a compact prompt from the Linear issue:

```text
Implement Linear issue <IDENTIFIER>.

Title: <title>

Description:
<description>

Additional guidance:
<extra_prompt>
```

Keep the prompt direct. Include acceptance criteria or constraints when present. Do not add unrelated planning instructions.

### 4. Spawn the tmux session

Run the `wt` command from the target repository.

Without implementation:

```bash
tmux new-session -d -s "$SESSION" "wt switch --create \"$BRANCH\""
```

With implementation in opencode:

```bash
tmux new-session -d -s "$SESSION" "wt switch --create \"$BRANCH\" -x 'opencode --prompt' -- $(printf '%q' "$PROMPT")"
```

If the branch already exists and the user did not ask to create from scratch, use `wt switch` without `--create`.

### 5. Report the result

After spawning the session, tell the user:

- tmux session name
- branch name
- whether `opencode` was launched
- how to attach to the session

Use:

```bash
tmux attach -t <session-name>
```

If the caller explicitly asks for machine-readable output, return only compact JSON with the requested fields and no surrounding prose.

## Common Mistakes

- Do not put `/` in the tmux session name. Use the branch only for git; sanitize the session separately.
- Do not invent issue details when a Linear id or URL is available. Fetch the issue first.
- Do not use `--create` when the branch already exists unless the user explicitly wants a fresh branch attempt.
- Do not launch `opencode run` for an interactive coding session; use `opencode --prompt` when the user wants the agent to continue working inside tmux.
- Do not pass raw multiline prompts into tmux without shell escaping; use `printf '%q'` when embedding the prompt into the command string.

## Complete Working Example

Use this pattern when the user asks to start working on a Linear issue immediately:

```bash
ISSUE_ID="CUS-123"
TITLE="Fix login timeout"
SLUG="fix-login-timeout"
BRANCH="feature/${ISSUE_ID}-${SLUG}"
SESSION="cus-123-fix-login-timeout"
PROMPT="Implement Linear issue CUS-123.

Title: Fix login timeout

Description:
The login session expires after 5 minutes. Find the session timeout config and extend it to 24 hours."

tmux new-session -d -s "$SESSION" "wt switch --create \"$BRANCH\" -x 'opencode --prompt' -- $(printf '%q' "$PROMPT")"
```

Use this pattern when the user only wants the environment prepared:

```bash
ISSUE_ID="CUS-123"
SLUG="fix-login-timeout"
BRANCH="feature/${ISSUE_ID}-${SLUG}"
SESSION="cus-123-fix-login-timeout"

tmux new-session -d -s "$SESSION" "wt switch --create \"$BRANCH\""
```

## Notes / Edge Cases

- `wt switch -x ...` runs the execute command inside the target worktree, so do not add a separate `cd`.
- If the user provides a repo path outside the current repository, run the `tmux new-session` command from that repo.
- Prefer the branch prefix inferred from the Linear issue type over manual defaults.
