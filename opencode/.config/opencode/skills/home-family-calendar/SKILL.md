---
name: home-family-calendar
description: >
  Read and edit the Konrády family Google Calendar "Rodina Konrády": what's
  on, add, move, change, or delete a family event.
metadata:
  opencode/autoinvoke: false
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

Scripts are in `~/.config/opencode/skills/home-family-calendar/scripts/`.

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

Events marked `auto: …` are written by home-kids code: `auto:
personal-kids-meal` is "nemá oběd" (follows the eListek canteen) and `auto:
personal-kids-judo` is "nemá judo". Don't edit or delete them by hand, because
the next sync would put them back. Change the underlying thing instead, e.g.
re-order the meal via home-kids.

Events created by family members can be edited or deleted only when the user
asks for that specific event.

Answer in Czech when the user writes in Czech.

## Code

`cal.mjs` is a thin CLI over the shared calendar client in
`~/.config/opencode/skills/_lib/` (`gcal.mjs`, `dates.mjs`). home-kids uses
the same client for its automatic events, following the rules in
`_lib/README.md`. Those writes are covered by the confirmation in
home-kids, so this skill's preview step doesn't apply to them.
