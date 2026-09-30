#!/usr/bin/env node
// Bakaláři (school information system), read-only, via the mobile app's API v3.
// API docs (unofficial): https://github.com/bakalari-api/bakalari-api-v3
//
// Usage:
//   bakalari.mjs user      KID                       who is logged in, class, enabled modules
//   bakalari.mjs homework  KID [FROM] [TO]           default: today .. +7 days (by due date)
//   bakalari.mjs messages  KID [--all] [--days N]    received Komens; default unread + last 14 days
//   bakalari.mjs noticeboard KID
//   bakalari.mjs timetable KID [DATE]                the week containing DATE, with changes
//   bakalari.mjs events    KID [FROM]                school events from FROM (default today)
//   bakalari.mjs marks     KID [--days N]            marks from the last N days (default 14)
//   bakalari.mjs excuse    KID FROM REASON... [--to DATE] [--time HH:MM-HH:MM] [--submit]
//                                                    omluvenka to the class teacher; preview unless --submit
//   Add --json to any command for the raw API response (excuse: the payload it would send).
//
// Credentials come from the macOS Keychain item named in config.json
// (school.keychain_service). Each run logs in with the password; no tokens are stored.

import { parseArgs } from "node:util";
import { addDaysIso, parseIso } from "../../_lib/dates.mjs";
import { die, findKid, keychainSecret, resolveDate, todayIso } from "./kids.mjs";

const WEEKDAY = ["ne", "po", "út", "st", "čt", "pá", "so"];

function schoolOf(name) {
  const [key, kid] = findKid(name);
  if (kid.school?.provider !== "bakalari") die(`${kid.name} has no Bakaláři school block in config.json`);
  return { key, kid, school: kid.school };
}

