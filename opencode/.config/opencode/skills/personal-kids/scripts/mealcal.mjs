#!/usr/bin/env node
// Mirror "no meal ordered" school days from eListek into the family Google Calendar.
//
// Usage:
//   mealcal.mjs sync [KID ...] [--dry-run]
//
// One all-day event "<Name> nemá oběd" per kid and school day from today on
// where eListek has no meal ordered. Events are tagged with private extended
// properties, so the sync only ever touches its own events.

import { parseArgs } from "node:util";
import { current, historyCodes, isOff, load } from "./elistek.mjs";
import {
  calendarConfigured,
  deleteEvent,
  eventId,
  listEvents,
  upsertEvent,
} from "../../personal-family-calendar/scripts/gcal.mjs";
import { instant } from "../../personal-family-calendar/scripts/dates.mjs";
import { die, findKid, isSchoolDay, loadConfig, todayIso } from "./kids.mjs";

export { calendarConfigured };

const SOURCE = "personal-kids-meal";

const firstName = (kid) => kid.name.split(" ")[0];
const idFor = (kid, date) => eventId(`${SOURCE}:${kid.key}:${date}`);

function eventFor(kid, date) {
  const [y, m, d] = date.split("-").map(Number);
  return {
    summary: `${firstName(kid)} nemá oběd`,
    description: `V eListku (${kid.facility}) není na tento den objednané jídlo.`,
    start: { date },
    end: { date: new Date(Date.UTC(y, m - 1, d + 1)).toISOString().slice(0, 10) },
    transparency: "transparent",
    reminders: { useDefault: false },
    extendedProperties: { private: { source: SOURCE, kid: kid.key } },
  };
}

/** Add (noMeal=true) or remove the event for one kid and day. */
export async function markNoMeal(kid, date, noMeal) {
  if (noMeal) await upsertEvent(idFor(kid, date), eventFor(kid, date));
  else await deleteEvent(idFor(kid, date));
}

/**
 * Meal state per school day from today on: true = no meal.
 * The orderable days on the main page are authoritative; the month history covers the rest.
 * History codes: [A]/[1]/[V] ordered or served, [ ] or [0] nothing ordered, [*] canteen closed.
 */
export async function noMealDays(kid) {
  const today = todayIso();
  const days = new Map();
  for (const [date, code] of await historyCodes(kid)) {
    if (date < today || !isSchoolDay(date) || code === "*") continue;
    days.set(date, code === "" || code === "0");
  }
  const page = await load(kid);
  for (const day of page.days) {
    if (day.date < today || !isSchoolDay(day.date)) continue;
    const chosen = current(day);
    days.set(day.date, !chosen || isOff(chosen));
  }
  return { days, generated: parseGenerated(page.generated) };
}

/** "28.09.2026 11:02:56" (local) -> Date. */
function parseGenerated(text) {
  const m = text?.match(/(\d{2})\.(\d{2})\.(\d{4}) (\d{2}):(\d{2}):(\d{2})/);
  return m ? new Date(m[3], m[2] - 1, m[1], m[4], m[5], m[6]) : null;
}

export async function syncKid(kid, { dryRun = false } = {}) {
  const { days, generated } = await noMealDays(kid);
  const existing = new Map(
    (await listEvents({ tags: { source: SOURCE, kid: kid.key }, timeMin: instant(todayIso()) }))
      .filter((e) => e.status !== "cancelled")
      .map((e) => [e.start?.date, new Date(e.updated)]),
  );
  const actions = [];
  for (const [date, noMeal] of [...days].sort()) {
    if (noMeal && !existing.has(date)) actions.push([date, true]);
    if (!noMeal && existing.has(date)) {
      // A cancel submitted after the page was generated isn't on the page yet; keep its event.
      if (!generated || existing.get(date) > generated) {
        console.log(`${firstName(kid)} ${date}: keep 'nemá oběd' (canteen page from ${generated?.toLocaleString("cs-CZ") ?? "?"} predates it)`);
        continue;
      }
      actions.push([date, false]);
    }
  }
  for (const [date, noMeal] of actions) {
    console.log(`${dryRun ? "[dry-run] " : ""}${firstName(kid)} ${date}: ${noMeal ? "add 'nemá oběd'" : "remove 'nemá oběd'"}`);
    if (!dryRun) await markNoMeal(kid, date, noMeal);
  }
  if (!actions.length) console.log(`${firstName(kid)}: calendar up to date (${days.size} school days checked)`);
}

if (import.meta.main) {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: { "dry-run": { type: "boolean" } },
  });
  const [cmd, ...names] = positionals;
  if (cmd !== "sync") die("usage: mealcal.mjs sync [KID ...] [--dry-run]");
  if (!calendarConfigured()) die("set FAMILY_GCAL_CREDENTIALS and FAMILY_GCAL_CALENDAR_ID (see personal-family-calendar skill)");
  const kids = names.length
    ? names.map((n) => findKid(n))
    : Object.entries(loadConfig().kids).filter(([, k]) => k.meals?.provider === "elistek");
  let failed = false;
  for (const [key, kid] of kids) {
    try {
      await syncKid({ ...kid, key }, { dryRun: values["dry-run"] });
    } catch (err) {
      failed = true;
      console.error(`${kid.name}: ${err.message}`);
    }
  }
  process.exit(failed ? 1 : 0);
}
