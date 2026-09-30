#!/usr/bin/env node
// Judo absences ("omluvenky") in the club's shared Google Sheet.
//
// Usage:
//   judo.mjs status KID [DATE]            absences in the kid's group on DATE (default: next training)
//   judo.mjs plan   KID DATE REASON       preview: target cell + Playwright code for the write
//   judo.mjs verify KID DATE REASON       re-read the sheet, check the write, add the calendar event
//
// The sheet is anyone-with-link editable, and all parents write into it. Reading
// goes through the xlsx export; writing goes through the Playwright MCP with the
// code `plan` prints. Nothing here ever clears or overwrites a cell.

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { setTimeout as sleep } from "node:timers/promises";
import { calendarConfigured, eventId, upsertEvent } from "../../_lib/gcal.mjs";
import { addDaysIso, parseIso } from "../../_lib/dates.mjs";
import { die, findKid, fold, resolveDate, todayIso } from "./kids.mjs";

const SOURCE = "personal-kids-judo";
const MONTHS = ["leden", "unor", "brezen", "duben", "kveten", "cerven", "cervenec", "srpen", "zari", "rijen", "listopad", "prosinec"];
const WEEKDAY = ["ne", "po", "út", "st", "čt", "pá", "so"];

const decodeXml = (s) =>
  s
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&amp;/g, "&");

