# Judo absences (omluvenky)

Diana ("Didi") trains Baby judo on Mondays 15:30–16:30 and Wednesdays
16:00–17:00. The club takes absences in the shared Google Sheet
"JUDO - OMLUVENÍ ABSENCE" (`judo.sheet_id` in `config.json`). Anyone with
the link can edit it without logging in, so the default headless Playwright
MCP (`tools.playwright.*`) is enough.

**Every parent writes into this sheet.** Never clear, overwrite, or reformat
a cell. Only write into a cell that is empty right before the write. The
Playwright code from `plan` refuses to write anywhere else.

## Sheet layout

- One tab per month, e.g. `OMLUVY - ZÁŘÍ`. The club adds the next month's tab
  itself. If it's missing, `plan` says so. Don't create it; ask the user.
- Row 1 has the group headers, each merged over two columns: `ZÁVODNÍ TÝM A`
  C:D, `ZÁVODNÍ TÝM B` E:F, `STŘEDNĚ POKROČILÍ` G:H, `BABY JUDO` I:J.
- Column A is the weekday and column B the day number. Each weekday has 5
  rows. A group's block is merged on days it doesn't train.
- An entry is one cell, `Jméno Příjmení - důvod`. The next absence goes into
  the first empty cell of the day in the first column (I), then the second (J).

## Workflow

1. **Reason.** The entry needs a short reason, like "nemocná", "zraněná", or
   "zranění na noze". If the user didn't give one, ask. Don't make one up.
2. **Preview:** `node judo.mjs plan <kid> <date> <reason...>`. It reads the
   sheet (xlsx export) and fails on a non-training day, a missing month tab,
   a merged block, or if Diana is already listed. Otherwise it prints the
   target cell, the entries it will keep, the calendar event, and the
   Playwright code. It also saves a snapshot for `verify`. Show the user the
   day with its weekday, the cell, and the text, then ask for confirmation.
3. **Write** after an explicit yes. Call `tools.playwright.browser_navigate`
   to the sheet's `/edit` URL, then `tools.playwright.browser_run_code_unsafe`
   with the code from `plan`. If the result says `aborted`, stop and re-run
   `plan`, because someone wrote into the cell in the meantime.
4. **Verify:** `node judo.mjs verify <kid> <date>`. It re-reads the export
   (retrying until `--timeout`, default 120 s), checks the target cell, and
   warns if any previously filled cell changed. It then adds the event
   "Diana nemá judo" (tagged `source=personal-kids-judo`) to the family
   calendar at training time and prints a `calendar:` line to pass on.

`node judo.mjs status <kid> [date]` lists the absences for a day and needs no
confirmation. Without a date it uses the next training day.

## Taking an absence back

The script can't do this. Clear only the cell holding Diana's own entry,
after reading it in the formula bar and confirming the exact text with the
user. Then delete the calendar event with `eventId("personal-kids-judo:diana:<date>")`.

## Notes

- The export sometimes answers with a Google 502 page. The script retries.
- Dates without a year resolve forward, so "16.9." said in late September
  means next year. Pass the full date for past days.