async function login(school) {
  const { account, password } = keychainSecret(school.keychain_service);
  const body = new URLSearchParams({ client_id: "ANDR", grant_type: "password", username: account, password });
  const res = await fetch(`${school.url}/api/login`, {
    method: "POST",
    headers: { ...LANG, "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.access_token) die(`login failed: HTTP ${res.status} ${data.error_description ?? data.error ?? ""}`);
  return data.access_token;
}

// Node's fetch sends `Accept-Language: *` by default, and the Bakaláři API answers that
// with HTTP 500 on every endpoint (before auth). Always send a concrete language.
const LANG = { "Accept-Language": "cs" };

function client(school, token) {
  return async (method, path, params, json) => {
    const query = method === "GET" && params ? `?${new URLSearchParams(params)}` : "";
    const res = await fetch(`${school.url}/api/3${path}${query}`, {
      method,
      headers: {
        ...LANG,
        Authorization: `Bearer ${token}`,
        "Content-Type": json ? "application/json; charset=utf-8" : "application/x-www-form-urlencoded",
      },
      ...(json && { body: JSON.stringify(json) }),
      ...(!json && method !== "GET" && params && { body: new URLSearchParams(params) }),
    });
    const text = await res.text();
    if (!res.ok) die(`${method} ${path} -> HTTP ${res.status} ${text.slice(0, 200)}`);
    return text ? JSON.parse(text) : null;
  };
}

const day = (iso) => (iso ? iso.slice(0, 10) : "");
const dayLabel = (iso) => `${day(iso)} ${WEEKDAY[parseIso(day(iso)).getDay()]}`;
const time = (iso) => iso.slice(11, 16);
const plain = (html = "") =>
  html
    .replace(/<br\s*\/?>|<\/(p|div|li)>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&amp;/g, "&")
    .replace(/\/n/g, "\n")
    .replace(/[ \t]+/g, " ")
    .replace(/\n\s*\n+/g, "\n")
    .trim();
const indent = (text) => text.split("\n").map((l) => `    ${l}`).join("\n");

async function cmdUser(api, opts) {
  const u = await api("GET", "/user");
  if (opts.json) return console.log(JSON.stringify(u, null, 2));
  console.log(`${u.FullName} (${u.UserTypeText}), ${u.SchoolOrganizationName}`);
  console.log(`třída: ${u.Class?.Abbrev ?? "?"}`);
  console.log(`moduly: ${u.EnabledModules.map((m) => `${m.Module}[${m.Rights.join(",")}]`).join(" ")}`);
}

async function cmdHomework(api, opts, [from, to]) {
  const f = from ? resolveDate(from) : todayIso();
  const t = to ? resolveDate(to) : addDaysIso(f, 7);
  const data = await api("GET", "/homeworks", { from: addDaysIso(f, -14), to: t });
  if (opts.json) return console.log(JSON.stringify(data, null, 2));
  const due = data.Homeworks.filter((h) => day(h.DateEnd) >= f && day(h.DateEnd) <= t).sort((a, b) => a.DateEnd.localeCompare(b.DateEnd));
  console.log(`úkoly s odevzdáním ${f} .. ${t}: ${due.length}`);
  for (const h of due) {
    const flags = [h.Done && "hotovo", h.Closed && "uzavřeno", h.Attachments?.length && `${h.Attachments.length} příloh`].filter(Boolean);
    console.log(`  do ${dayLabel(h.DateEnd)}  ${h.Subject.Name}${flags.length ? ` (${flags.join(", ")})` : ""}  zadáno ${day(h.DateStart)}`);
    console.log(indent(plain(h.Content)));
  }
}

async function cmdMessages(api, opts) {
  const data = await api("POST", "/komens/messages/received");
  if (opts.json) return console.log(JSON.stringify(data, null, 2));
  const since = addDaysIso(todayIso(), -Number(opts.days ?? 14));
  const shown = data.Messages.filter((m) => opts.all || !m.Read || day(m.SentDate) >= since);
  console.log(`přijaté zprávy: ${shown.length} zobrazeno (${data.Messages.filter((m) => !m.Read).length} nepřečtených, ${data.Messages.length} celkem)`);
  for (const m of shown) {
    const flags = [!m.Read && "NEPŘEČTENO", m.CanConfirm && !m.Confirmed && "ČEKÁ NA POTVRZENÍ", m.Attachments?.length && `${m.Attachments.length} příloh`].filter(Boolean);
    console.log(`  ${dayLabel(m.SentDate)} ${time(m.SentDate)}  ${m.Sender?.Name ?? "?"}: ${m.Title}${flags.length ? `  [${flags.join(", ")}]` : ""}`);
    console.log(indent(plain(m.Text)));
  }
}

async function cmdNoticeboard(api, opts) {
  const data = await api("POST", "/komens/messages/noticeboard");
  if (opts.json) return console.log(JSON.stringify(data, null, 2));
  console.log(`nástěnka: ${data.Messages.length} zpráv`);
  for (const m of data.Messages) {
    console.log(`  ${dayLabel(m.SentDate)}  ${m.Sender?.Name ?? "?"}: ${m.Title}${m.Read ? "" : "  [NEPŘEČTENO]"}`);
    console.log(indent(plain(m.Text)));
  }
}

async function cmdTimetable(api, opts, [date]) {
  const d = date ? resolveDate(date) : todayIso();
  const data = await api("GET", "/timetable/actual", { date: d });
  if (opts.json) return console.log(JSON.stringify(data, null, 2));
  const hours = Object.fromEntries(data.Hours.map((h) => [h.Id, h]));
  const subjects = Object.fromEntries(data.Subjects.map((s) => [s.Id, s]));
  for (const dd of data.Days) {
    const label = dayLabel(dd.Date);
    if (dd.DayType !== "WorkDay") {
      console.log(`${label}  ${dd.DayType}${dd.DayDescription ? ` (${dd.DayDescription})` : ""}`);
      continue;
    }
    const atoms = dd.Atoms.filter((a) => a.SubjectId || a.Change).sort((a, b) => a.HourId - b.HourId);
    const taught = atoms.filter((a) => a.SubjectId && a.Change?.ChangeType !== "Canceled" && a.Change?.ChangeType !== "Removed");
    const span = taught.length ? `${hours[taught[0].HourId].BeginTime}-${hours[taught.at(-1).HourId].EndTime}` : "bez výuky";
    console.log(`${label}  ${span}  ${atoms.map((a) => `${hours[a.HourId].Caption}.${subjects[a.SubjectId]?.Abbrev?.trim() ?? "-"}`).join(" ")}`);
    const changes = new Set(atoms.filter((x) => x.Change).map((a) => `    změna ${a.Change.Hours}: ${a.Change.ChangeType} ${a.Change.Description}`));
    for (const line of changes) console.log(line);
  }
}

async function cmdEvents(api, opts, [from]) {
  const f = from ? resolveDate(from) : todayIso();
  const data = await api("GET", "/events/my", { from: f });
  if (opts.json) return console.log(JSON.stringify(data, null, 2));
  console.log(`akce od ${f}: ${data.Events.length}`);
  for (const e of data.Events) {
    const times = e.Times.map((t) => (t.WholeDay ? dayLabel(t.StartTime) : `${dayLabel(t.StartTime)} ${time(t.StartTime)}-${time(t.EndTime)}`)).join(", ");
    console.log(`  ${times}  ${e.Title} (${e.EventType?.Name ?? "?"})`);
    if (e.Description) console.log(indent(plain(e.Description)));
  }
}

async function cmdMarks(api, opts) {
  const data = await api("GET", "/marks");
  if (opts.json) return console.log(JSON.stringify(data, null, 2));
  const since = addDaysIso(todayIso(), -Number(opts.days ?? 14));
  const recent = data.Subjects.flatMap((s) => s.Marks.filter((m) => day(m.EditDate) >= since || m.IsNew).map((m) => ({ ...m, subject: s.Subject.Name })));
  recent.sort((a, b) => b.MarkDate.localeCompare(a.MarkDate));
  console.log(`známky za posledních ${opts.days ?? 14} dní: ${recent.length}`);
  for (const m of recent) console.log(`  ${dayLabel(m.MarkDate)}  ${m.subject}: ${m.MarkText}${m.IsNew ? " [nová]" : ""}${m.Caption ? `  ${m.Caption}` : ""}${m.TypeNote ? ` (${m.TypeNote})` : ""}`);
  console.log("průměry: " + data.Subjects.filter((s) => s.AverageText?.trim()).map((s) => `${s.Subject.Abbrev.trim()} ${s.AverageText.trim()}`).join(", "));
}

/** "+02:00" for a local Prague date/time (handles CET/CEST). */
function pragueOffset(iso, hhmm) {
  const [y, m, d] = iso.split("-").map(Number);
  const [h, min] = hhmm.split(":").map(Number);
  const guess = new Date(Date.UTC(y, m - 1, d, h, min));
  const name = new Intl.DateTimeFormat("en", { timeZone: "Europe/Prague", timeZoneName: "longOffset" })
    .formatToParts(guess)
    .find((p) => p.type === "timeZoneName").value;
  return name === "GMT" ? "+00:00" : name.slice(3);
}

const stamp = (iso, hhmm, ss = "00") => `${iso}T${hhmm}:${ss}${pragueOffset(iso, hhmm)}`;

/**
 * Omluvenka to the class teacher (Komens message type OMLUVENKA).
 * Payload shape follows the community API docs plus the web form (whole day / time range);
 * it has not been confirmed against a real submission yet, see references/bakalari.md.
 */
async function cmdExcuse(api, opts, [fromToken, ...reasonWords]) {
  if (!fromToken || !reasonWords.length) die('excuse needs FROM REASON... [--to DATE] [--time HH:MM-HH:MM]');
  const reason = reasonWords.join(" ").trim();
  const from = resolveDate(fromToken);
  const to = opts.to ? resolveDate(opts.to) : from;
  if (to < from) die(`--to ${to} is before ${from}`);
  let dateFrom, dateTo;
  if (opts.time) {
    if (to !== from) die("--time works for a single day only");
    const norm = (t = "") => {
      const [h, m = "00"] = t.trim().replace(".", ":").split(":");
      return `${h.padStart(2, "0")}:${m.padStart(2, "0")}`;
    };
    const [a, b] = opts.time.split("-").map(norm);
    if (!/^\d\d:\d\d$/.test(a) || !/^\d\d:\d\d$/.test(b ?? "") || b <= a) die(`bad --time '${opts.time}', use HH:MM-HH:MM`);
    [dateFrom, dateTo] = [stamp(from, a), stamp(from, b)];
  } else [dateFrom, dateTo] = [stamp(from, "00:00"), stamp(to, "23:59", "59")];

  const types = await api("GET", "/komens/message-types");
  const type = types.MessageTypes.find((t) => t.Abbreviation === "OMLUVENKA");
  if (!type) die("this account cannot send OMLUVENKA messages");
  const rtype = type.RecipientsTypes.find((r) => r.Code === "U") ?? type.RecipientsTypes[0];
  const recipient = rtype.Recipients.find((r) => r.IsDefault) ?? (rtype.Recipients.length === 1 ? rtype.Recipients[0] : null);
  if (!recipient) die(`no default recipient for OMLUVENKA (options: ${rtype.Recipients.map((r) => r.DisplayName).join(", ")})`);

  const sent = await api("POST", "/komens/messages/sent");
  const overlapping = sent.Messages.filter(
    (m) => m.Type === "OMLUVENKA" && m.DateFrom && m.DateTo && day(m.DateFrom) <= to && day(m.DateTo) >= from,
  );

  const payload = {
    MessageType: "OMLUVENKA",
    Title: "",
    Text: reason,
    RecipientType: rtype.Code,
    Recipients: [recipient.Code],
    Lifetime: null,
    DateFrom: dateFrom,
    DateTo: dateTo,
    PreviousMessageId: null,
    CopyForClassTeacher: false,
    CopyForParent: false,
    EmailNotification: false,
    SendAsDirector: false,
    RequireConfirmation: false,
    TypeOfRatingId: null,
    Scale: null,
    Attachments: [],
    DraftDate: null,
  };

  const span = opts.time ? `${dayLabel(from)} ${opts.time}` : from === to ? `${dayLabel(from)} celý den` : `${dayLabel(from)} .. ${dayLabel(to)} celé dny`;
  console.log(`OMLUVENKA pro: ${recipient.DisplayName} (${rtype.Name})`);
  console.log(`  omluvit: ${span}`);
  console.log(`  text: ${reason}`);
  for (const m of overlapping) console.log(`  WARNING: už odesláno ${dayLabel(m.SentDate)}: ${m.Title} (${day(m.DateFrom)} .. ${day(m.DateTo)})`);
  if (opts.json) console.log(JSON.stringify(payload, null, 2));
  if (!opts.submit) {
    console.log("PREVIEW ONLY - nothing sent. Re-run with --submit after the user confirms.");
    return;
  }

  await api("POST", "/komens/message", null, payload);
  const after = await api("POST", "/komens/messages/sent");
  const mine = after.Messages.find((m) => m.Type === "OMLUVENKA" && day(m.DateFrom) === from && day(m.DateTo) === to && !sent.Messages.some((s) => s.Id === m.Id));
  if (mine) console.log(`SENT and found in odeslané: ${mine.Title} (${mine.DateFrom} .. ${mine.DateTo})`);
  else console.log("SENT, but not found in odeslané with matching dates; check /next/komens.aspx?l=o before retrying (do not resend blindly)");
}

const { values: opts, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    json: { type: "boolean" },
    all: { type: "boolean" },
    days: { type: "string" },
    to: { type: "string" },
    time: { type: "string" },
    submit: { type: "boolean" },
  },
});
const [cmd, name, ...args] = positionals;
const commands = { user: cmdUser, homework: cmdHomework, messages: cmdMessages, noticeboard: cmdNoticeboard, timetable: cmdTimetable, events: cmdEvents, marks: cmdMarks, excuse: cmdExcuse };
if (!commands[cmd] || !name) die("usage: bakalari.mjs user|homework|messages|noticeboard|timetable|events|marks KID ... (see header)");
const { school } = schoolOf(name);
await commands[cmd](client(school, await login(school)), opts, args);