const attrs = (text) => Object.fromEntries([...text.matchAll(/([\w:]+)="([^"]*)"/g)].map((m) => [m[1], decodeXml(m[2])]));
const texts = (xml) => [...xml.matchAll(/<t(?:\s[^>]*)?>([\s\S]*?)<\/t>/g)].map((m) => decodeXml(m[1])).join("");

const colNum = (letters) => [...letters].reduce((n, ch) => n * 26 + ch.charCodeAt(0) - 64, 0);
const colName = (n) => (n > 26 ? colName(Math.floor((n - 1) / 26)) : "") + String.fromCharCode(65 + ((n - 1) % 26));
const splitRef = (ref) => {
  const m = ref.match(/^([A-Z]+)(\d+)$/);
  return { col: colNum(m[1]), row: Number(m[2]) };
};

/** Download the workbook as xlsx; Google sometimes answers the export with a 502 page, so retry. */
async function download(sheetId) {
  const file = join(tmpdir(), `kids-judo-${sheetId}.xlsx`);
  for (let attempt = 1; attempt <= 4; attempt++) {
    const res = await fetch(`https://docs.google.com/spreadsheets/d/${sheetId}/export?format=xlsx`);
    const buf = Buffer.from(await res.arrayBuffer());
    if (res.ok && buf.subarray(0, 2).toString() === "PK") {
      writeFileSync(file, buf);
      return file;
    }
    await sleep(3000 * attempt);
  }
  die("sheet export failed 4 times (HTTP error or not an xlsx); try again in a minute");
}

const unzip = (file, path) => execFileSync("unzip", ["-p", file, path], { encoding: "utf8", maxBuffer: 64 << 20 });

/** -> [{name, cells: Map(ref -> text), merges: [{c1, r1, c2, r2}]}] */
async function loadWorkbook(sheetId) {
  const file = await download(sheetId);
  let shared = [];
  try {
    shared = [...unzip(file, "xl/sharedStrings.xml").matchAll(/<si>([\s\S]*?)<\/si>/g)].map((m) => texts(m[1]));
  } catch {
    // A workbook without text cells has no sharedStrings.xml.
  }
  const rels = Object.fromEntries(
    [...unzip(file, "xl/_rels/workbook.xml.rels").matchAll(/<Relationship\b([^>]*)\/?>/g)].map((m) => {
      const a = attrs(m[1]);
      return [a.Id, a.Target.replace(/^\/?xl\//, "")];
    }),
  );
  return [...unzip(file, "xl/workbook.xml").matchAll(/<sheet\b([^>]*)\/?>/g)].map((m) => {
    const a = attrs(m[1]);
    const xml = unzip(file, `xl/${rels[a["r:id"]]}`);
    const cells = new Map();
    for (const c of xml.matchAll(/<c\b([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g)) {
      const ca = attrs(c[1]);
      const body = c[2] ?? "";
      const v = body.match(/<v>([\s\S]*?)<\/v>/)?.[1];
      let value = null;
      if (ca.t === "s" && v !== undefined) value = shared[Number(v)];
      else if (ca.t === "inlineStr") value = texts(body);
      else if (v !== undefined) value = decodeXml(v);
      if (value !== null && String(value).trim() !== "") cells.set(ca.r, String(value));
    }
    const merges = [...xml.matchAll(/<mergeCell ref="([A-Z]+\d+):([A-Z]+\d+)"/g)].map((mm) => {
      const a1 = splitRef(mm[1]);
      const a2 = splitRef(mm[2]);
      return { c1: a1.col, r1: a1.row, c2: a2.col, r2: a2.row };
    });
    return { name: a.name, cells, merges };
  });
}

const monthTab = (book, date) => {
  const month = MONTHS[Number(date.slice(5, 7)) - 1];
  const tab = book.find((s) => fold(s.name).split(/[^a-z]+/).includes(month));
  if (!tab) die(`no tab for ${month} (tabs: ${book.map((s) => s.name).join(", ")}); the club may not have added it yet`);
  return tab;
};

const inMerge = (tab, col, row) => tab.merges.find((m) => col >= m.c1 && col <= m.c2 && row >= m.r1 && row <= m.r2);

/**
 * The block of cells for one group and day: the group header in row 1 spans its
 * columns (merged, e.g. I1:J1), and column B holds the day number on each row of the day.
 */
function dayBlock(tab, group, date) {
  const header = [...tab.cells].find(([ref, text]) => splitRef(ref).row === 1 && fold(text) === fold(group));
  if (!header) die(`group '${group}' not found in row 1 of '${tab.name}'`);
  const { col } = splitRef(header[0]);
  const hm = inMerge(tab, col, 1);
  const cols = hm ? Array.from({ length: hm.c2 - hm.c1 + 1 }, (_, i) => hm.c1 + i) : [col];
  const day = Number(date.slice(8, 10));
  const rows = [...tab.cells]
    .filter(([ref, text]) => splitRef(ref).col === 2 && Number(text) === day)
    .map(([ref]) => splitRef(ref).row)
    .sort((a, b) => a - b);
  if (!rows.length) die(`day ${day} not found in column B of '${tab.name}'`);
  const cells = cols.flatMap((c) => rows.map((r) => `${colName(c)}${r}`));
  const open = cells.filter((ref) => {
    const { col: c, row: r } = splitRef(ref);
    return !inMerge(tab, c, r);
  });
  return { cells, open, rows };
}

function judoOf(name) {
  const [key, kid] = findKid(name);
  if (!kid.judo) die(`${kid.name} has no judo block in config.json`);
  return { key, kid, judo: kid.judo };
}

const training = (judo, date) => judo.trainings[String(parseIso(date).getDay())];

function nextTraining(judo) {
  for (let i = 0; i < 14; i++) {
    const d = addDaysIso(todayIso(), i);
    if (training(judo, d)) return d;
  }
  die("no training day configured");
}

const dayLabel = (date) => `${date} ${WEEKDAY[parseIso(date).getDay()]}`;
const snapshotFile = (key, date) => join(tmpdir(), `kids-judo-${key}-${date}.json`);
const entryText = (judo, reason) => `${judo.entry_name} - ${reason.trim()}`;
const listedAt = (tab, cells, judo) => {
  const surname = fold(judo.entry_name.split(" ").at(-1));
  return cells.find((ref) => fold(tab.cells.get(ref) ?? "").includes(surname));
};

async function cmdStatus(args) {
  const { judo } = judoOf(args[0] ?? die("status needs KID"));
  const date = args[1] ? resolveDate(args[1]) : nextTraining(judo);
  const tab = monthTab(await loadWorkbook(judo.sheet_id), date);
  const { cells, open } = dayBlock(tab, judo.group, date);
  const entries = cells.filter((ref) => tab.cells.has(ref));
  console.log(`${judo.group} ${dayLabel(date)} ('${tab.name}'): ${entries.length} omluvených${training(judo, date) ? "" : " (not a training day for this kid)"}`);
  for (const ref of entries) console.log(`  ${ref}: ${tab.cells.get(ref)}`);
  if (!open.length) console.log("  (block is merged: no training for this group that day)");
}

async function cmdPlan(args) {
  const [name, dateToken, ...reasonWords] = args;
  if (!name || !dateToken || !reasonWords.length) die("plan needs KID DATE REASON");
  const { key, kid, judo } = judoOf(name);
  const date = resolveDate(dateToken);
  if (date < todayIso()) die(`${dayLabel(date)} is in the past`);
  if (!training(judo, date)) die(`${dayLabel(date)} is not a training day for ${kid.name} (days: ${Object.keys(judo.trainings).map((d) => WEEKDAY[d]).join(", ")})`);
  const tab = monthTab(await loadWorkbook(judo.sheet_id), date);
  const { cells, open } = dayBlock(tab, judo.group, date);
  if (!open.length) die(`${judo.group} has no training on ${dayLabel(date)} in the sheet (block is merged)`);
  const already = listedAt(tab, cells, judo);
  if (already) die(`already listed: ${already} = '${tab.cells.get(already)}'`);
  const target = open.find((ref) => !tab.cells.has(ref));
  if (!target) die(`all ${open.length} cells for ${dayLabel(date)} are taken; ask the user where to write`);
  const text = entryText(judo, reasonWords.join(" "));
  writeFileSync(snapshotFile(key, date), JSON.stringify({ tab: tab.name, target, text, cells: Object.fromEntries(tab.cells) }));

  console.log(`PLAN ${kid.name}: ${judo.group}, ${dayLabel(date)}, trénink ${training(judo, date)}`);
  console.log(`  tab '${tab.name}', rows ${cells.map((r) => splitRef(r).row).filter((r, i, a) => a.indexOf(r) === i).join(",")}`);
  for (const ref of cells.filter((r) => tab.cells.has(r))) console.log(`  keep ${ref}: ${tab.cells.get(ref)}`);
  console.log(`  write ${target}: ${text}`);
  console.log(`  calendar: '${kid.name.split(" ")[0]} nemá judo' ${date} ${training(judo, date)}`);
  console.log("PREVIEW ONLY - nothing written. After the user confirms, run this with playwright browser_run_code_unsafe");
  console.log(`(after browser_navigate to https://docs.google.com/spreadsheets/d/${judo.sheet_id}/edit), then judo.mjs verify:`);
  console.log(playwrightCode(tab.name, target, text));
}

/** Playwright MCP code that writes one empty cell and refuses if it isn't empty. */
function playwrightCode(tabName, target, text) {
  return `async (page) => {
  const tab = ${JSON.stringify(tabName)}, ref = ${JSON.stringify(target)}, text = ${JSON.stringify(text)};
  await page.getByRole('button', { name: tab, exact: true }).click();
  const nameBox = page.locator('#t-name-box');
  const formula = page.locator('#t-formula-bar-input .cell-input');
  const go = async () => { await nameBox.click(); await nameBox.fill(ref); await nameBox.press('Enter'); await page.waitForTimeout(700); return (await formula.innerText()).trim(); };
  const before = await go();
  if (before !== '') return { aborted: true, reason: ref + ' is not empty', before };
  await page.keyboard.type(text);
  await page.keyboard.press('Enter');
  await page.waitForTimeout(3000);
  return { written: ref, after: await go() };
}`;
}

async function cmdVerify(args, opts) {
  const [name, dateToken] = args;
  if (!name || !dateToken) die("verify needs KID DATE");
  const { key, kid, judo } = judoOf(name);
  const date = resolveDate(dateToken);
  const file = snapshotFile(key, date);
  if (!existsSync(file)) die(`no plan snapshot at ${file}; run plan first`);
  const plan = JSON.parse(readFileSync(file, "utf8"));
  const deadline = Date.now() + Number(opts.timeout ?? 120) * 1000;
  let tab;
  for (;;) {
    tab = (await loadWorkbook(judo.sheet_id)).find((s) => s.name === plan.tab);
    if (!tab) die(`tab '${plan.tab}' disappeared`);
    if (tab.cells.get(plan.target) === plan.text) break;
    if (Date.now() > deadline) die(`${plan.target} = '${tab.cells.get(plan.target) ?? ""}', expected '${plan.text}'`, 1);
    await sleep(10_000);
  }
  const changed = Object.entries(plan.cells).filter(([ref, text]) => tab.cells.get(ref) !== text);
  console.log(`OK ${plan.tab}!${plan.target} = '${plan.text}'`);
  if (changed.length) {
    console.log(`WARNING: ${changed.length} previously filled cell(s) differ now (another parent, or our write went wrong):`);
    for (const [ref, text] of changed) console.log(`  ${ref}: '${text}' -> '${tab.cells.get(ref) ?? ""}'`);
  } else console.log(`other entries unchanged (${Object.keys(plan.cells).length} cells checked)`);

  if (!calendarConfigured()) return console.log("calendar: skipped, FAMILY_GCAL_* not set");
  const [start, end] = training(judo, date).split("-");
  try {
    await upsertEvent(eventId(`${SOURCE}:${key}:${date}`), {
      summary: `${kid.name.split(" ")[0]} nemá judo`,
      description: `Omluvena v tabulce judo (${judo.group}): ${plan.text}`,
      start: { dateTime: `${date}T${start}:00`, timeZone: "Europe/Prague" },
      end: { dateTime: `${date}T${end}:00`, timeZone: "Europe/Prague" },
      transparency: "transparent",
      reminders: { useDefault: false },
      extendedProperties: { private: { source: SOURCE, kid: key } },
    });
    console.log(`calendar: added '${kid.name.split(" ")[0]} nemá judo' ${dayLabel(date)} ${start}-${end}`);
  } catch (err) {
    console.log(`calendar: update failed (${err.message})`);
  }
}

const { values: opts, positionals } = parseArgs({
  allowPositionals: true,
  options: { timeout: { type: "string" } },
});
const [cmd, ...args] = positionals;
const commands = { status: cmdStatus, plan: cmdPlan, verify: cmdVerify };
if (!commands[cmd]) die("usage: judo.mjs status|plan|verify ... (see header)");
await commands[cmd](args, opts);
