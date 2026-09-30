#!/usr/bin/env node
// eListek (elistek.cz) meal orders: read status, preview/submit changes, verify.
//
// Usage:
//   elistek.mjs status  KID [--json]
//   elistek.mjs history KID
//   elistek.mjs set     KID CHOICE DATE [DATE ...] [--submit] [--force]
//   elistek.mjs verify  KID CHOICE DATE [DATE ...] [--timeout SEC] [--interval SEC]
//
// CHOICE: off | on | nosnack | a raw option code from `status` (A, B, 0, 1, ...)
// DATE:   2026-09-30 | 30.9. | 30.9.2026 | streda | zitra

import { writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { setTimeout as sleep } from "node:timers/promises";
import { die, findKid, fold, resolveDate, secret } from "./kids.mjs";

const BASE = "http://www.elistek.cz/elistek";
const ENCODING = "windows-1250";
const DEADLINE_HOUR = 11;
const UA = "Mozilla/5.0 home-kids";

const decoder = new TextDecoder(ENCODING);
// The form is windows-1250, so the POST body must be too; build the reverse map from the decoder.
const CP1250 = new Map(
  Array.from({ length: 128 }, (_, i) => [decoder.decode(Uint8Array.of(i + 128)), i + 128]),
);

const encodeCp1250 = (text) =>
  [...text]
    .map((ch) => {
      if (/[A-Za-z0-9*\-._]/.test(ch)) return ch;
      if (ch === " ") return "+";
      const byte = ch.charCodeAt(0) < 128 ? ch.charCodeAt(0) : CP1250.get(ch);
      if (byte === undefined) die(`cannot encode '${ch}' as ${ENCODING}`);
      return `%${byte.toString(16).toUpperCase().padStart(2, "0")}`;
    })
    .join("");

const decodeEntities = (s) =>
  s
    .replace(/&nbsp;/g, " ")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&amp;/g, "&");

export const stripTags = (fragment) =>
  decodeEntities(fragment.replace(/<[^>]+>/g, " ")).replace(/\s+/g, " ").trim();

const attrs = (text) => Object.fromEntries([...text.matchAll(/(\w+)\s*=\s*"([^"]*)"/g)].map((m) => [m[1].toLowerCase(), m[2]]));

export async function fetchPage(url) {
  const res = await fetch(`${url}?t=${Date.now()}`, { headers: { "Cache-Control": "no-cache", "User-Agent": UA } });
  if (!res.ok) die(`GET ${url} -> HTTP ${res.status}; login code probably wrong (case-sensitive, no spaces)`);
  return decoder.decode(await res.arrayBuffer());
}

export function pageUrl(kid, suffix = "") {
  const meals = kid.meals ?? die(`${kid.name} has no meals config`);
  if (meals.provider !== "elistek") die(`${kid.name} meals provider is ${meals.provider}, not elistek`);
  return `${BASE}/${meals.canteen_id}/users/${secret(meals.code_env)}${suffix}.htm`;
}

function parse(page, url) {
  if (page.includes("Přihlašovací kód") || !page.includes("<form")) {
    die("login code rejected or page missing; check the env var value (case-sensitive, no spaces)");
  }
  const action = page.match(/<form[^>]*action="([^"]+)"/i)?.[1];
  const hidden = [...page.matchAll(/<input\b([^>]*)>/gi)]
    .map((m) => attrs(m[1]))
    .filter((a) => a.type?.toLowerCase() === "hidden")
    .map((a) => [a.name, decodeEntities(a.value ?? "")]);

  const rowRe = /<tr valign="top"[^>]*>\s*<td>\s*(\d{2})\.(\d{2})\.(\d{4})\s*<\/td>\s*<td>\s*([^<]*?)\s*<\/td>([\s\S]*?)<\/tr>\s*<\/table>\s*<\/td>\s*<\/tr>/gi;
  const days = [...page.matchAll(rowRe)].map(([, dd, mm, yyyy, weekday, body]) => {
    let group = null;
    const options = [...body.matchAll(/<input\b([^>]*)>([^<]*)/gi)]
      .filter((m) => attrs(m[1]).type?.toLowerCase() === "radio")
      .map((m) => {
        const a = attrs(m[1]);
        group = a.name;
        const code = a.value.slice(8);
        // Once a day is cancelled, the page leaves the checked "0" option without a label.
        const label = stripTags(m[2]) || (code === "0" ? "odhlásit" : code);
        return { value: a.value, code, label, checked: /\bchecked\b/i.test(m[1]) };
      });
    const menuHtml = body.split("<input")[0];
    return {
      date: `${yyyy}-${mm}-${dd}`,
      weekday: weekday.trim(),
      menu: menuHtml.split(/<\/tr>/i).map(stripTags).filter((s) => s && s !== "-"),
      group,
      options,
    };
  });

  return {
    url,
    action: action ? new URL(action, url).href : null,
    hidden,
    credit: page.match(/Zbývá kredit:\s*([^<]*)/)?.[1].trim() ?? null,
    generated: page.match(/\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2}/)?.[0] ?? null,
    days,
  };
}

