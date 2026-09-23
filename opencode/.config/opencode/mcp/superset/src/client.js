/**
 * Superset SQL Lab REST client (read path only).
 *
 * Talks to the Perselio analytics database through Superset rather than
 * Postgres directly, because the Postgres endpoint sits inside the Hetzner
 * network behind an SSH tunnel while this runs over HTTPS.
 *
 * Request flow, which must happen in this order:
 *   POST /api/v1/security/login        -> access_token (+ session cookie)
 *   GET  /api/v1/security/csrf_token/  -> csrf_token   (needs the access token)
 *   POST /api/v1/sqllab/execute/       -> rows
 *
 * Superset binds the CSRF token to the `session` cookie set on the csrf_token
 * response, and `fetch` has no cookie jar, so cookies are threaded by hand.
 * Dropping them produces "The CSRF session token is missing."
 */

import { assertReadOnly } from "./readonly.js";

const DEFAULTS = {
  databaseId: 1,
  catalog: "superset",
  schema: "data",
  // Aggregations over the production tables regularly run past 30s.
  timeoutMs: 60_000,
  rowLimit: 1000,
  maxRowLimit: 10_000,
};

/** Access tokens last ~15 minutes; refresh well before that. */
const TOKEN_TTL_MS = 10 * 60 * 1000;

export class SupersetError extends Error {
  constructor(message, cause) {
    super(message);
    this.name = "SupersetError";
    this.cause = cause;
  }
}

/** Reduce raw Set-Cookie headers to a single Cookie request header value. */
function cookieHeader(setCookies) {
  return setCookies
    .map((raw) => raw.split(";")[0]?.trim())
    .filter(Boolean)
    .join("; ");
}

async function fetchJson(url, init, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { ...init, signal: controller.signal });
    const text = await res.text();
    const cookies =
      typeof res.headers.getSetCookie === "function"
        ? res.headers.getSetCookie()
        : [res.headers.get("set-cookie")].filter(Boolean);

    if (!res.ok) {
      throw new SupersetError(
        `Superset request failed (${res.status} ${res.statusText}): ${text.slice(0, 400)}`,
      );
    }
    try {
      return { body: JSON.parse(text), cookies };
    } catch {
      throw new SupersetError(`Superset returned a non-JSON response: ${text.slice(0, 400)}`);
    }
  } catch (error) {
    if (error instanceof SupersetError) throw error;
    if (error?.name === "AbortError") {
      throw new SupersetError(
        `Superset query timed out after ${timeoutMs}ms. Narrow the WHERE clause, add a LIMIT, ` +
          "or use a per-tenant table instead of a cross-tenant view.",
      );
    }
    throw new SupersetError(`Superset request failed: ${error?.message ?? error}`, error);
  } finally {
    clearTimeout(timer);
  }
}

