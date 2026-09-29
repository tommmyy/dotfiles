---
name: personal-family-calendar
description: >
  Read and edit the Konrády family Google Calendar "Rodina Konrády". Use this
  skill whenever the user asks what's on the family calendar or wants to
  add, move, change, or delete a family event. Trigger on things like "co
  máme v sobotu", "co je tento týden v kalendáři", "kdy je zubař", "přidej do
  kalendáře", "zapiš do rodinného kalendáře", "přesuň schůzku", "smaž
  událost", "máme něco ve čtvrtek odpoledne", "rodinný kalendář", "Rodina
  Konrády", and the same in English (family calendar, add an event, what's
  on this weekend). Other skills (personal-kids) use its library for
  automatic events; that path does not go through this workflow.
---

# Family calendar: Rodina Konrády

A Google service account (`kids-calendar@temposheets.iam.gserviceaccount.com`)
reads and writes the family calendar "Rodina Konrády". It sees only
calendars shared with it, so it can't read anyone's personal or work
calendar. Auth comes from env vars in `~/dotfiles/zsh/.zsh_secrets`:
`FAMILY_GCAL_CREDENTIALS` and `FAMILY_GCAL_CALENDAR_ID`. See
`references/setup.md` for how that is set up and for fixing auth errors.

The whole family uses this calendar, and a wrong entry or a deleted event
affects everyone. That is why user-requested writes follow preview → confirm
→ submit.

## Commands

Scripts are in `~/.config/opencode/skills/personal-family-calendar/scripts/`.

```bash
node cal.mjs list   [FROM] [TO] [--json]      # default: today .. +6 days, TO inclusive
node cal.mjs search TEXT [--from D] [--to D]  # default: today .. +1 year
node cal.mjs add    "TITLE" DATE [TIME[-TIME]] [--to-date D] [--desc T] [--location T] [--submit]
node cal.mjs update ID [--title T] [--date D] [--time HH:MM[-HH:MM]] [--desc T] [--location T] [--submit]
node cal.mjs delete ID [--submit]
```

Dates: `dnes`, `zitra`, `pozitri`, weekday names (the next occurrence after
today, so "středa" said on a Wednesday means next week), `2.10.`, `2.10.2026`,
`2026-10-02`. Time: `10`, `10:30`, `9.15`. A range is `10-11:30`. Without
an end time, the event lasts one hour. Without a time, it's all day, and
`--to-date` extends it over several days. Times are Europe/Prague.

Each listed event shows its `id` and who created it: an email address, or
`auto: <source>` for events another skill maintains.

## Reading

`list` and `search` need no confirmation. Turn a Czech phrase into a range,
e.g. "o víkendu" → `list sobota nedele`, "tento týden" → `list dnes <neděle>`,
"kdy je zubař" → `search zubař`. Summarize the answer in the user's
language, grouped by day. Don't dump the raw output.

## Writing (add, update, delete)

1. Run the command **without** `--submit`. It prints exactly what would
   be written. Show it to the user with the resolved date and weekday,
   because "v pátek" can land a week later than they meant.
2. Wait for an explicit yes, then run the same command with `--submit`.
   Several changes asked for together get one preview and one confirmation.
3. To update or delete, get the `id` from `list` or `search` first. If
   more than one event matches, ask which one.

Events marked `auto: …` belong to another skill's sync. `auto:
personal-kids-meal` is the "nemá oběd" entries, which follow the eListek
canteen. Don't edit or delete them by hand, because the next sync would
put them back. Change the underlying thing instead, e.g. re-order the meal
via personal-kids.

Events created by family members can be edited or deleted only when the user
asks for that specific event.

Answer in Czech when the user writes in Czech.

## Library for other skills

`scripts/gcal.mjs` exports `listEvents({timeMin, timeMax, q, tags})`,
`getEvent`, `insertEvent`, `patchEvent`, `deleteEvent`, `upsertEvent(id,
event)`, `eventId(key)`, and `calendarConfigured()`. `scripts/dates.mjs`
has the date parsing. An automated caller must:

- tag its events with `extendedProperties.private.source = "<caller>"` and
  only ever list or modify events with that tag;
- use stable IDs (`eventId("<caller>:<key>")`) so reruns stay idempotent.

The caller's own confirmation covers these writes, so this skill's
preview step does not apply. personal-kids does this for its meal events.
