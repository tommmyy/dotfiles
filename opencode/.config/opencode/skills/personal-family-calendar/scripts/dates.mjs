// Czech-friendly date and time parsing shared by the family skills. All dates are local (Europe/Prague).

const WEEKDAYS = {
  pondeli: 1, po: 1, monday: 1, mon: 1,
  utery: 2, ut: 2, tuesday: 2, tue: 2,
  streda: 3, stredu: 3, st: 3, wednesday: 3, wed: 3,
  ctvrtek: 4, ct: 4, thursday: 4, thu: 4,
  patek: 5, pa: 5, friday: 5, fri: 5,
  sobota: 6, sobotu: 6, so: 6, saturday: 6, sat: 6,
  nedele: 0, nedeli: 0, ne: 0, sunday: 0, sun: 0,
};
const RELATIVE = { dnes: 0, today: 0, zitra: 1, tomorrow: 1, pozitri: 2 };

/** Lowercase and strip diacritics so "Středa" matches "streda". */
export const fold = (text) =>
  String(text).trim().toLowerCase().normalize("NFKD").replace(/\p{M}/gu, "");

/** Local calendar date as YYYY-MM-DD. */
export const isoDate = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

export const startOfToday = () => {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
};

export const todayIso = () => isoDate(startOfToday());

export const addDays = (d, n) => {
  const r = new Date(d);
  r.setDate(r.getDate() + n);
  return r;
};

export const parseIso = (iso) => {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y, m - 1, d);
};

export const addDaysIso = (iso, n) => isoDate(addDays(parseIso(iso), n));

/**
 * Accept YYYY-MM-DD, D.M., D.M.YYYY, weekday names (next occurrence after today) or dnes/zitra/pozitri.
 * Throws on anything else.
 */
export function resolveDate(token, base = startOfToday()) {
  const raw = fold(token).replace(/\.$/, "");
  if (raw in RELATIVE) return isoDate(addDays(base, RELATIVE[raw]));
  if (raw in WEEKDAYS) {
    const ahead = (WEEKDAYS[raw] - base.getDay() + 7) % 7 || 7;
    return isoDate(addDays(base, ahead));
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;
  const parts = raw.split(".").filter(Boolean);
  if ((parts.length === 2 || parts.length === 3) && parts.every((p) => /^\d+$/.test(p))) {
    const [day, month] = parts.map(Number);
    const year = parts.length === 3 ? Number(parts[2]) : base.getFullYear();
    let date = new Date(year, month - 1, day);
    if (parts.length === 2 && date < base) date = new Date(year + 1, month - 1, day);
    return isoDate(date);
  }
  throw new Error(`cannot read date '${token}'`);
}

/** "10", "10:30", "9.15" -> "HH:MM". */
export function resolveTime(token) {
  const m = String(token).trim().match(/^(\d{1,2})(?:[:.](\d{2}))?$/);
  if (!m || Number(m[1]) > 23 || Number(m[2] ?? 0) > 59) throw new Error(`cannot read time '${token}'`);
  return `${m[1].padStart(2, "0")}:${m[2] ?? "00"}`;
}

/** Local wall-clock date + time -> RFC 3339 instant for API range queries. */
export const instant = (iso, time = "00:00") => {
  const [h, min] = time.split(":").map(Number);
  const d = parseIso(iso);
  d.setHours(h, min, 0, 0);
  return d.toISOString();
};