/** Build a client bound to one deployment + credentials. */
export function createSupersetClient(config = {}) {
  const baseUrl = String(config.baseUrl ?? "").replace(/\/+$/, "");
  const user = config.user;
  const password = config.password;
  const databaseId = config.databaseId ?? DEFAULTS.databaseId;
  const catalog = config.catalog ?? DEFAULTS.catalog;
  const schema = config.schema ?? DEFAULTS.schema;
  const defaultTimeoutMs = config.timeoutMs ?? DEFAULTS.timeoutMs;
  const defaultRowLimit = config.rowLimit ?? DEFAULTS.rowLimit;
  const maxRowLimit = config.maxRowLimit ?? DEFAULTS.maxRowLimit;

  let cachedToken = null;

  const requireConfig = () => {
    const missing = [];
    if (!baseUrl) missing.push("SUPERSET_URL");
    if (!user) missing.push("SUPERSET_USER");
    if (!password) missing.push("SUPERSET_PASSWORD");
    if (missing.length) {
      throw new SupersetError(
        `Superset is not configured; missing ${missing.join(", ")}. ` +
          "These are exported from ~/.zsh_secrets and read from the macOS keychain.",
      );
    }
  };

  const login = async () => {
    requireConfig();
    const { body, cookies } = await fetchJson(
      `${baseUrl}/api/v1/security/login`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username: user, password, provider: "db", refresh: true }),
      },
      defaultTimeoutMs,
    );
    if (!body?.access_token) {
      throw new SupersetError("Superset login did not return an access token.");
    }
    return { token: body.access_token, cookies };
  };

  /** Cached bearer token plus the cookies it was issued with. */
  const session = async () => {
    const now = Date.now();
    if (cachedToken && cachedToken.expiresAt > now) return cachedToken;
    const { token, cookies } = await login();
    cachedToken = { token, cookies, expiresAt: now + TOKEN_TTL_MS };
    return cachedToken;
  };

  /**
   * Fetch a CSRF token and the session cookie it is bound to. Returns a null
   * token if CSRF is disabled, which some deployments do for bearer auth.
   */
  const csrf = async (token, loginCookies) => {
    try {
      const headers = { Authorization: `Bearer ${token}` };
      const cookie = cookieHeader(loginCookies);
      if (cookie) headers.Cookie = cookie;
      const { body, cookies } = await fetchJson(
        `${baseUrl}/api/v1/security/csrf_token/`,
        { method: "GET", headers },
        defaultTimeoutMs,
      );
      return {
        token: body?.result ?? null,
        // Prefer the cookie the CSRF endpoint set; fall back to the login one
        // so the token's session always travels with it.
        cookies: cookies.length > 0 ? cookies : loginCookies,
      };
    } catch {
      return { token: null, cookies: loginCookies };
    }
  };

  /**
   * Run one read-only statement and return { rows, columns, truncated }.
   *
   * The SQL is validated before it leaves this process. That check is the only
   * thing preventing a write: Superset's database connection has DML and CTAS
   * enabled and executes as the table owner.
   */
  const query = async (sql, opts = {}) => {
    assertReadOnly(sql);
    requireConfig();

    const timeoutMs = opts.timeoutMs ?? defaultTimeoutMs;
    const limit = Math.min(opts.limit ?? defaultRowLimit, maxRowLimit);

    const run = async ({ token, cookies }) => {
      const csrfResult = await csrf(token, cookies);
      const headers = {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
        Referer: baseUrl,
      };
      if (csrfResult.token) headers["X-CSRFToken"] = csrfResult.token;
      const cookie = cookieHeader(csrfResult.cookies);
      if (cookie) headers.Cookie = cookie;

      const { body } = await fetchJson(
        `${baseUrl}/api/v1/sqllab/execute/`,
        {
          method: "POST",
          headers,
          body: JSON.stringify({
            client_id: Math.random().toString(36).slice(2, 13),
            database_id: databaseId,
            catalog: opts.catalog ?? catalog,
            schema: opts.schema ?? schema,
            sql,
            json: true,
            runAsync: false,
            ctas_method: "TABLE",
            expand_data: true,
            queryLimit: limit,
            select_as_cta: false,
            sql_editor_id: "opencode-mcp",
            tab: "opencode-mcp",
            tmp_table_name: "",
          }),
        },
        timeoutMs,
      );

      if (body?.status && body.status !== "success") {
        throw new SupersetError(
          `Superset query ${body.status}: ${body.error ?? body.errorMessage ?? JSON.stringify(body).slice(0, 400)}`,
        );
      }

      const rows = body?.data ?? [];
      return {
        rows,
        columns: (body?.columns ?? []).map((c) => ({
          name: c.column_name ?? c.name,
          type: c.type,
        })),
        rowCount: rows.length,
        // Superset caps at queryLimit; equal counts mean results were probably cut off.
        truncated: rows.length >= limit,
      };
    };

    try {
      return await run(await session());
    } catch (error) {
      // One retry with a fresh token on a likely-expired session.
      if (error instanceof SupersetError && /\b401\b|unauthorized|token|csrf/i.test(error.message)) {
        cachedToken = null;
        return run(await session());
      }
      throw error;
    }
  };

  return {
    query,
    isConfigured: () => Boolean(baseUrl && user && password),
    defaults: { databaseId, catalog, schema, rowLimit: defaultRowLimit, maxRowLimit },
  };
}

/** Build a client from the process environment. */
export function clientFromEnv() {
  return createSupersetClient({
    baseUrl: process.env.SUPERSET_URL,
    user: process.env.SUPERSET_USER,
    password: process.env.SUPERSET_PASSWORD,
    databaseId: process.env.SUPERSET_DATABASE_ID
      ? Number(process.env.SUPERSET_DATABASE_ID)
      : undefined,
    catalog: process.env.SUPERSET_CATALOG,
    schema: process.env.SUPERSET_SCHEMA,
    timeoutMs: process.env.SUPERSET_TIMEOUT_MS ? Number(process.env.SUPERSET_TIMEOUT_MS) : undefined,
  });
}
