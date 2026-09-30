# Shared code for the family skills

This folder is not a skill. It has no `SKILL.md`, so OpenCode never lists or
loads it. Scripts of the family skills import it by relative path
(`../../_lib/...`).

| Module | What it does | Used by |
| --- | --- | --- |
| `gcal.mjs` | Google Calendar client for "Rodina Konrády" (service account, no deps): `listEvents`, `getEvent`, `insertEvent`, `patchEvent`, `deleteEvent`, `upsertEvent`, `eventId`, `calendarConfigured` | `home-family-calendar/scripts/cal.mjs`, `home-kids/scripts/{mealcal,judo}.mjs` |
| `dates.mjs` | Czech date/time parsing (`zitra`, `streda`, `2.10.`), ISO helpers | both skills |

Auth comes from `FAMILY_GCAL_CREDENTIALS` and `FAMILY_GCAL_CALENDAR_ID`. See
`home-family-calendar/references/setup.md`.

## Rules for automatic events

Code that writes calendar events without the user reviewing each one (for
example the daily `kids-meal-sync` or `judo.mjs verify`) must:

- tag every event with `extendedProperties.private.source = "<caller>"` and
  only list or modify events carrying its own tag;
- use stable IDs (`eventId("<caller>:<key>")`) so reruns overwrite instead of
  duplicating.

`cal.mjs list` shows these events as `auto: <source>`, and the calendar skill
never edits them by hand.
