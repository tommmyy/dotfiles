---
name: personal-kids
description: >
  Manage Tomáš's children's everyday logistics: school/kindergarten meal
  orders (odhlašování/přihlašování obědů, svačin) in eListek, judo absences
  (omluvenky) in the club's Google Sheet, and their activities (kroužky,
  tréninky, schedule, contacts, prices). Use this skill whenever the user
  mentions Izabela/Izabelka/Iza or Diana/Dianka/Didi in any Czech form
  (Izabelce, Diance, Dianě...), or says things like "omluv z juda",
  "nepůjde na judo", "odhlaš oběd",
  "odhlaš stravu", "přihlaš oběd", "odhlaš svačinu", "jde po obědě domů",
  "je nemocná, odhlaš ji", "co mají zítra k obědu", "kolik mají kreditu",
  "jídelna", "školka", "MŠ", "ZŠ Libčany", "eListek", "kroužek", "kdy má
  trénink", or asks to add or change anything about the kids' school,
  kindergarten, meals, or activities.
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
| Family calendar ("nemá oběd" days) | `scripts/mealcal.mjs` on top of the personal-family-calendar skill, daily `kids-meal-sync` | `references/calendar.md` |
| Judo absences (Diana) | `scripts/judo.mjs` + Playwright MCP | `references/judo.md` |
| Activities | edit `activities.md` directly | the file itself |

To add an area (school system like Bakaláři, a club's booking site...), add
a block to the kid in `config.json` (`"school": {"provider": ..., "..._env": ...}`),
a `references/<provider>.md`, and a `scripts/<provider>.mjs` that imports
`kids.mjs` for kid lookup, secrets, and date parsing. Then add a row above.

## Meals workflow (preview, confirm, submit, verify)

The user wants to see what will change before anything is sent, because a wrong
submission costs money or leaves a child without lunch, and changes go to
the canteen by email and cannot be taken back.

Scripts are at `~/.config/opencode/skills/personal-kids/scripts/`.

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
