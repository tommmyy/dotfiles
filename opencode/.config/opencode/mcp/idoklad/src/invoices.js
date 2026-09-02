/**
 * Issued-invoice operations built on the v3 REST API.
 *
 * The "copy the last invoice, change a few fields, save" workflow is served by
 * `copyDraft` (preview) and `createFromCopy` (preview + save), both of which
 * start from GET /IssuedInvoices/{id}/Copy — the API returns a payload that is
 * already shaped for POST /IssuedInvoices, including the next serial number.
 */

import { writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { request } from "./api.js";

export const REPORT_LANGUAGES = { cs: 1, sk: 2, en: 3, de: 4 };

/**
 * Deep-merge `changes` into `base`. Plain objects merge recursively; arrays and
 * scalars replace wholesale, so passing `Items` swaps the whole item list.
 * A null value deletes the key.
 */
export function mergeChanges(base, changes) {
  if (!changes) return base;
  const out = Array.isArray(base) ? [...base] : { ...base };
  for (const [key, value] of Object.entries(changes)) {
    if (value === null) {
      delete out[key];
    } else if (isPlainObject(value) && isPlainObject(out[key])) {
      out[key] = mergeChanges(out[key], value);
    } else {
      out[key] = value;
    }
  }
  return out;
}

const isPlainObject = (v) => typeof v === "object" && v !== null && !Array.isArray(v);

/** Compact row for listings, so a list of invoices does not flood the context. */
function summarize(invoice) {
  return {
    Id: invoice.Id,
    DocumentNumber: invoice.DocumentNumber,
    DateOfIssue: invoice.DateOfIssue,
    DateOfMaturity: invoice.DateOfMaturity,
    DateOfTaxing: invoice.DateOfTaxing,
    Partner: invoice.PartnerAddress?.NickName ?? invoice.PartnerId,
    PartnerId: invoice.PartnerId,
    Description: invoice.Description,
    VariableSymbol: invoice.VariableSymbol,
    TotalWithVat: invoice.Prices?.TotalWithVat,
    CurrencyId: invoice.CurrencyId,
    DateOfPayment: invoice.DateOfPayment,
  };
}

export async function listInvoices({ limit = 20, page = 1, filter, filtertype, sort = "DateOfIssue~desc", full = false } = {}) {
  const data = await request("IssuedInvoices", {
    query: { page, pagesize: limit, filter, filtertype, sort },
  });
  const items = data.Items ?? [];
  return {
    totalItems: data.TotalItems,
    totalPages: data.TotalPages,
    page: data.CurrentPage ?? page,
    items: full ? items : items.map(summarize),
  };
}

export const getInvoice = (id) => request(`IssuedInvoices/${id}`);

/** Id of the most recently issued invoice, used when no source is given. */
async function latestInvoiceId() {
  const { items } = await listInvoices({ limit: 1, sort: "DateOfIssue~desc" });
  if (!items.length) throw new Error("No issued invoices found to copy from.");
  return items[0].Id;
}

/**
 * Build (but do not save) a new-invoice payload from an existing invoice.
 * Returns the source id alongside the draft so callers can report what was copied.
 */
/**
 * Build an unsaved new-invoice payload from an existing invoice.
 *
 * `draft` is exactly what gets POSTed; `totals` is iDoklad's own calculation of
 * that draft, for showing the user before saving. They are kept apart on
 * purpose — see `recountTotals`.
 */
export async function copyDraft({ sourceInvoiceId, changes, recount = true } = {}) {
  const sourceId = sourceInvoiceId ?? (await latestInvoiceId());
  const copy = await request(`IssuedInvoices/${sourceId}/Copy`);
  const draft = mergeChanges(copy, changes);

  return { sourceId, draft, totals: recount ? await recountTotals(draft) : undefined };
}

/**
 * Ask iDoklad to price a draft, and return only the resulting totals.
 *
 * The Recount response reshapes items — `UnitPrice` moves inside a per-item
 * `Prices` object and `Code`, `Unit`, `VatCodeId` and `PriceListItemId` are
 * dropped — so merging its items back into the draft would silently strip the
 * prices from the invoice being created. The items are therefore discarded and
 * the caller keeps its own.
 */
export async function recountTotals(draft) {
  const recounted = await request("IssuedInvoices/Recount", {
    method: "POST",
    body: {
      CurrencyId: draft.CurrencyId,
      DateOfTaxing: draft.DateOfTaxing,
      DiscountPercentage: draft.DiscountPercentage ?? 0,
      ExchangeRate: draft.ExchangeRate,
      ExchangeRateAmount: draft.ExchangeRateAmount,
      HasVatRegimeOss: draft.HasVatRegimeOss ?? false,
      PaymentOptionId: draft.PaymentOptionId,
      Items: (draft.Items ?? []).map((item) => ({
        Id: item.Id,
        Amount: item.Amount,
        DiscountPercentage: item.DiscountPercentage ?? 0,
        IsTaxMovement: item.IsTaxMovement ?? false,
        ItemType: item.ItemType ?? 0,
        Name: item.Name,
        PriceType: item.PriceType,
        UnitPrice: item.UnitPrice,
        VatRate: item.VatRate,
        VatRateType: item.VatRateType,
      })),
    },
  });
  return recounted.Prices;
}

export const createInvoice = (body) => request("IssuedInvoices", { method: "POST", body });

export const updateInvoice = (body) => request("IssuedInvoices", { method: "PATCH", body });

/** Copy → merge → price → save. With `dryRun` the draft is returned unsaved. */
export async function createFromCopy({ sourceInvoiceId, changes, recount = true, dryRun = false } = {}) {
  const { sourceId, draft, totals } = await copyDraft({ sourceInvoiceId, changes, recount });
  if (dryRun) return { sourceId, saved: false, draft, totals };
  return { sourceId, saved: true, invoice: await createInvoice(draft) };
}

/**
 * Download an invoice PDF. The API returns base64 inside the response envelope.
 * @returns absolute path of the written file and its size in bytes.
 */
export async function downloadPdf({ id, path, language = "cs", withPayments = false }) {
  const languageId = REPORT_LANGUAGES[language];
  if (!languageId) throw new Error(`Unknown language "${language}". Use one of: ${Object.keys(REPORT_LANGUAGES).join(", ")}`);

  const endpoint = withPayments ? "PdfWithPayments" : "Pdf";
  const base64 = await request(`Reports/IssuedInvoice/${id}/${endpoint}`, {
    query: { language: languageId, compressed: false },
  });
  if (typeof base64 !== "string") throw new Error(`Unexpected PDF payload for invoice ${id}.`);

  const bytes = Buffer.from(base64, "base64");
  const target = resolve(path);
  await writeFile(target, bytes);
  return { path: target, bytes: bytes.length };
}

export async function listContacts({ query, limit = 20, page = 1 } = {}) {
  const data = await request("Contacts", {
    query: {
      page,
      pagesize: limit,
      filter: query ? `CompanyName~ct~${query}` : undefined,
      sort: "CompanyName~asc",
    },
  });
  return (data.Items ?? []).map((c) => ({
    Id: c.Id,
    CompanyName: c.CompanyName,
    IdentificationNumber: c.IdentificationNumber,
    VatIdentificationNumber: c.VatIdentificationNumber,
    City: c.City,
  }));
}

export const CODEBOOKS = [
  "VatRates",
  "VatCodes",
  "Currencies",
  "PaymentOptions",
  "NumericSequences",
  "ConstantSymbols",
  "Banks",
  "Countries",
];

export async function getCodebook(name) {
  if (!CODEBOOKS.includes(name)) {
    throw new Error(`Unknown codebook "${name}". Available: ${CODEBOOKS.join(", ")}`);
  }
  const data = await request(name, { query: { pagesize: 200, page: 1 } });
  return data.Items ?? data;
}
