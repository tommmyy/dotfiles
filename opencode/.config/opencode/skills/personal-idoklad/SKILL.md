---
name: personal-idoklad
description: >
  Use this skill for invoicing and Czech VAT paperwork in iDoklad (idoklad.cz)
  through the `idoklad` MCP server. Trigger on requests like "vystav fakturu",
  "create an invoice", "zkopíruj poslední fakturu", "copy the last invoice and
  change the amount", "stáhni fakturu jako PDF", "udělej kontrolní hlášení",
  "přiznání k DPH za minulý měsíc", "generate the VAT filings", or any mention
  of iDoklad invoices, faktury vydané, kontrolní hlášení, or DPH reports.
  Covers two workflows: copy-edit-save-download an issued invoice, and generate
  the monthly VAT filings for manual upload to the state portal.
---

# iDoklad: invoices and VAT filings

## Purpose

Drive iDoklad from opencode for the two recurring jobs: issuing an invoice by
copying the previous one, and producing the monthly Czech VAT filings that get
uploaded to the state portal by hand.

## What the MCP server can and cannot do

The `idoklad` MCP server has two halves, and they behave very differently.

**Invoices go through the documented REST API v3.** Reliable, fast, structured.

**VAT filings do not exist in the API.** All 313 v3 endpoints were checked:
`Reports` only renders individual documents as PDF, and `Statistics/VatTotals`
returns six aggregate numbers — neither is a filing. So `vat_filings_download`
drives the iDoklad **web app** in a headless browser and lets iDoklad compute
the numbers. That means it is slower, needs `IDOKLAD_EMAIL` /
`IDOKLAD_PASSWORD`, and can break when iDoklad changes its UI. Never claim a
filing was produced unless the tool returned real file paths.

## Workflow A: new invoice by copying the last one

### 1. Find the source invoice

Call `invoice_list` (defaults to newest first). Unless the user named a
specific invoice, the source is the first row. Show the user which invoice you
are about to copy — number, date, partner, total — so a wrong source is caught
before anything is written.

### 2. Preview the draft

Call `invoice_copy_draft` with the `changes` the user asked for. It returns
`draft` (exactly what would be POSTed) and `totals` (iDoklad's pricing of that
draft). Merge semantics matter:

- Objects merge recursively; **arrays and scalars replace wholesale**. Passing
  `Items` replaces the entire item list, so to tweak one line you must send all
  lines.
- `null` deletes a key.
- `recount` defaults to true, so `totals` comes back calculated by iDoklad
  rather than computed here. Never hand-calculate VAT.

The copy already carries the next document number in `DocumentSerialNumber` —
do not set it yourself.

Typical edits: `DateOfIssue`, `DateOfTaxing`, `DateOfMaturity`, `Description`,
`Items[].Amount`, `Items[].UnitPrice`, `Items[].Name`, `PartnerId`.

Dates are ISO (`2026-09-30`). Resolve a partner by name with `contact_list`,
never by guessing an id. Resolve VAT rates, currencies, payment options and
numeric sequences with `codebook` when a change needs an id.

### 3. Confirm before saving

Show the user the resulting draft: document number, dates, partner, line items,
and the recounted total. **Wait for explicit confirmation** — this creates a
real accounting document. Do not chain straight from request to saved invoice.

### 4. Save

Call `invoice_create_from_copy` with the same arguments. Capture the returned
`Id` and `DocumentNumber`.

Passing `dryRun: true` returns the draft unsaved, equivalent to step 2; use it
if the user keeps adjusting.

### 5. Download the PDF

Call `invoice_pdf` with the new `Id` and a `path`. Default the filename to the
document number, e.g. `~/Downloads/2026-0042.pdf`. Report the absolute path.

### 6. Report back

Invoice number, id, total, and the PDF path.

## Workflow B: monthly VAT filings

### 1. Resolve the period

"Last month" means the calendar month before today — state the resolved period
(`2026-08`) explicitly so an off-by-one month is caught immediately.

A filing only contains what was already invoiced. If the user asks for last
month before issuing that month's invoice, the filing will come back empty —
check `invoice_list` for a document whose `DateOfTaxing` falls in the period,
and say so before generating rather than after.

### 2. Generate

Call `vat_filings_download` with `year`, `month`, `outputDir` (default
`~/Downloads`). It defaults to kontrolní hlášení plus přiznání k DPH; souhrnné
hlášení is opt-in, since it only covers cross-border EU supplies.

It drives a browser, so it takes tens of seconds per filing. If it fails, retry
once with `headed: true` and report what the browser was doing rather than
inventing a cause.

### 3. Check the filing is not empty

Each result reports `documentRows` and `sections`, read from the generated XML:

- **Kontrolní hlášení** lists one `VetaA*`/`VetaB*` row per document.
  `documentRows: 0` means iDoklad found nothing in that period — say so plainly
  instead of presenting it as a finished filing.
- **Přiznání k DPH** always carries the form's aggregate boxes `Veta1`–`Veta6`
  whether or not anything was traded, so `documentRows` is always 0 for it and
  proves nothing. Do not report it as empty on that basis.

If kontrolní hlášení is empty, the usual cause is that the period's invoice
does not exist yet, or its `DateOfTaxing` falls outside the month. The second
possible cause is documents saved without členění DPH, which iDoklad warns
about on that screen — those never reach the filing.

### 4. Report back

- Absolute path of each XML file.
- The **daňový portál link** returned as `portalUrl`
  (`https://adisspr.mfcr.cz/pmd/epo`) — the user needs it to upload.
- The period covered, and whether kontrolní hlášení actually had rows.

Then stop. The user uploads to the portal themselves; do not offer to submit
the filings, and do not attempt to open the portal.

## Common mistakes

- Saving an invoice without showing the draft and getting confirmation first.
- Computing VAT or totals manually instead of letting `recount` do it.
- Sending a partial `Items` array and silently dropping the other lines.
- Guessing a `PartnerId`, `VatRateType` or `PaymentOptionId` instead of looking
  it up with `contact_list` / `codebook`.
- Claiming the VAT filings were generated when the tool errored — there is no
  API fallback, so a browser failure means no filing at all.
- Presenting an empty kontrolní hlášení as a finished filing, or calling
  přiznání k DPH empty because its `documentRows` is 0.
- Forgetting to return the `portalUrl`; it is half the point of workflow B.
- Offering to submit the filings to the state portal. The user does that
  manually, by design.
