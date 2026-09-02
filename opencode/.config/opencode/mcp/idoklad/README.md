# iDoklad MCP server

Invoicing and Czech VAT filings for [iDoklad](https://www.idoklad.cz), exposed
to opencode as the `idoklad` MCP server. Paired with the `personal-idoklad`
skill, which describes the workflows.

## Two halves, two mechanisms

**Invoices** use the documented [REST API v3](https://api.idoklad.cz/Help/v3/cs/index.html)
with OAuth2 client credentials.

**VAT filings** are not in the API. All 313 v3 endpoints were checked: the
`Reports` group only renders individual documents as PDF, and
`Statistics/VatTotals` returns six aggregate numbers. Kontrolní hlášení and
přiznání k DPH exist only in the web app, under **Finance → DPH**
(`/VatDeclaration`), so `vat_filings_download` drives that screen with
Playwright and lets iDoklad compute the numbers. That half is slower and
depends on iDoklad's UI staying put.

The screen is built with Kendo UI, whose `<select>` elements are aria-hidden
decoys holding a single `[object Object]` option. Selection therefore goes
through the widgets, matched on their `data-ui-id` hooks
(`csw-vat-declaration-dropdown`, `csw-month-dropdown`, `csw-year-dropdown`,
`csw-vat-submit`) because element ids are regenerated as GUIDs on every render.
After generating, iDoklad shows a toast linking to the daňový portál
(`https://adisspr.mfcr.cz/pmd/epo`); that link is returned as `portalUrl`.

## Setup

### 1. API credentials

In iDoklad: **Nastavení → Aplikace a API**, create an API application, and copy
its client id and secret.

### 2. Store the secrets in the keychain

```sh
security add-generic-password -a "$USER" -s idoklad-client-id     -w '...'
security add-generic-password -a "$USER" -s idoklad-client-secret -w '...'
security add-generic-password -a "$USER" -s idoklad-email         -w 'you@example.cz'
security add-generic-password -a "$USER" -s idoklad-password      -w '...'
```

`~/.zsh_secrets` reads all four and exports `IDOKLAD_CLIENT_ID`,
`IDOKLAD_CLIENT_SECRET`, `IDOKLAD_EMAIL` and `IDOKLAD_PASSWORD`;
`opencode.jsonc` passes them to the server.

The email and password are only needed for the VAT tools. The invoice tools
work with just the client id and secret.

### 3. Install dependencies

```sh
npm install
npx playwright install chromium   # only if Chromium is not already cached
```

## Tools

| Tool | Purpose |
| --- | --- |
| `invoice_list` | List issued invoices, newest first |
| `invoice_get` | Full detail of one invoice |
| `invoice_copy_draft` | Build an unsaved copy with changes applied |
| `invoice_create_from_copy` | Copy, edit, recount and save in one call |
| `invoice_create` | Create from a complete payload |
| `invoice_update` | Partially update an existing invoice |
| `invoice_pdf` | Download an invoice as PDF |
| `contact_list` | Find a contact to resolve `PartnerId` |
| `codebook` | Read a codebook (VAT rates, currencies, payment options, …) |
| `vat_filings_download` | Generate and download the monthly VAT filings |

### Reading a filing result

Each filing reports `sections` and `documentRows`, parsed from the XML. The two
filings are shaped differently, so they cannot be judged the same way:

- **Kontrolní hlášení** lists one `VetaA*`/`VetaB*` row per document, so
  `documentRows: 0` means iDoklad found nothing in the period — usually because
  the month's invoice has not been issued yet, its `DateOfTaxing` falls
  elsewhere, or the documents carry no členění DPH.
- **Přiznání k DPH** always carries the form's aggregate boxes `Veta1`–`Veta6`,
  so its `documentRows` is always 0 and says nothing about whether it is empty.

### Editing semantics

`changes` on the copy tools deep-merges into the copied invoice: objects merge
recursively, arrays and scalars replace wholesale, `null` deletes a key.
Replacing one line item therefore means sending the whole `Items` array.

Totals are never computed locally. `recount` (default on) posts the draft to
`IssuedInvoices/Recount` so iDoklad returns the authoritative VAT and totals.
Only those totals are kept: the Recount response reshapes items, moving
`UnitPrice` inside a per-item `Prices` object and dropping `Code`, `Unit`,
`VatCodeId` and `PriceListItemId`, so merging its items back into the draft
would strip the prices from the invoice being created.

## Browser session

`vat_filings_download` keeps a persistent Chromium profile so it does not log in
on every run. It lives in `~/.local/share/idoklad-mcp/browser-profile`, override
with `IDOKLAD_BROWSER_PROFILE`. Pass `headed: true` to watch a run that is
misbehaving.
