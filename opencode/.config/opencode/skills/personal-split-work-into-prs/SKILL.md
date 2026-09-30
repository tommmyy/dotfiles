---
name: personal-split-work-into-prs
description: >
  Use this skill when the user has a pile of local changes (uncommitted and/or
  unpushed commits, usually hacked directly on `develop`) and wants to split
  them into several logical tasks, each shipped as its own Linear issue +
  branch + single commit + pull request. Trigger on phrases like "split my
  changes into tasks", "break this work into separate branches/PRs", "I did a
  lot of work, divide it into tickets", "one branch/PR per task from this
  diff". Multi-task sibling of `personal-quick-feature`. Also the reference for
  the multi-branch git mechanics (snapshot, clean tree for `pre-push`, push →
  PR URL, coverage check) that `personal-slack-feedback-intake` defers to.
---

# Split work into tasks → branches → PRs

Cut a working tree of mixed changes into N tasks. Each task gets its own Linear
issue and its own branch off `origin/develop`, holding exactly one commit, pushed
with a create-PR URL.

This skill owns the **grouping** and the **multi-branch git mechanics**. Issue
creation belongs to `personal-quick-feature`, and commit/branch formats to the
repo's `AGENTS.md`. Don't restate either.

## Safety rules

- Until step 6 passes, the snapshot commit is the only complete copy of the
  work. No `reset --hard`, `checkout -- .`, `clean`, `stash drop` or deleting
  the snapshot branch before then.
- Nothing gets created (issues, branches) before the user confirms the grouping.
- Branches are cut from `origin/develop`, never local `develop`.

## 1. Survey

```bash
git fetch origin
git status --short
git log --oneline origin/develop..HEAD   # unpushed commits count as work too
```

`BASE=$(git merge-base HEAD origin/develop)`. The work is everything between
`$BASE` and the working tree. If `origin/develop..HEAD` shows commits that aren't
this work (for example an old, never-pushed local `develop`), ask before
including them. Otherwise they come back as ghost changes: files `develop` has
since renamed or deleted, and work that's already merged.

## 2. Group by intent, confirm

Read the hunks, not only the file names: `git diff "$BASE"` plus the untracked files.

- One feature or fix is one group, however many files it touches.
- One file belongs to one group. If a file genuinely serves two tasks, note which
  hunks go where (step 4 handles it); prefer whole-file groups.
- Leave unrelated untracked junk (scratch files, tool output) out of every group.

Present `group → files → existing Linear issue or new` in **one** message and
wait for confirmation. Ambiguous files go in the same message.

## 3. Issues first, then snapshot

For each group without an existing issue, follow `personal-quick-feature`
steps 3–4 (intake fields, assignee/cycle pins, `Todo` → `In Progress`,
`Data-issue`, file-agnostic title), deriving everything from that group's diff
only. Skip its branch step. Record each group's `<TASK-ID>/<stub>` (the part
of the issue URL after `/issue/`).

Then freeze the work into one commit so every tree below starts clean:

```bash
git switch -c split/snapshot
git add -A -- <every path in every group>     # not junk
git commit --no-verify -m "split snapshot"    # WIP only; never pushed
```

## 4. Per group: branch → apply → commit → push

```bash
git switch -c <TASK-ID>/<stub> origin/develop
git diff "$BASE" split/snapshot -- <group paths> | git apply --3way --index
git commit -m "<TASK-ID> <type>(sa): <summary>" -m "<body>"
git push -u origin <TASK-ID>/<stub>
```

- Applying the **diff** rather than checking out whole files carries new files and
  deletions over correctly. It also keeps any changes `origin/develop` made to
  those files since `$BASE`. `--3way` turns overlaps into normal conflicts:
  resolve them, `git add`, and commit.
- Split file: write the diff to a patch, delete the hunks belonging to other
  groups, and apply the rest. The other group gets the complementary hunks.
- One commit per task, with detail in the body. Format per `AGENTS.md`.
- Before pushing, `git status --short` must show nothing tracked and dirty.
  The `pre-push` hook (`yarn lint`, `typecheck`, `build`) refuses a dirty tree.
- Branches are independent (no stacking). Their order doesn't matter.

## 5. PR URL

`origin` is Bitbucket (`bitbucket.org/lundegaard/sdp`): no PR is created on
push, and there's no `gh`. The push output prints the URL. Pass it on verbatim:

```
remote:   https://bitbucket.org/lundegaard/sdp/pull-requests/new?source=<branch>
```

Never construct one yourself. If a repo's remote is GitHub and `gh` exists,
`gh pr create --base develop` is the equivalent.

## 6. Prove coverage, then clean up

Replay every group commit onto `$BASE` in a throwaway worktree. The result must
equal the snapshot:

```bash
git worktree add --detach "$TMPDIR/split-verify" "$BASE"
git -C "$TMPDIR/split-verify" cherry-pick <tip of each group branch>...
git -C "$TMPDIR/split-verify" diff --stat split/snapshot   # must be empty
git worktree remove "$TMPDIR/split-verify"
```

- A cherry-pick conflict means two groups overlap.
- A leftover file means a group missed it.
- A leftover diff limited to lines `origin/develop` also changed is expected;
  check it by eye.

Once it's clean: `git switch develop` and `git branch -D split/snapshot`.
Local `develop` no longer holds the work; it lives on the branches now. Say so.

## 7. Report

Per task: issue ID + URL, branch, commit subject, create-PR URL. Then
coverage: N files → M tasks, verified by replay.

## When the hook fails

- `Cannot find module '<plugin>'`, or lint errors in files you never touched:
  `node_modules` doesn't match the branch's lockfile. Run `yarn install`
  and retry.
- The hook complains about unstaged changes: another group's files are in
  the tree. They belong in the snapshot, not here.
- A `<TASK-ID>/<stub>` branch already exists locally from an older attempt:
  check `git log origin/develop..<branch>` before reusing it. Usually rebuild
  it from `origin/develop`.
