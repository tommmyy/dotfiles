// Shared helpers: kid lookup from config.json, secrets, school days.
// Date parsing comes from the personal-family-calendar skill.

import { readFileSync } from "node:fs";
import { fold, isoDate, parseIso, resolveDate as parseDate, todayIso } from "../../personal-family-calendar/scripts/dates.mjs";

export { fold, todayIso };

const CONFIG_URL = new URL("../config.json", import.meta.url);

export function die(message, code = 2) {
  console.error(`error: ${message}`);
  process.exit(code);
}

export function resolveDate(token) {
  try {
    return parseDate(token);
  } catch (err) {
    die(err.message);
  }
}

export const loadConfig = () => JSON.parse(readFileSync(CONFIG_URL, "utf8"));

/** Return [key, kid] for a name in any declension; exit on no/ambiguous match. */
export function findKid(query) {
  const wanted = fold(query);
  const kids = Object.entries(loadConfig().kids);
  const matches = kids.filter(
    ([key, kid]) => wanted === fold(key) || (kid.aliases ?? []).some((a) => fold(a) === wanted),
  );
  if (matches.length !== 1) {
    die(`unknown kid '${query}' (known: ${kids.map(([k]) => k).join(", ")}); add an alias to config.json`);
  }
  return matches[0];
}

export function secret(envName) {
  const value = (process.env[envName] ?? "").trim();
  if (!value) die(`env var ${envName} is not set; export it in ~/dotfiles/zsh/.zsh_secrets and open a new shell`);
  return value;
}

/** Czech public holidays (státní svátky) of a year, as YYYY-MM-DD. */
export function czechHolidays(year) {
  const fixed = ["01-01", "05-01", "05-08", "07-05", "07-06", "09-28", "10-28", "11-17", "12-24", "12-25", "12-26"];
  // Anonymous Gregorian algorithm for Easter Sunday.
  const a = year % 19, b = Math.floor(year / 100), c = year % 100;
  const d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30, i = Math.floor(c / 4), k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31), day = ((h + l - 7 * m + 114) % 31) + 1;
  const easter = new Date(year, month - 1, day);
  const shift = (n) => isoDate(new Date(easter.getFullYear(), easter.getMonth(), easter.getDate() + n));
  return new Set([...fixed.map((md) => `${year}-${md}`), shift(-2), shift(1)]);
}

/** Mon-Fri and not a public holiday. */
export function isSchoolDay(iso) {
  const [y, m] = iso.split("-").map(Number);
  const date = parseIso(iso);
  if (date.getMonth() !== m - 1) return false;
  return date.getDay() !== 0 && date.getDay() !== 6 && !czechHolidays(y).has(iso);
}
