/**
 * Czech VAT filings via the iDoklad web app.
 *
 * The REST API v3 exposes no VAT-filing endpoint — its `Reports` group only
 * renders individual documents as PDF, and `Statistics/VatTotals` returns six
 * aggregate numbers. The filings exist only in the web app, under Finance >
 * DPH, so this module drives that screen and lets iDoklad compute the numbers.
 *
 * Session state is persisted so repeated runs skip the login form.
 */

import { mkdir, readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { chromium } from "playwright";

export const VAT_FILINGS = ["kontrolni-hlaseni", "priznani-k-dph", "souhrnne-hlaseni"];

/**
 * Generated unless the caller says otherwise. Souhrnné hlášení is left out: it
 * only applies to cross-border supplies within the EU, so filing it by default
 * would produce a return nobody asked for.
 */
export const DEFAULT_FILINGS = ["kontrolni-hlaseni", "priznani-k-dph"];

/** Label shown in the "Typ výkazu" dropdown for each filing. */
const FILING_LABELS = {
  "kontrolni-hlaseni": "Kontrolní hlášení",
  "priznani-k-dph": "Přiznání k DPH",
  "souhrnne-hlaseni": "Souhrnné hlášení",
};

const MONTH_LABELS = [
  "Leden",
  "Únor",
  "Březen",
  "Duben",
  "Květen",
  "Červen",
  "Červenec",
  "Srpen",
  "Září",
  "Říjen",
  "Listopad",
  "Prosinec",
];

const APP_ORIGIN = "https://app.idoklad.cz";
const LOGIN_URL = `${APP_ORIGIN}/Account/Login`;
const VAT_URL = `${APP_ORIGIN}/VatDeclaration`;

// The screen is built with Kendo UI: the real <select> elements are aria-hidden
// decoys holding a single "[object Object]" option, so selection has to go
// through the widget. These data-ui-id hooks are stable; element ids are not.
const DROPDOWNS = {
  filing: "csw-vat-declaration-dropdown",
  month: "csw-month-dropdown",
  year: "csw-year-dropdown",
};
const SUBMIT = '[data-ui-id="csw-vat-submit"]';
const TOAST = '[data-ui-id="csw-toast-message"]';

const profileDir = () =>
  process.env.IDOKLAD_BROWSER_PROFILE ?? join(homedir(), ".local", "share", "idoklad-mcp", "browser-profile");

function webCredentials() {
  const email = process.env.IDOKLAD_EMAIL;
  const password = process.env.IDOKLAD_PASSWORD;
  if (!email || !password) {
    throw new Error(
      "Missing IDOKLAD_EMAIL / IDOKLAD_PASSWORD. The VAT filings are not in the REST API, so they need the " +
        "web login. Store them in the macOS keychain and export them from ~/.zsh_secrets.",
    );
  }
  return { email, password };
}

/**
 * Open a browser context that is logged in to iDoklad, reusing the persisted
 * profile when its session is still valid.
 */
export async function openSession({ headed = false } = {}) {
  const dir = profileDir();
  await mkdir(dir, { recursive: true });

  const context = await chromium.launchPersistentContext(dir, {
    headless: !headed,
    acceptDownloads: true,
    locale: "cs-CZ",
    timezoneId: "Europe/Prague",
  });
  const page = context.pages()[0] ?? (await context.newPage());

  await page.goto(APP_ORIGIN, { waitUntil: "domcontentloaded" });
  if (page.url().includes("/Account/Login")) await signIn(page);

  return { context, page };
}

async function signIn(page) {
  const { email, password } = webCredentials();
  await page.goto(LOGIN_URL, { waitUntil: "domcontentloaded" });

  // Element ids are regenerated as GUIDs on every render, so match on `name`.
  await page.locator('input[name="UserName"]').fill(email);
  await page.locator('input[name="Password"]').fill(password);
  await page.getByRole("button", { name: "Přihlásit se" }).click();

  await page.waitForURL((url) => !url.pathname.startsWith("/Account/Login"), { timeout: 30_000 }).catch(() => {
    throw new Error(
      "iDoklad login did not complete. Check IDOKLAD_EMAIL / IDOKLAD_PASSWORD, or pass headed=true to watch it.",
    );
  });
}

/** Pick a value in a Kendo dropdown and confirm the widget actually took it. */
async function selectOption(page, dropdown, label) {
  const widget = page.locator(`[data-ui-id="${DROPDOWNS[dropdown]}"]`);
  await widget.click();
  await page.getByRole("option", { name: label, exact: true }).click();

  const shown = (await widget.locator(".k-input-value-text").textContent())?.trim();
  if (shown !== label) {
    throw new Error(`Could not set ${dropdown} to "${label}" — the dropdown still shows "${shown}".`);
  }
}

/**
 * Summarise what a filing actually contains, so an empty period is visible
 * instead of being handed over as a finished return.
 *
 * The two filings are shaped differently and cannot be judged the same way:
 * kontrolní hlášení lists one `VetaA*`/`VetaB*` row per document, whereas
 * přiznání k DPH always carries the form's aggregate boxes `Veta1`–`Veta6`
 * whether or not anything was traded. So `documentRows` is meaningful for
 * kontrolní hlášení only, and `sections` reports the raw truth for both.
 */
function describeContents(xml) {
  // VetaD is the header and VetaP the payer; both are present regardless.
  const tags = [...xml.matchAll(/<(Veta[A-Z0-9]+)\b/g)]
    .map((m) => m[1])
    .filter((tag) => tag !== "VetaD" && tag !== "VetaP");

  const sections = {};
  for (const tag of tags) sections[tag] = (sections[tag] ?? 0) + 1;

  return { sections, documentRows: tags.filter((tag) => /^Veta[AB]\d/.test(tag)).length };
}

async function generateFiling({ page, filing, year, month, outputDir }) {
  const label = FILING_LABELS[filing];
  if (!label) throw new Error(`Unknown filing "${filing}". Use one of: ${VAT_FILINGS.join(", ")}`);

  await page.goto(VAT_URL, { waitUntil: "networkidle" });
  await selectOption(page, "filing", label);
  await selectOption(page, "month", MONTH_LABELS[month - 1]);
  await selectOption(page, "year", String(year));

  const downloadPromise = page.waitForEvent("download", { timeout: 90_000 });
  await page.locator(SUBMIT).click();

  let download;
  try {
    download = await downloadPromise;
  } catch {
    const message = await page.locator(TOAST).first().textContent().catch(() => null);
    throw new Error(
      `iDoklad produced no file for ${label} ${year}-${String(month).padStart(2, "0")}` +
        (message ? `: ${message.trim()}` : ". The page reported nothing; retry with headed=true to watch it."),
    );
  }

  // Downloads arrive without an extension, e.g. "iDoklad_DPHKH_2026M08B".
  const suggested = download.suggestedFilename();
  const filename = /\.xml$/i.test(suggested) ? suggested : `${suggested}.xml`;
  const file = join(outputDir, filename);
  await download.saveAs(file);

  return {
    filing,
    label,
    file,
    ...describeContents(await readFile(file, "utf8")),
    portalUrl: await portalLink(page),
  };
}

/** The toast shown after generating links to the state tax portal. */
async function portalLink(page) {
  const link = page.locator(`${TOAST} a`).first();
  return await link.getAttribute("href", { timeout: 15_000 }).catch(() => null);
}

export async function downloadVatFilings({ year, month, filings = DEFAULT_FILINGS, outputDir, headed = false }) {
  const target = resolve(outputDir.replace(/^~(?=$|\/)/, homedir()));
  await mkdir(target, { recursive: true });

  const { context, page } = await openSession({ headed });
  try {
    const results = [];
    for (const filing of filings) {
      results.push(await generateFiling({ page, filing, year, month, outputDir: target }));
    }
    return {
      period: `${year}-${String(month).padStart(2, "0")}`,
      outputDir: target,
      filings: results,
      // Same for every filing; lifted out so the caller cannot miss it.
      portalUrl: results.find((r) => r.portalUrl)?.portalUrl ?? null,
    };
  } finally {
    await context.close();
  }
}
