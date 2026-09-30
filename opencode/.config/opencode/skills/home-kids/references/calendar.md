# "Nemá oběd" events in the family calendar

Days when a kid has no meal ordered in eListek appear in the family calendar
"Rodina Konrády" as an all-day, non-blocking event **"<Name> nemá oběd"**,
so whoever is on duty knows to pack food or pick the kid up before lunch.

Calendar access comes from the shared package `skills/_lib/gcal.mjs`, which
`scripts/mealcal.mjs` and `scripts/judo.mjs` import. Auth, setup, and error
meanings are in `home-family-calendar/references/setup.md`. These writes
happen in the background, because confirming the meal or judo change already
covers them.

## How the events are maintained

- **After a submit:** `elistek.mjs set ... --submit` adds the event (for a
  cancel) or removes it (for re-ordering) right away.
- **Daily sync:** `kids-meal-sync` (launchd `com.tommmyy.kids-meal-sync`,
  Mon-Fri 12:15) runs `scripts/mealcal.mjs sync`. It reads each kid's page and
  month history from today on, then adds or removes events so the calendar
  matches the canteen. This also picks up changes made by someone else, and
  changes the canteen rejected. Log: `~/Library/Logs/kids-meal-sync.log`.
- A school day counts as "no meal" when eListek has it as `odhlásit`, `[0]`, or
  `[ ]` (neobjednáno). Weekends, Czech public holidays, and `[*]` (nevaří se)
  are skipped. School holidays such as podzimní prázdniny are not known, so if
  the canteen leaves them as `[ ]` they show up as "nemá oběd".
- Events carry private extended properties `source=personal-kids-meal` and
  `kid=<key>`, and have fixed IDs. The sync never touches any other event,
  and past days are left alone.

Run by hand: `kids-meal-sync --dry-run` (preview) or `kids-meal-sync`.
