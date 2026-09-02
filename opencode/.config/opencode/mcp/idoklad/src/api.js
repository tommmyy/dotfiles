/**
 * iDoklad REST API v3 client.
 *
 * Auth is OAuth2 client_credentials against the identity server. Tokens are
 * cached in memory for the process lifetime and refreshed 60s before expiry.
 *
 * Every v3 response is wrapped in an envelope:
 *   { Data, ErrorCode, IsSuccess, Message, StatusCode }
 * `request` unwraps it and throws on IsSuccess === false.
 */

// Credentials created under Nastavení > Aplikace a API authenticate against the
// original token endpoint. The v2 endpoint additionally demands an
// application_id issued by the Developer portal and rejects requests without
// one, so it is only used when that id is configured.
const TOKEN_URL = "https://identity.idoklad.cz/server/connect/token";
const TOKEN_URL_V2 = "https://identity.idoklad.cz/server/v2/connect/token";
const API_BASE = "https://api.idoklad.cz/v3";

let cachedToken = null; // { value, expiresAt }

function credentials() {
  const clientId = process.env.IDOKLAD_CLIENT_ID;
  const clientSecret = process.env.IDOKLAD_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    throw new Error(
      "Missing IDOKLAD_CLIENT_ID / IDOKLAD_CLIENT_SECRET. Create them in iDoklad under " +
        "Nastavení > Aplikace a API, then store them in the macOS keychain and export them from ~/.zsh_secrets.",
    );
  }
  return { clientId, clientSecret, applicationId: process.env.IDOKLAD_APPLICATION_ID };
}

async function accessToken() {
  if (cachedToken && cachedToken.expiresAt > Date.now()) return cachedToken.value;

  const { clientId, clientSecret, applicationId } = credentials();
  const body = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: clientId,
    client_secret: clientSecret,
    scope: "idoklad_api",
  });
  if (applicationId) body.set("application_id", applicationId);

  const res = await fetch(applicationId ? TOKEN_URL_V2 : TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`Token request failed (${res.status}): ${text.slice(0, 400)}`);

  const json = JSON.parse(text);
  // Refresh a minute early so a long-running call never races the expiry.
  cachedToken = {
    value: json.access_token,
    expiresAt: Date.now() + Math.max(0, (json.expires_in ?? 3600) - 60) * 1000,
  };
  return cachedToken.value;
}

/**
 * Perform an authenticated v3 call and return the unwrapped `Data`.
 *
 * @param {string} path       Path below /v3, e.g. "IssuedInvoices/12/Copy".
 * @param {object} [options]
 * @param {string} [options.method="GET"]
 * @param {object} [options.query]  Query parameters; undefined values are dropped.
 * @param {object} [options.body]   JSON request body.
 */
export async function request(path, { method = "GET", query, body } = {}) {
  const url = new URL(`${API_BASE}/${path.replace(/^\/+/, "")}`);
  for (const [key, value] of Object.entries(query ?? {})) {
    if (value !== undefined && value !== null) url.searchParams.set(key, String(value));
  }

  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${await accessToken()}`,
      Accept: "application/json",
      ...(body === undefined ? {} : { "Content-Type": "application/json" }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  const text = await res.text();
  let payload;
  try {
    payload = text ? JSON.parse(text) : {};
  } catch {
    throw new Error(`${method} ${path} returned non-JSON (${res.status}): ${text.slice(0, 400)}`);
  }

  if (!res.ok || payload.IsSuccess === false) {
    const detail = payload.Message || payload.ErrorMessage || text.slice(0, 400);
    throw new Error(`${method} ${path} failed (HTTP ${res.status}): ${detail}`);
  }
  return "Data" in payload ? payload.Data : payload;
}
