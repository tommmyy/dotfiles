#!/usr/bin/env node
// Family calendar ("Rodina Konrády") from the command line.
//
// Usage:
//   cal.mjs list   [FROM] [TO] [--json]              FROM default dnes, TO default FROM+6 (inclusive)
//   cal.mjs search TEXT [--from D] [--to D]          default: today .. +1 year
//   cal.mjs add    TITLE DATE [TIME[-TIME]] [--to-date D] [--desc T] [--location T] [--submit]
//   cal.mjs update ID [--title T] [--date D] [--time HH:MM[-HH:MM]] [--desc T] [--location T] [--submit]
//   cal.mjs delete ID [--submit]
//
// Writes only print a preview unless --submit is given.

import { parseArgs } from "node:util";
import { addDaysIso, instant, parseIso, resolveDate, resolveTime, todayIso } from "../../_lib/dates.mjs";
import { TIME_ZONE, assertConfigured, deleteEvent, getEvent, insertEvent, listEvents, patchEvent } from "../../_lib/gcal.mjs";

const SOURCE = "personal-family-calendar";
const WEEKDAY = ["ne", "po", "út", "st", "čt", "pá", "so"];

function die(message, code = 2) {
  console.error(`error: ${message}`);
  process.exit(code);
}

const localParts = (dateTime) => {
  const d = new Date(dateTime);
  const iso = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  const time = `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  return { iso, time };
};

function describe(event) {
  let when;
  if (event.start?.date) {
    const lastDay = addDaysIso(event.end.date, -1);
    when = `${event.start.date} ${WEEKDAY[parseIso(event.start.date).getDay()]}${lastDay !== event.start.date ? ` - ${lastDay}` : ""}  celý den`;
  } else {
    const s = localParts(event.start.dateTime);
    const e = localParts(event.end.dateTime);
    when = `${s.iso} ${WEEKDAY[parseIso(s.iso).getDay()]}  ${s.time}-${e.iso !== s.iso ? `${e.iso} ` : ""}${e.time}`;
  }
  const auto = event.extendedProperties?.private?.source;
  const origin = auto && auto !== SOURCE ? `auto: ${auto}` : event.creator?.email ?? "?";
  const extra = [event.location && `@ ${event.location}`].filter(Boolean).join(" ");
  return `${when}  ${event.summary ?? "(bez názvu)"}${extra ? `  ${extra}` : ""}\n    id: ${event.id}  (${origin})`;
}

/** "10" | "10:00-11:30" -> {start, end}; end defaults to one hour later. */
function parseTimeRange(token) {
  const [a, b] = String(token).split("-");
  const start = resolveTime(a);
  if (b) return { start, end: resolveTime(b) };
  const [h, m] = start.split(":").map(Number);
  return { start, end: `${String(Math.min(h + 1, 23)).padStart(2, "0")}:${String(h + 1 > 23 ? 59 : m).padStart(2, "0")}` };
}

const timed = (iso, time) => ({ dateTime: `${iso}T${time}:00`, timeZone: TIME_ZONE });

function buildWhen(date, time, toDate) {
  if (time) {
    const { start, end } = parseTimeRange(time);
    if (end <= start) die(`end ${end} is not after start ${start}`);
    return { start: timed(date, start), end: timed(toDate ?? date, end) };
  }
  const last = toDate ?? date;
  if (last < date) die(`--to-date ${last} is before ${date}`);
  return { start: { date }, end: { date: addDaysIso(last, 1) } };
}

function finish(opts, preview, action) {
  console.log(preview);
  if (!opts.submit) {
    console.log("PREVIEW ONLY - nothing written. Re-run with --submit after the user confirms.");
    return null;
  }
  return action();
}

async function cmdList(opts, args) {
  const from = args[0] ? resolveDate(args[0]) : todayIso();
  const to = args[1] ? resolveDate(args[1]) : addDaysIso(from, 6);
  const events = await listEvents({ timeMin: instant(from), timeMax: instant(addDaysIso(to, 1)) });
  if (opts.json) return console.log(JSON.stringify(events, null, 2));
  console.log(`Rodina Konrády ${from} .. ${to}: ${events.length} událostí`);
  for (const e of events) console.log(describe(e));
}

async function cmdSearch(opts, args) {
  if (!args[0]) die("search needs TEXT");
  const from = opts.from ? resolveDate(opts.from) : todayIso();
  const to = opts.to ? resolveDate(opts.to) : addDaysIso(from, 365);
  const events = await listEvents({ q: args.join(" "), timeMin: instant(from), timeMax: instant(addDaysIso(to, 1)) });
  console.log(`"${args.join(" ")}" ${from} .. ${to}: ${events.length} událostí`);
  for (const e of events) console.log(describe(e));
}

async function cmdAdd(opts, args) {
  const [title, dateToken, time] = args;
  if (!title || !dateToken) die("add needs TITLE DATE [TIME]");
  const date = resolveDate(dateToken);
  const event = {
    summary: title,
    ...(opts.desc && { description: opts.desc }),
    ...(opts.location && { location: opts.location }),
    ...buildWhen(date, time, opts["to-date"] && resolveDate(opts["to-date"])),
    extendedProperties: { private: { source: SOURCE } },
  };
  const created = await finish(opts, `ADD\n${describe({ ...event, id: "(new)", creator: { email: "service account" } })}`, () => insertEvent(event));
  if (created) console.log(`CREATED id: ${created.id}`);
}

async function cmdUpdate(opts, args) {
  const id = args[0] ?? die("update needs ID");
  const current = await getEvent(id);
  const patch = {};
  if (opts.title) patch.summary = opts.title;
  if (opts.desc) patch.description = opts.desc;
  if (opts.location) patch.location = opts.location;
  if (opts.date || opts.time) {
    const allDay = Boolean(current.start.date);
    const date = opts.date ? resolveDate(opts.date) : allDay ? current.start.date : localParts(current.start.dateTime).iso;
    if (opts.time) Object.assign(patch, buildWhen(date, opts.time));
    else if (allDay) {
      const days = (parseIso(current.end.date) - parseIso(current.start.date)) / 86_400_000;
      Object.assign(patch, buildWhen(date, null, addDaysIso(date, days - 1)));
    } else {
      const s = localParts(current.start.dateTime).time;
      const e = localParts(current.end.dateTime).time;
      Object.assign(patch, buildWhen(date, `${s}-${e}`));
    }
  }
  if (!Object.keys(patch).length) die("nothing to update");
  const preview = `UPDATE\n  before: ${describe(current)}\n  after:  ${describe({ ...current, ...patch })}`;
  const updated = await finish(opts, preview, () => patchEvent(id, patch));
  if (updated) console.log(`UPDATED id: ${updated.id}`);
}

async function cmdDelete(opts, args) {
  const id = args[0] ?? die("delete needs ID");
  const current = await getEvent(id);
  const done = await finish(opts, `DELETE\n${describe(current)}`, () => deleteEvent(id).then(() => true));
  if (done) console.log(`DELETED id: ${id}`);
}

const { values: opts, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    json: { type: "boolean" },
    submit: { type: "boolean" },
    from: { type: "string" },
    to: { type: "string" },
    "to-date": { type: "string" },
    title: { type: "string" },
    date: { type: "string" },
    time: { type: "string" },
    desc: { type: "string" },
    location: { type: "string" },
  },
});
const [cmd, ...args] = positionals;
const commands = { list: cmdList, search: cmdSearch, add: cmdAdd, update: cmdUpdate, delete: cmdDelete };
if (!commands[cmd]) die("usage: cal.mjs list|search|add|update|delete ... (see header)");
try {
  assertConfigured();
  await commands[cmd](opts, args);
} catch (err) {
  die(err.message);
}
