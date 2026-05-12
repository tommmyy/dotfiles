---
name: retro-feedback
description: >
  Add retrospective feedback from a local markdown file to a Linear retrospective issue.
  Use this skill whenever the user wants to submit retro notes, add retro feedback,
  merge retrospective content into a Linear issue, find the matching retrospective
  Linear task for today, or says things like
  "add this to the retro", "put my retro feedback into CUS-xxx",
  "merge my retro notes into Linear", "add retro from file to issue".
  Also trigger when the user references a local retro markdown file
  together with a Linear issue identifier (e.g. CUS-283).
---

# Retro Feedback

Merge a user's retrospective feedback from a local markdown note into a Linear
retrospective issue that uses a markdown table format.

## Context

The team runs retrospectives where each member fills in their feedback into a
shared Linear issue. The issue description contains a markdown table with columns
like Likes, Dislikes, Improvements, Praises, and Who. Each team member has a row
identified by their Linear `@username` in the Who column.

The user keeps their retro notes locally (e.g. in an Obsidian vault) using a
simple markdown structure with category headings and bullet points.

## Workflow

### 1. Identify inputs

You need two things from the user:

- **Source**: A local markdown file path (and optionally line range). This
  contains the user's retro feedback organized under headings like
  `Praises:`, `Dislike`, `Improvements:`, `Like:`, etc.
- **Target**: A Linear issue identifier (e.g. `CUS-283`).

If the target issue is not specified, find the current one automatically.
Retro issues are created every 14 days in the project
**Perselio Container - Sales/Marketing/Guidelines**
(https://linear.app/perselio/project/perselio-container-salesmarketingguidelines-662489b43a5a).
Search for issues with "Retrospective" in the title using `list_issues` with
`project: "Perselio Container - Sales/Marketing/Guidelines"` and
`query: "Retrospective"`, sorted by `createdAt`.

Use the current date to pick the corresponding issue:

- Prefer an issue whose title or description clearly indicates a date or date
  range covering today.
- If multiple issues match, pick the newest matching one.
- If no issue clearly maps to today, fall back to the newest retrospective
  issue and tell the user you used that fallback.

The source file path and line range are always required from the user — ask
if not provided. Do not guess or search for the file.

### 2. Read the local file

Read the specified file (and line range if given). Parse the content by
category headings. The headings may vary in style — look for keywords:

| Keyword pattern       | Maps to table column |
| --------------------- | -------------------- |
| like / likes          | Likes                |
| dislike / dislikes    | Dislikes             |
| improvement(s)        | Improvements         |
| praise(s)             | Praises              |

Collect all bullet points under each heading. Strip leading `- ` markers.

### 3. Read the Linear issue

Fetch the issue using `get_issue`. The description will contain a markdown
table. Parse the table to understand:

- The column names (first row)
- Which row belongs to which team member (Who column)
- What content already exists in each cell

### 4. Determine which row to update

The user's row is typically identified by their Linear `@username` in the Who
column. If the user hasn't told you which row is theirs, look for the row
that has empty cells (the one waiting for their input). If ambiguous, ask.

### 5. Merge the content

For each category from the local file, place the content into the matching
column of the user's row. Preserve the exact content from all other rows —
do not modify anyone else's feedback.

**Cell formatting — separating multiple items within a table cell:**

Use `<br>` (with NO trailing space) to separate items on individual lines
within a cell. For example:

```
| item one<br>item two<br>item three | ... |
```

CRITICAL rules for table cell formatting:
- **NEVER use literal newlines** inside a table row. A newline breaks the
  markdown row boundary and will corrupt the entire table.
- **NEVER use markdown list syntax** (`- item` or `* item`) inside cells.
  Linear converts `-` to `*` and only renders the first line as a bullet;
  the rest appear as plain text with a hyphen prefix.
- **Use `<br>` WITHOUT a trailing space** to avoid an extra leading space
  on each new line in Linear's renderer. Write `item one<br>item two`,
  NOT `item one <br> item two`.
- The Linear API may store `<br>` as `&#10;` — this is expected and renders
  as line breaks in the UI.
- If the user prefers a single-line format, use `·` (middle dot) as a
  separator: `item one · item two · item three`. This is a proven safe
  format used in previous retros.

Important considerations:
- The column names in the table may not match the headings in the local file
  exactly. Use the keyword mapping above to find the right column.
- If a column already has content in the user's row, append rather than
  overwrite (unless it's clearly empty/placeholder).
- If the local file has a category that doesn't map to any table column,
  mention it to the user and ask where to put it.

### 6. Update the issue

Use `save_issue` with the updated description. Make sure the entire table
is well-formed markdown. After updating, confirm to the user what was added
and link to the issue.

### 6.1 Ask the user which row is theirs

The user is `@tomas.konrady`. If you are unsure, ask — but default to this
username unless told otherwise.

## Common pitfalls

- **NEVER use literal newlines inside a table row**. This is the #1 cause of
  table corruption. A single newline inside `| ... |` splits the row and
  destroys the table structure. Always keep each row on a single line and use
  `<br>` for in-cell line breaks.
- **NEVER use markdown list syntax (`- ` or `* `) inside table cells**. It
  does not render correctly — only the first item becomes a bullet, the rest
  are plain text.
- **`<br>` spacing matters**: Use `item<br>item`, NOT `item <br> item`. The
  trailing space before `<br>` is fine, but a space after `<br>` adds a
  visible leading space on the next line in Linear.
- **Preserving others' feedback**: This is critical. Always read the current
  issue state right before updating to avoid overwriting concurrent edits.
  Never modify rows that don't belong to the user. If the table has been
  edited by others since the last fetch, re-fetch before writing.
- **Category mapping flexibility**: Users might write "Dislike" (singular) or
  "Dislikes" (plural), with or without colons. Be flexible in matching.
- **Table corruption recovery**: If a bad update corrupts the table (e.g.
  hundreds of empty columns appear), you must rebuild the table from scratch.
  Re-fetch the issue, identify the intended structure, and rewrite the entire
  description cleanly.
