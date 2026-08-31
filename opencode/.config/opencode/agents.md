## Images pasted into a session

A pasted image reaches you as a decoded rendering, not as a file. You cannot
reproduce its bytes, so never emit base64 for one from what you see — the
result is a redrawing, not the original.

The real bytes are in opencode's database. `oc-paste-extract` reads them out:

    oc-paste-extract --list             # recent pastes, newest first
    oc-paste-extract                    # newest -> $TMPDIR, prints sha256
    oc-paste-extract -n 2 -o bug.png    # 2nd newest -> bug.png

Use that file wherever the actual image is needed: uploading to Linear
(`prepare_attachment_upload` verifies exactly the sha256 it printed),
attaching to a PR, or diffing against a screenshot you captured yourself.

## Documentation style

1. Docs and comments describe the CURRENT state only. Never write "previously X, now Y" — history lives in git.
2. Exception: keep historical context only when it prevents a future mistake (e.g. "threshold below 10s caused frequent timeouts").
3. When updating docs, rewrite the affected section to describe the new state; don't append change notes.