export const load = async (kid) => {
  const url = pageUrl(kid);
  return parse(await fetchPage(url), url);
};

export const current = (day) => day.options.find((o) => o.checked) ?? null;
export const isOff = (o) => o.code === "0" || fold(o.label).startsWith("odhlas");

/** Map an intent or raw code to exactly one option of this day. */
function pick(day, choice) {
  const opts = day.options;
  const c = fold(choice);
  let found;
  if (["off", "odhlasit", "0"].includes(c)) found = opts.filter(isOff);
  else if (["on", "prihlasit", "full"].includes(c)) {
    found = opts.filter((o) => fold(o.label) === "cely den");
    if (!found.length) found = opts.filter((o) => !isOff(o)).slice(0, 1);
  } else if (["nosnack", "bez svaciny"].includes(c)) {
    found = opts.filter((o) => fold(o.label).includes("obed") && !fold(o.label).includes("svacin") && !isOff(o));
  } else {
    found = opts.filter((o) => fold(o.code) === c);
    if (!found.length) found = opts.filter((o) => fold(o.label).includes(c));
  }
  if (found.length !== 1) {
    const labels = opts.map((o) => `${o.code}=${o.label}`).join(", ");
    die(`choice '${choice}' does not match one option on ${day.date} (options: ${labels})`);
  }
  return found[0];
}

/** Orders close at 11:00 on the previous calendar day. */
function deadline(isoDay) {
  const [y, m, d] = isoDay.split("-").map(Number);
  return new Date(y, m - 1, d - 1, DEADLINE_HOUR);
}

const fmtDeadline = (d) => `${d.getDate()}.${d.getMonth() + 1}. ${String(d.getHours()).padStart(2, "0")}:00`;

async function cmdStatus(kid, opts) {
  const state = await load(kid);
  if (opts.json) {
    const { hidden, ...rest } = state;
    console.log(JSON.stringify(rest, null, 2));
    return;
  }
  console.log(`${kid.name} (${kid.facility})  kredit: ${state.credit}  stránka vytvořena: ${state.generated}`);
  if (!state.days.length) console.log("  no orderable days on the page right now");
  for (const day of state.days) {
    const opts2 = day.options.map((o) => `${o.code}=${o.label}`).join(" | ");
    console.log(`  ${day.date} ${day.weekday}: ${current(day)?.label ?? "nic"}   [${opts2}]`);
    for (const line of day.menu) console.log(`      ${line}`);
  }
}

async function cmdHistory(kid) {
  console.log(stripTags(await fetchPage(pageUrl(kid, "_H"))));
}

function planChanges(state, choice, dates) {
  const byDate = Object.fromEntries(state.days.map((d) => [d.date, d]));
  const changes = [];
  const problems = [];
  for (const token of dates) {
    const date = resolveDate(token);
    const day = byDate[date];
    if (!day) {
      problems.push(`${date} is not on the page (orderable days now: ${Object.keys(byDate).join(", ") || "none"})`);
      continue;
    }
    changes.push({ day, from: current(day), to: pick(day, choice), late: new Date() > deadline(date) });
  }
  return { changes, problems };
}

