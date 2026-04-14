---
name: linear-task-intake
description: >
  Use this skill when the user asks to create a Linear task/issue/ticket (for example:
  "create a task in linear", "open a linear issue", "add a ticket in linear.app").
  Before creating the issue, ensure these required fields are present: team, project,
  title, and assignee. Ask follow-up questions only for fields the user did not provide.
---

# Linear Task Intake

## Purpose

Create Linear issues through MCP with a strict intake flow so the agent only asks for missing required fields.

## Required Fields

- `team`
- `project`
- `title`
- `assignee`
- `description`
- `cycle`

Do not create the issue until all four fields are known.

## Intake Rules

1. Parse the user's request and extract any of the required fields already present.
2. If one or more required fields are missing, ask exactly one follow-up question that lists only the missing fields.
3. Do not ask about fields that are already provided.
4. Before creating the issue, autocorrect obvious typos in user-provided text fields (especially the title and description) while preserving intent.
5. Once all required fields are available, create the issue using the Linear MCP tool.
6. Confirm success with issue identifier and URL.

## Field Mapping

- `team` -> `linear_save_issue.team`
- `project` -> `linear_save_issue.project`
- `title` -> `linear_save_issue.title`
- `assignee` -> `linear_save_issue.assignee`
- `description` -> `linear_save_issue.description`

## Follow-up Question Format

When fields are missing, ask a single concise question like:

"Got it - I can create that. Please share: <missing fields only>."

Examples:

- Missing `project` and `assignee`:
  "Got it - I can create that. Please share: project and assignee."
- Missing only `team`:
  "Got it - I can create that. Please share: team."

## Creation Step

After all required fields are present, call `linear_save_issue` with at least:

- `title`
- `team`
- `project`
- `assignee`
- `description`

Include optional fields (description, priority, labels, etc.) only when explicitly provided by the user.
**Correct obvious grammar mistakes and typos.**

## Output Format

After creating the issue, respond with:

- Issue identifier (for example `ENG-123`)
- Direct URL to the issue
- One-line confirmation of team/project/assignee used

## Common Mistakes

- Asking multiple back-and-forth questions when one consolidated missing-fields question is enough.
- Asking for a field the user already provided.
- Creating an issue before `team`, `project`, `title`, `description`, `cycle` and `assignee` are all known.
- Creating an issue without first **correcting obvious typos** in user-provided text.
