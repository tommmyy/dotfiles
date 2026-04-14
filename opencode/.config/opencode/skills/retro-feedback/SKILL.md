---
name: retro-feedback
description: >
  Add retrospective feedback from a local markdown file to a Linear retrospective issue.
  Use this skill whenever the user wants to submit retro notes, add retro feedback,
  merge retrospective content into a Linear issue, or says things like
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

If the target issue is not specified, find the current one automatically:
retro issues are created every 14 days in the project
**Perselio Container - Sales/Marketing/Guidelines**
(https://linear.app/perselio/project/perselio-container-salesmarketingguidelines-662489b43a5a).
Search for the most recent issue with "Retrospective" in the title using
`list_issues` with `project: "Perselio Container - Sales/Marketing/Guidelines"`
and `query: "Retrospective"`, sorted by `createdAt`. Pick the newest one.

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

When building multi-line cell content, use `<br>` tags or newlines depending
on what the existing table already uses. Match the existing style.

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

## Common pitfalls

- **Multi-line cells in markdown tables**: Linear's markdown renderer handles
  newlines within table cells. Use the same line-break style as the existing
  content (usually literal newlines or `<br>` — check what the other rows use).
- **Preserving others' feedback**: This is critical. Always read the current
  issue state right before updating to avoid overwriting concurrent edits.
  Never modify rows that don't belong to the user.
- **Category mapping flexibility**: Users might write "Dislike" (singular) or
  "Dislikes" (plural), with or without colons. Be flexible in matching.
