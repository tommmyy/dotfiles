---
name: home-kids
description: >
  Tomáš's kids Izabela (Iza, kindergarten) and Diana (Dianka, Didi, ZŠ
  Libčany): lunches in eListek, school in Bakaláři (timetable, homework,
  marks, messages, omluvenky), judo absences, and kroužky. Use whenever
  either girl is mentioned in any Czech form, or for obědy, jídelna, školka,
  škola, omluvenka, úkoly, trénink, or kroužek.
metadata:
  opencode/autoinvoke: false
---

# Kids: meals, school, activities

## Who is who

`config.json` is the registry: each kid has a key, Czech name forms (aliases),
a facility, and one block per service area. Scripts resolve a kid by any alias,
so pass the name as the user wrote it (`Izabelce`, `Dianě`).

| Kid | Facility | Meals |
| --- | --- | --- |
| Izabela (Iza) | MŠ Libčany (kindergarten) | eListek, `KIDS_IZABELA_ELISTEK_CODE` |
| Diana | ZŠ Libčany (primary school) | eListek, `KIDS_DIANA_ELISTEK_CODE` |

Login codes live only in env vars exported from `~/dotfiles/zsh/.zsh_secrets`
(gitignored). Never write a code into this skill or into chat output. If a
script says a variable is unset, tell the user which one and stop.

## Areas

| Area | How | Details |
| --- | --- | --- |
| Meals | `scripts/elistek.mjs` | `references/elistek.md` |
| Family calendar ("nemá oběd", "nemá judo") | `scripts/mealcal.mjs` (daily `kids-meal-sync`), `judo.mjs verify` | `references/calendar.md` |
| School: timetable, homework, messages, marks, events, omluvenka (Diana) | `scripts/bakalari.mjs` | `references/bakalari.md` |
| Judo absences (Diana) | `scripts/judo.mjs` + Playwright MCP | `references/judo.md` |
| Activities | edit `activities.md` directly | the file itself |

To add an area (school system like Bakaláři, a club's booking site...), add
a block to the kid in `config.json` (`"school": {"provider": ..., "..._env": ...}`),
a `references/<provider>.md`, and a `scripts/<provider>.mjs` that imports
`kids.mjs` for kid lookup, secrets, and date parsing. Then add a row above.

## Dependencies

- **Code:** date parsing and the Google Calendar client come from the shared
  package `~/.config/opencode/skills/_lib/` (`dates.mjs`, `gcal.mjs`, rules in
  its `README.md`). The scripts write automatic events ("nemá oběd", "nemá
  judo") themselves. The user's confirmation of the meal or judo change covers
  them.
- **Manual calendar work:** when the user wants a calendar event outside those
  automatic ones (e.g. "přidej Mažoretky do kalendáře"), load the
  `home-family-calendar` skill by ID and follow its preview → confirm flow.
  Don't call `_lib/gcal.mjs` directly for that.

## Meals workflow (preview, confirm, submit, verify)

The user wants to see what will change before anything is sent, because a wrong
submission costs money or leaves a child without lunch, and changes go to
the canteen by email and cannot be taken back.

Scripts are at `~/.config/opencode/skills/home-kids/scripts/`.

1. **Translate the request** into kid + CHOICE + dates. Read
   `references/elistek.md` for how Czech phrasing maps to options. It is
   different for MŠ and ZŠ.
2. **Preview:** `node elistek.mjs set <kid> <choice> <date...>`. This only
   reads. Show the user the lines it prints (date, weekday, from -> to) and
   say anything notable: past the deadline, the day isn't orderable yet,
   or an MŠ lunch cancel covering the whole day. Ask for confirmation.
   Handle several kids in one request with one preview per kid, then one
   confirmation for all of them.
3. **Submit** only after an explicit yes: the same command plus `--submit`.
   With several kids, submit one at a time with `sleep 30` in between. On
   29.9.2026 two cancels sent a second apart both got a success reply, but
   only one was applied; the canteen couldn't say why.
   The same run adds or removes the "nemá oběd" event in the family calendar
   and prints a `calendar:` line. Don't ask for a separate confirmation for
   that; the meal confirmation covers it. Pass the line on to the user. If
   it says the update failed, say that the 12:15 sync will retry.
4. **Verify:** start `node elistek.mjs verify <kid> <choice> <date...>
   --timeout 2400 --interval 120` in the background for each kid. The
   canteen usually shows the change within minutes. Report each result when
   it arrives. If it times out, tell the user to check again later or call
   the canteen. Don't resubmit, because two submissions can be applied in
   the wrong order.

Informational questions ("co mají zítra k obědu", "kolik má kreditu", "jak
byla přihlášená minulý týden") use `status` or `history` and need no
confirmation.

Answer in Czech when the user writes in Czech.

## School absence (omluvenka)

"Didi je nemocná" usually means three things: an omluvenka in Bakaláři
(`references/bakalari.md`), a lunch cancel in eListek, and a judo absence if
it falls on Monday or Wednesday. Ask whether she misses all of them, then
show one preview covering all of them and get one confirmation. The
omluvenka goes through `bakalari.mjs excuse` and follows the same preview →
confirm → `--submit` flow.

## Judo absence workflow (preview, confirm, write, verify)

Diana's judo club keeps absences in a Google Sheet that all parents write
into. Follow `references/judo.md`. It covers how to ask for the reason, the
`plan` preview, the Playwright write, and `verify`. Never clear or overwrite
a cell in that sheet.

## Activities

`activities.md` is the source of truth for kroužky and trainings: day, time,
place, who takes the child, contact, price, and payment status. Read it to
answer questions and edit it when the user reports a change. Keep it
describing the current state. Drop finished activities rather than marking
them "previously".
