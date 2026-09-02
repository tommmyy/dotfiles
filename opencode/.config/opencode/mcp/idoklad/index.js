#!/usr/bin/env node
/**
 * MCP server for iDoklad (idoklad.cz).
 *
 * Two capability groups:
 *   - Issued invoices, over the documented REST API v3.
 *   - Czech VAT filings (kontrolní hlášení, přiznání k DPH), which the REST API
 *     does not expose at all, so they are driven through the iDoklad web app.
 *
 * Credentials come from the environment:
 *   IDOKLAD_CLIENT_ID / IDOKLAD_CLIENT_SECRET  API (Nastavení > Aplikace a API)
 *   IDOKLAD_EMAIL / IDOKLAD_PASSWORD           web login, VAT tools only
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

import {
  CODEBOOKS,
  copyDraft,
  createFromCopy,
  createInvoice,
  downloadPdf,
  getCodebook,
  getInvoice,
  listContacts,
  listInvoices,
  updateInvoice,
} from "./src/invoices.js";
import { DEFAULT_FILINGS, downloadVatFilings, VAT_FILINGS } from "./src/vat.js";

const server = new McpServer({ name: "idoklad", version: "1.0.0" });

/** Render a tool result, reporting failures as tool errors rather than throwing. */
const ok = (value) => ({ content: [{ type: "text", text: JSON.stringify(value, null, 2) }] });
const fail = (error) => ({
  content: [{ type: "text", text: `iDoklad error: ${error.message}` }],
  isError: true,
});
const tool = (handler) => async (args) => {
  try {
    return ok(await handler(args));
  } catch (error) {
    return fail(error);
  }
};

server.registerTool(
  "invoice_list",
  {
    title: "List issued invoices",
    description:
      "List issued invoices (faktury vydané), newest first by default. Use this to find the invoice to copy. " +
      "Returns compact rows; set full=true for complete records.",
    inputSchema: {
      limit: z.number().int().min(1).max(100).default(20).describe("Page size"),
      page: z.number().int().min(1).default(1),
      sort: z.string().default("DateOfIssue~desc").describe('e.g. "DateOfIssue~desc", "DocumentNumber~asc"'),
      filter: z.string().optional().describe('iDoklad filter, e.g. "DateOfIssue~gte~2026-01-01"'),
      filtertype: z.enum(["and", "or"]).optional(),
      full: z.boolean().default(false).describe("Return full invoice objects instead of a summary"),
    },
  },
  tool(listInvoices),
);

server.registerTool(
  "invoice_get",
  {
    title: "Get invoice detail",
    description: "Fetch one issued invoice by its numeric id, with all fields and items.",
    inputSchema: { id: z.number().int().describe("Invoice Id") },
  },
  tool(({ id }) => getInvoice(id)),
);

server.registerTool(
  "invoice_copy_draft",
  {
    title: "Preview a copy of an invoice",
    description:
      "Build an unsaved new-invoice payload by copying an existing invoice and applying changes. " +
      "Omit sourceInvoiceId to copy the most recently issued invoice. Nothing is written to iDoklad; " +
      "use this to show the user what would be created before calling invoice_create_from_copy.",
    inputSchema: {
      sourceInvoiceId: z.number().int().optional().describe("Invoice to copy; defaults to the latest one"),
      changes: z
        .record(z.any())
        .optional()
        .describe(
          "Fields to override on the copy. Objects merge recursively; arrays and scalars replace wholesale, " +
            "so passing Items replaces the whole item list. null deletes a key.",
        ),
      recount: z.boolean().default(true).describe("Recalculate totals via the API after applying changes"),
    },
  },
  tool(copyDraft),
);

server.registerTool(
  "invoice_create_from_copy",
  {
    title: "Create an invoice by copying another",
    description:
      "Copy an existing invoice (the latest one unless sourceInvoiceId is given), apply changes, recount " +
      "totals, and save it as a new issued invoice. Set dryRun=true to get the draft back without saving.",
    inputSchema: {
      sourceInvoiceId: z.number().int().optional(),
      changes: z.record(z.any()).optional().describe("Same merge semantics as invoice_copy_draft"),
      recount: z.boolean().default(true),
      dryRun: z.boolean().default(false),
    },
  },
  tool(createFromCopy),
);

server.registerTool(
  "invoice_create",
  {
    title: "Create an invoice from a full payload",
    description:
      "Create an issued invoice from a complete request body. Prefer invoice_create_from_copy for the " +
      "copy-and-edit workflow; use this when building an invoice from scratch.",
    inputSchema: { invoice: z.record(z.any()).describe("Full POST /IssuedInvoices body") },
  },
  tool(({ invoice }) => createInvoice(invoice)),
);

server.registerTool(
  "invoice_update",
  {
    title: "Update an invoice",
    description: "Partially update an existing issued invoice. The payload must include its Id.",
    inputSchema: {
      invoice: z.record(z.any()).describe("PATCH /IssuedInvoices body, including Id"),
    },
  },
  tool(({ invoice }) => updateInvoice(invoice)),
);

server.registerTool(
  "invoice_pdf",
  {
    title: "Download invoice PDF",
    description: "Download an issued invoice as PDF and write it to the given path. Returns the absolute path.",
    inputSchema: {
      id: z.number().int(),
      path: z.string().describe("Destination file path for the PDF"),
      language: z.enum(["cs", "sk", "en", "de"]).default("cs"),
      withPayments: z.boolean().default(false).describe("Include the payment overview variant"),
    },
  },
  tool(downloadPdf),
);

server.registerTool(
  "contact_list",
  {
    title: "List contacts",
    description: "List or search contacts (odběratelé), to resolve a PartnerId for an invoice.",
    inputSchema: {
      query: z.string().optional().describe("Substring match on company name"),
      limit: z.number().int().min(1).max(100).default(20),
      page: z.number().int().min(1).default(1),
    },
  },
  tool(listContacts),
);

server.registerTool(
  "codebook",
  {
    title: "Read a codebook",
    description:
      `Read an iDoklad codebook to resolve ids used on invoices. One of: ${CODEBOOKS.join(", ")}.`,
    inputSchema: { name: z.enum(CODEBOOKS) },
  },
  tool(({ name }) => getCodebook(name)),
);

server.registerTool(
  "vat_filings_download",
  {
    title: "Download VAT filings (kontrolní hlášení, přiznání k DPH)",
    description:
      "Generate and download the Czech VAT filings for one month as XML, and return their paths plus the " +
      "daňový portál link for uploading them. The REST API has no endpoint for this, so it drives the " +
      "iDoklad web app and needs IDOKLAD_EMAIL / IDOKLAD_PASSWORD. Each result reports `documentRows`: for " +
      "kontrolní hlášení, 0 means iDoklad found no documents in that period.",
    inputSchema: {
      year: z.number().int().min(2000).max(2100).describe("Filing year, e.g. 2026"),
      month: z.number().int().min(1).max(12).describe("Filing month, 1-12"),
      filings: z
        .array(z.enum(VAT_FILINGS))
        .default([...DEFAULT_FILINGS])
        .describe("Which filings to generate; souhrnné hlášení is opt-in as it only covers EU supplies"),
      outputDir: z.string().describe("Directory to write the downloaded XML files into"),
      headed: z.boolean().default(false).describe("Show the browser window, for debugging"),
    },
  },
  tool(downloadVatFilings),
);

await server.connect(new StdioServerTransport());
