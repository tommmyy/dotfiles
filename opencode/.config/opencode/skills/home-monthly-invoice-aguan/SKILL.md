---
name: home-monthly-invoice-aguan
description: >
  Use this skill to issue the recurring monthly invoice for Aguan s.r.o. in
  iDoklad by copying the previous month's invoice. Trigger on requests like
  "vystav fakturu pro Aguan", "měsíční faktura za srpen", "udělej fakturu podle
  předchozího měsíce", "create the monthly invoice for Aguan", "faktura za
  minulý měsíc", or any request that pairs a month with a count of odpracované
  MDs/hodiny and a vícepráce amount. Owns the arithmetic that turns worked hours
  into the invoice base, which cannot be derived from the MD figure alone.
---

# Měsíční faktura pro Aguan

## Purpose

Issue the recurring monthly invoice to Aguan s.r.o. by copying the previous
month's invoice and changing three things: the dates, the worked time, and the
vícepráce amount. Everything else — partner, popis, číselná řada, VAT setup —
carries over from the copy.

Mechanics of the MCP server (tools, merge semantics, the fact that it is
disabled by default) live in **`home-idoklad`**; follow that skill for those
and do not restate them here.

## The one thing that is easy to get wrong

**The invoice base is worked hours × hourly rate. It is not MDs × the MD rate.**

The MD figure printed in the item name is a display value rounded to two
decimals, so recomputing from it silently produces a wrong base — historically
off by multiples of 8,25 Kč.

Derive the numbers like this, reading the MD rate from the previous invoice
rather than hardcoding it (it has been 6100, 7000 and 6600 across years):

```
hourly rate = MD rate / 8
base        = hours × hourly rate
MD shown    = hours / 8, rounded to 2 decimals, Czech decimal comma
item name   = "<MD> MDs v sazbě <MD rate>/MD"
```

Worked example, August 2026 at 6600/MD: 149 h × 825 = 122 925 Kč, shown as
`18,63 MDs v sazbě 6600/MD` because 149 / 8 = 18,625.

So **ask for hours, not MDs**. If the user offers MDs instead, treat the value
as possibly rounded: multiply by 8 and check the result is a plausible hour
count (quarter hours, or one decimal place). If it is not — 18,63 × 8 = 149,04
— the real figure is the nearby clean one, and you must confirm which before
building the invoice.

## Workflow

### 1. Collect the inputs

Needed: the month being invoiced, hours worked, and the vícepráce amount
(bez DPH). Ask for whatever is missing. Verify the hours against the rule above
before going further.

### 2. Find the source invoice

`invoice_list` — the source is the previous month's invoice. Confirm its
`DateOfTaxing` really is the month before the one being invoiced; if the
previous month was skipped, say so rather than copying a stale invoice.

Read the MD rate out of its first item name for the arithmetic in step 1.

### 3. Build the draft

`invoice_copy_draft` with:

- `DateOfIssue` and `DateOfTaxing`: last day of the invoiced month.
- `DateOfMaturity`: **14 days after issue**. The copy suggests 30 days, and
  invoice 20260007 used 30, but every other invoice in the series uses 14 —
  confirm rather than accepting the copy's default.
- `ItemsTextSuffix`: `"Období 1.<M>. - <last day>.<M>.<YYYY>"` for the invoiced
  month, e.g. `"Období 1.8. - 31.8.2026"`. This prints under the items on the
  PDF and **the copy carries the previous month's period**, so it has to be
  rewritten every time.
- `Items`: exactly two lines, both `PriceType: 1` (bez DPH), `VatRate: 21`,
  `VatRateType: 1`, `VatCodeId: 3`, `IsTaxMovement: true`, `ItemType: 0`,
  `Amount: 1`, `DiscountPercentage: 0`:
  1. `"<MD> MDs v sazbě <rate>/MD"` at the computed base.
  2. `"vícepráce"` at the amount the user gave.

  `DiscountPercentage` is required by `POST /IssuedInvoices`, but the preview
  (`invoice_copy_draft`) accepts items without it. Leave it out and the draft
  looks fine, then the save fails with HTTP 400.

**Drop the copied `Rounding` line.** It carries the previous month's
adjustment, and iDoklad recomputes its own on save. `Items` replaces the whole
list, so simply omit it.

### 4. Confirm, then save

Show the draft as a table — číslo, odběratel, dates, **období
(`ItemsTextSuffix`)**, both lines, and the recounted bez DPH / DPH / celkem —
and wait for explicit approval. Every date-bearing field belongs in that table,
because anything omitted from it is a field nobody checks. This writes a real
accounting document and consumes a number in the číselná řada.

Then `invoice_create_from_copy` with the same arguments, and `invoice_pdf` to
`~/Downloads/<číslo>.pdf`.

### 5. Report back

Číslo faktury, id, splatnost, the three totals, and the PDF path. Mention the
`Rounding` line iDoklad added, so the total is traceable.

If the user also wants the VAT filings for that month, hand over to
`home-idoklad` workflow B — and note the filing is only complete once this
invoice exists, since it is what puts the month's DUZP on record.

## Common mistakes

- Computing the base as MDs × MD rate. It is hours × (MD rate / 8), and the
  printed MD figure is rounded.
- Accepting a MD figure that implies a ragged hour count (149,04 h) instead of
  confirming the clean one (149 h).
- Copying the previous month's `Rounding` line into the new invoice.
- Omitting `DiscountPercentage: 0` from the items. The preview passes, the
  save is rejected.
- Leaving `ItemsTextSuffix` on the previous month's period. It is not visible
  in the totals and survives the copy untouched, so it is the field most likely
  to ship wrong — it reached a saved invoice this way once already.
- Taking the copy's 30-day maturity without asking; the series uses 14 days.
- Dating the invoice today instead of the last day of the invoiced month —
  a wrong `DateOfTaxing` moves it into the wrong VAT period.
- Saving before showing the draft and getting explicit approval.
- Hardcoding 6600/MD or 825/h. Read the rate from the previous invoice.
