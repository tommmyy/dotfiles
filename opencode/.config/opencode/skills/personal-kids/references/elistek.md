# eListek (ZŠ a MŠ Libčany canteen)

Canteen ID `5RA1336P865653676`. Each kid has a static page
`http://www.elistek.cz/elistek/<canteen>/users/<code>.htm`. The code is the only
credential and is case-sensitive. `<code>_H.htm` is the month's history.

## How it works

- The page lists **only the days that can still be changed**. That is usually
  just the next school day. A date that isn't listed can't be changed yet,
  or can't be changed any more. Tell the user, and offer to try again later.
- Deadline: **11:00 on the previous day**. `set` flags late dates and refuses
  to `--submit` them without `--force`. Use `--force` only if the user insists
  after being told the canteen will probably reject it.
- Submitting POSTs the whole form to `sendelistekmail.php`, which emails the
  canteen. It answers with "eListek: probiha odesilani emailu se zmenami"
  and then sends the browser on to `ok.htm`. Both count as success.
- The canteen PC applies the change and regenerates that kid's page, and
  the delay varies. Two cancels were sent at 10:41 on 29.9.2026: Diana's
  page showed hers at 10:46, but Izabela's only at 11:03, in the daily
  ~11:00 regeneration of all pages. The "stránka vytvořena"
  timestamp shows how fresh the page is.
- Once a day is cancelled, the page shows the checked `0` option with an
  empty label. The parser treats code `0` as "odhlásit".
- If a change is rejected (for example, not enough credit), the canteen emails
  the user and the page keeps the old choice.

## Options per facility

Codes are the suffix after the date in the radio value. `status` prints them.

**MŠ, Izabela**

| Code | Label | Meaning |
| --- | --- | --- |
| A | celý den | přesnídávka + oběd + svačina |
| B | přesnídávka a oběd | drops the afternoon snack; the child goes home after lunch |
| 0 | odhlásit | nothing that day |

**ZŠ, Diana**

| Code | Label |
| --- | --- |
| 1 | 1. jídlo |
| 0 | odhlásit |

## Phrase -> CHOICE

| User says | MŠ (Izabela) | ZŠ (Diana) |
| --- | --- | --- |
| odhlaš oběd / stravu / celý den, je nemocná, nebude tam | `off` | `off` |
| odhlaš svačinu, jde po obědě domů, jen oběd | `nosnack` | not possible: say so |
| přihlaš (zpět), bude tam celý den | `on` (= A) | `on` (= 1) |
| přihlaš jen dopoledne / přesnídávku a oběd | `nosnack` | `on` |

In MŠ, **"odhlaš oběd" means `off` (the whole day)**. There is no option for
snacks without lunch. Say this in the preview so the user can pick `nosnack`
if they only meant the afternoon.

## Dates

Pass dates the way the user said them: `streda`, `zitra`, `30.9.`,
`2026-09-30`. Several dates in one call are fine. A weekday name means its next
occurrence after today, so on a Wednesday "středa" means next week. Check the
resolved date in the preview.

## Commands

```bash
node elistek.mjs status  <kid> [--json]   # credit, page time, orderable days, menu, options
node elistek.mjs history <kid>            # month history: [A]/[1] ordered, [V] served, [ ] none
node elistek.mjs set     <kid> <choice> <date...>            # preview only
node elistek.mjs set     <kid> <choice> <date...> --submit   # send (after user confirms)
node elistek.mjs verify  <kid> <choice> <date...> [--timeout 900 --interval 60]
```

Exit codes: 2 bad input/env/login, 3 date not orderable, 4 past deadline
(submit refused), 5 verify timed out.