async function cmdSet(kid, opts, choice, dates) {
  const state = await load(kid);
  const { changes, problems } = planChanges(state, choice, dates);
  console.log(`${kid.name} (${kid.facility}), stránka vytvořena ${state.generated}`);
  for (const c of changes) {
    const note = c.from === c.to ? "  (beze změny)" : "";
    const late = c.late ? `  ! po uzávěrce ${fmtDeadline(deadline(c.day.date))}` : "";
    console.log(`  ${c.day.date} ${c.day.weekday}: ${c.from?.label ?? "nic"} -> ${c.to.label}${note}${late}`);
  }
  for (const p of problems) console.log(`  ! ${p}`);
  if (problems.length) process.exit(3);
  if (changes.every((c) => c.from === c.to)) {
    console.log("nothing to change");
    return;
  }
  if (changes.some((c) => c.late) && !opts.force) {
    console.log("past the 11:00 deadline of the previous day; the canteen will likely reject it (use --force to send anyway)");
    if (opts.submit) process.exit(4);
  }
  if (!opts.submit) {
    console.log("PREVIEW ONLY - nothing sent. Re-run with --submit after the user confirms.");
    return;
  }

  // Mirror what the browser sends: hidden fields, one checked value per day, the clicked button.
  const targets = Object.fromEntries(changes.map((c) => [c.day.group, c.to.value]));
  const fields = [...state.hidden];
  for (const day of state.days) {
    const value = targets[day.group] ?? current(day)?.value;
    if (value) fields.push([day.group, value]);
  }
  fields.push(["submit3", "Potvrdit a odeslat změny"]);
  const body = fields.map(([k, v]) => `${encodeCp1250(k)}=${encodeCp1250(v)}`).join("&");

  const res = await fetch(state.action, {
    method: "POST",
    body,
    headers: { "Content-Type": "application/x-www-form-urlencoded", Referer: state.url, "User-Agent": UA },
  });
  // The server answers "probiha odesilani emailu se zmenami" and then sends the browser on to ok.htm.
  const reply = decoder.decode(await res.arrayBuffer());
  if (!res.ok || !(fold(reply).includes("odesilani") || fold(reply).includes("odeslany") || res.url.endsWith("ok.htm"))) {
    const dump = join(tmpdir(), `elistek-reply-${Date.now()}.html`);
    writeFileSync(dump, reply);
    die(`unexpected reply from ${res.url} (HTTP ${res.status}), saved to ${dump}: ${stripTags(reply).slice(0, 300)}; do NOT resubmit before checking the page`);
  }
  console.log(
    `SENT to canteen at ${new Date().toLocaleTimeString("cs-CZ")}. Applied when the canteen PC regenerates the page (minutes to tens of minutes).`,
  );

  // The calendar follows the submitted state right away; the daily sync corrects it if the canteen rejects.
  const { markNoMeal, calendarConfigured } = await import("./mealcal.mjs");
  if (!calendarConfigured()) {
    console.log("calendar: not configured (FAMILY_GCAL_* unset), skipped");
    return;
  }
  try {
    for (const c of changes.filter((c) => c.from !== c.to)) {
      await markNoMeal(kid, c.day.date, isOff(c.to));
      console.log(`calendar: ${c.day.date} ${isOff(c.to) ? "bez oběda - přidáno" : "má oběd - odebráno"}`);
    }
  } catch (err) {
    console.log(`calendar: update failed (${err.message}); the daily sync will retry`);
  }
}

/** Month history as date -> code: "A"/"B"/"1" ordered, "V" served, "" or "0" nothing, "*" closed. */
export async function historyCodes(kid) {
  const text = stripTags(await fetchPage(pageUrl(kid, "_H")));
  return new Map(
    [...text.matchAll(/(\d{2})\.(\d{2})\.(\d{4}):\s*\[\s*([^\]]*?)\s*\]/g)].map(([, dd, mm, yyyy, code]) => [`${yyyy}-${mm}-${dd}`, code]),
  );
}

/** Whether the canteen shows the requested state for a date: true, false, or null when it can't tell. */
function confirmed(day, historyCode, choice) {
  if (day) return current(day) === pick(day, choice);
  if (historyCode === undefined) return null;
  const off = historyCode === "" || historyCode === "0";
  const c = fold(choice);
  if (["off", "odhlasit", "0"].includes(c)) return off;
  if (["on", "prihlasit", "full"].includes(c)) return !off && historyCode !== "*";
  return fold(historyCode) === c;
}

async function cmdVerify(kid, opts, choice, dates) {
  const end = Date.now() + Number(opts.timeout) * 1000;
  const wanted = dates.map((token) => resolveDate(token));
  for (;;) {
    const state = await load(kid);
    const byDate = Object.fromEntries(state.days.map((d) => [d.date, d]));
    // Past the deadline a day drops off the main page; the history then has the final word.
    const history = wanted.some((date) => !byDate[date]) ? await historyCodes(kid) : new Map();
    const results = wanted.map((date) => [date, confirmed(byDate[date], history.get(date), choice)]);
    const pending = results.filter(([, ok]) => ok !== true).map(([date, ok]) => (ok === null ? `${date} (unknown)` : date));
    if (!pending.length) {
      console.log(`OK: canteen shows the requested state (page generated ${state.generated})`);
      return;
    }
    if (Date.now() >= end) {
      console.log(`NOT CONFIRMED: ${pending.join(", ")} (page generated ${state.generated}); check the history or call the canteen`);
      process.exit(5);
    }
    await sleep(Number(opts.interval) * 1000);
  }
}

if (import.meta.main) {
  const { values: opts, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      json: { type: "boolean" },
      submit: { type: "boolean" },
      force: { type: "boolean" },
      timeout: { type: "string", default: "900" },
      interval: { type: "string", default: "60" },
    },
  });
  const [cmd, kidName, choice, ...dates] = positionals;
  const commands = { status: cmdStatus, history: cmdHistory, set: cmdSet, verify: cmdVerify };
  if (!commands[cmd] || !kidName || ((cmd === "set" || cmd === "verify") && (!choice || !dates.length))) {
    die("usage: elistek.mjs status|history KID  |  set|verify KID CHOICE DATE... [--submit] [--force]");
  }
  const [key, kid] = findKid(kidName);
  await commands[cmd]({ ...kid, key }, opts, choice, dates);
}
