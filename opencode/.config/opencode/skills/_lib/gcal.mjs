// Google Calendar client for the family calendar, authenticated as a service account (no dependencies).
//
// Env: FAMILY_GCAL_CREDENTIALS = path to the service-account JSON key
//      FAMILY_GCAL_CALENDAR_ID = calendar ID shared with the service account ("Make changes to events")
//
// Shared by home-family-calendar (cal.mjs) and home-kids (automatic events). Automatic events
// carry private extended properties (tags) so each caller only touches its own.

import { createHash, createSign } from "node:crypto";
import { readFileSync } from "node:fs";

const SCOPE = "https://www.googleapis.com/auth/calendar.events";
const API = "https://www.googleapis.com/calendar/v3";
export const TIME_ZONE = "Europe/Prague";

export const calendarConfigured = () =>
  Boolean(process.env.FAMILY_GCAL_CREDENTIALS?.trim() && process.env.FAMILY_GCAL_CALENDAR_ID?.trim());

export function assertConfigured() {
  if (!calendarConfigured()) {
    throw new Error("FAMILY_GCAL_CREDENTIALS / FAMILY_GCAL_CALENDAR_ID not set (see ~/dotfiles/zsh/.zsh_secrets)");
  }
}

const b64url = (data) => Buffer.from(data).toString("base64url");

let cachedToken = null;

async function token() {
  if (cachedToken && cachedToken.expires > Date.now() + 60_000) return cachedToken.value;
  assertConfigured();
  const key = JSON.parse(readFileSync(process.env.FAMILY_GCAL_CREDENTIALS.trim(), "utf8"));
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${b64url(
    JSON.stringify({ iss: key.client_email, scope: SCOPE, aud: key.token_uri, iat: now, exp: now + 3600 }),
  )}`;
  const signature = createSign("RSA-SHA256").update(unsigned).sign(key.private_key, "base64url");
  const res = await fetch(key.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${signature}`,
    }),
  });
  const body = await res.json();
  if (!res.ok) throw new Error(`Google token request failed: ${body.error_description ?? body.error ?? res.status}`);
  cachedToken = { value: body.access_token, expires: Date.now() + body.expires_in * 1000 };
  return cachedToken.value;
}

async function call(method, path, { query, body, allow = [] } = {}) {
  const url = new URL(`${API}/calendars/${encodeURIComponent(process.env.FAMILY_GCAL_CALENDAR_ID.trim())}${path}`);
  for (const [k, values] of Object.entries(query ?? {})) {
    for (const v of [values].flat()) if (v !== undefined) url.searchParams.append(k, v);
  }
  const res = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${await token()}`, ...(body && { "Content-Type": "application/json" }) },
    body: body && JSON.stringify(body),
  });
  if (allow.includes(res.status)) return { status: res.status };
  const text = await res.text();
  if (!res.ok) {
    const hint = res.status === 404 ? " (calendar not shared with the service account, or wrong calendar ID)" : "";
    throw new Error(`Google Calendar ${method} ${path} -> ${res.status}${hint}: ${text.slice(0, 300)}`);
  }
  return text ? JSON.parse(text) : {};
}

/** Events overlapping [timeMin, timeMax) (RFC 3339), expanded, sorted by start. */
export async function listEvents({ timeMin, timeMax, q, tags } = {}) {
  const events = [];
  let pageToken;
  do {
    const page = await call("GET", "/events", {
      query: {
        timeMin,
        timeMax,
        q,
        singleEvents: "true",
        orderBy: "startTime",
        maxResults: "250",
        pageToken,
        privateExtendedProperty: Object.entries(tags ?? {}).map(([k, v]) => `${k}=${v}`),
      },
    });
    events.push(...(page.items ?? []));
    pageToken = page.nextPageToken;
  } while (pageToken);
  return events;
}

export const getEvent = (id) => call("GET", `/events/${encodeURIComponent(id)}`);
export const insertEvent = (event) => call("POST", "/events", { body: event });
export const patchEvent = (id, patch) => call("PATCH", `/events/${encodeURIComponent(id)}`, { body: patch });
export const deleteEvent = (id) => call("DELETE", `/events/${encodeURIComponent(id)}`, { allow: [404, 410] });

/** Event IDs must be base32hex; a hex digest of a stable key makes them idempotent. */
export const eventId = (key) => createHash("sha1").update(key).digest("hex");

/** Create or restore an event under a fixed ID. */
export async function upsertEvent(id, event) {
  const body = { ...event, id, status: "confirmed" };
  const updated = await call("PUT", `/events/${id}`, { body, allow: [404] });
  if (updated.status === 404) await call("POST", "/events", { body });
}
