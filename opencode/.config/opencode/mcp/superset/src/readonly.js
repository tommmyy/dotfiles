/**
 * Read-only SQL guard.
 *
 * This is the ONLY thing standing between this server and a writable
 * production database. Superset's `PostgreSQL` connection (database_id 1) is
 * configured with allow_dml/allow_ctas/allow_cvas all true, and SQL Lab
 * executes as the Postgres role `superset`, which OWNS the analytics tables.
 * A statement that gets past this file will run with full DDL/DML rights.
 *
 * Treat every change here as security-relevant and keep test/readonly.test.js
 * passing.
 *
 * Approach: sanitize first, then match. Naive regex guards fail because string
 * literals and comments hide (or fake) keywords, so `sanitize()` replaces every
 * string, quoted identifier, dollar-quoted block and comment with an inert
 * placeholder. All checks then run on text where the remaining words are real
 * SQL tokens.
 */

export class ReadOnlyViolation extends Error {
  constructor(message) {
    super(message);
    this.name = "ReadOnlyViolation";
  }
}

/** Statements that cannot, on their own, modify anything. */
const ALLOWED_PREFIXES = ["select", "with", "explain", "show", "describe", "table", "values"];

/**
 * Keywords that imply a write. Matched on word boundaries against sanitized
 * SQL. `into` is here because `SELECT * INTO t FROM x` is Postgres' spelling of
 * CREATE TABLE AS — it starts with SELECT and contains no other write keyword,
 * so a prefix check alone lets it through.
 */
const FORBIDDEN_KEYWORDS = [
  "insert", "update", "delete", "drop", "alter", "create", "truncate",
  "replace", "merge", "grant", "revoke", "call", "exec", "execute",
  "upsert", "rename", "comment", "lock", "unlock", "vacuum", "reindex",
  "cluster", "copy", "load", "import", "into", "set", "reset", "begin",
  "commit", "rollback", "savepoint", "prepare", "deallocate", "discard",
  "listen", "notify", "unlisten", "refresh", "reassign", "security",
  "attach", "detach", "do", "analyze", "checkpoint", "move", "fetch",
  "close", "declare",
];

/**
 * Dangerous routines that a word-boundary keyword match cannot catch, because
 * `_` counts as a word character: `\bexec\b` does not fire inside
 * `dblink_exec`. Matched as plain substrings instead.
 *
 * These either execute arbitrary SQL through a side channel (dblink,
 * query_to_xml), touch the filesystem (pg_read_file, lo_export), or let a
 * "read" query damage the server (pg_sleep, pg_terminate_backend).
 */
const FORBIDDEN_IDENTIFIERS = [
  "dblink", "postgres_fdw", "pg_read_file", "pg_read_binary_file",
  "pg_ls_dir", "pg_stat_file", "pg_file_write", "pg_logdir_ls",
  "lo_import", "lo_export", "lo_unlink", "lowrite",
  "pg_sleep", "pg_terminate_backend", "pg_cancel_backend",
  "pg_reload_conf", "pg_rotate_logfile", "pg_promote",
  "query_to_xml", "xmltable", "pg_execute", "set_config",
  "pg_create_restore_point", "pg_switch_wal", "pg_drop_replication_slot",
  "pg_create_physical_replication_slot", "pg_create_logical_replication_slot",
];

/**
 * Replace string literals, quoted identifiers, dollar-quoted blocks and
 * comments with inert placeholders of the same "shape", so that later keyword
 * matching only ever sees real SQL tokens.
 *
 * Returns the sanitized SQL. Throws if a literal or comment is unterminated,
 * since that means we cannot reason about the rest of the statement.
 */
export function sanitize(sql) {
  let out = "";
  let i = 0;
  const n = sql.length;

  while (i < n) {
    const ch = sql[i];
    const next = sql[i + 1];

    // -- line comment
    if (ch === "-" && next === "-") {
      while (i < n && sql[i] !== "\n") i++;
      out += " ";
      continue;
    }

    // /* block comment */ — nestable in Postgres
    if (ch === "/" && next === "*") {
      let depth = 1;
      i += 2;
      while (i < n && depth > 0) {
        if (sql[i] === "/" && sql[i + 1] === "*") { depth++; i += 2; continue; }
        if (sql[i] === "*" && sql[i + 1] === "/") { depth--; i += 2; continue; }
        i++;
      }
      if (depth > 0) throw new ReadOnlyViolation("Unterminated block comment in SQL.");
      out += " ";
      continue;
    }

    // 'string literal' with '' escapes
    if (ch === "'") {
      i++;
      let closed = false;
      while (i < n) {
        if (sql[i] === "'" && sql[i + 1] === "'") { i += 2; continue; }
        if (sql[i] === "'") { i++; closed = true; break; }
        i++;
      }
      if (!closed) throw new ReadOnlyViolation("Unterminated string literal in SQL.");
      out += "''";
      continue;
    }

    // "quoted identifier" with "" escapes
    if (ch === '"') {
      i++;
      let closed = false;
      while (i < n) {
        if (sql[i] === '"' && sql[i + 1] === '"') { i += 2; continue; }
        if (sql[i] === '"') { i++; closed = true; break; }
        i++;
      }
      if (!closed) throw new ReadOnlyViolation("Unterminated quoted identifier in SQL.");
      // Keep it a valid identifier token so it cannot glue two words together.
      out += "ident";
      continue;
    }

    // $tag$ dollar-quoted block $tag$
    if (ch === "$") {
      const tag = /^\$[A-Za-z_\u0080-\uffff][A-Za-z0-9_\u0080-\uffff]*\$|^\$\$/.exec(sql.slice(i));
      if (tag) {
        const marker = tag[0];
        const end = sql.indexOf(marker, i + marker.length);
        if (end === -1) throw new ReadOnlyViolation("Unterminated dollar-quoted string in SQL.");
        i = end + marker.length;
        out += "''";
        continue;
      }
    }

    out += ch;
    i++;
  }

  return out;
}

/**
 * Throw unless `sql` is a single, unambiguously read-only statement.
 *
 * Checks, in order: non-empty, single statement, allowed leading keyword, no
 * write keyword, no dangerous routine.
 */
export function assertReadOnly(sql) {
  if (typeof sql !== "string" || !sql.trim()) {
    throw new ReadOnlyViolation("Empty SQL query.");
  }

  // Sanitize before anything else so quotes and comments cannot hide tokens.
  const sanitized = sanitize(sql);

  // Drop a single trailing semicolon (and trailing space) — everything after
  // that would be a second statement.
  const trimmed = sanitized.trim().replace(/;\s*$/, "").trim();

  if (!trimmed) {
    throw new ReadOnlyViolation("Empty SQL query.");
  }
  if (trimmed.includes(";")) {
    throw new ReadOnlyViolation(
      "Multi-statement queries are not allowed; send one read-only statement.",
    );
  }

  const normalized = trimmed.replace(/\s+/g, " ").toLowerCase();

  // A set operation may parenthesise its branches — `(SELECT 1) UNION (SELECT 2)`.
  // Look past any leading parens to find the first real keyword; the forbidden
  // keyword scan below still covers the whole statement, so this cannot be used
  // to smuggle `(INSERT ...)` through.
  const leading = normalized.replace(/^[(\s]+/, "");

  const prefix = ALLOWED_PREFIXES.find(
    (p) => leading === p || leading.startsWith(`${p} `) || leading.startsWith(`${p}(`),
  );
  if (!prefix) {
    throw new ReadOnlyViolation(
      `Only read queries are allowed (must start with ${ALLOWED_PREFIXES.map((p) =>
        p.toUpperCase(),
      ).join(", ")}).`,
    );
  }

  for (const keyword of FORBIDDEN_KEYWORDS) {
    if (new RegExp(`\\b${keyword}\\b`, "i").test(normalized)) {
      throw new ReadOnlyViolation(
        `Write operation detected ("${keyword}"); only read-only queries are permitted.`,
      );
    }
  }

  for (const identifier of FORBIDDEN_IDENTIFIERS) {
    if (normalized.includes(identifier)) {
      throw new ReadOnlyViolation(
        `Disallowed routine detected ("${identifier}"); it can write, read files, or execute SQL indirectly.`,
      );
    }
  }

  return sql;
}

/**
 * Validate a tenant alias before it is concatenated into a table name. Aliases
 * are short lowercase codes (`sps`, `agb`, `rts`); this is the only place a
 * caller-supplied value becomes a SQL identifier, so keep it strict.
 */
export function assertSafeTenantAlias(alias) {
  if (typeof alias !== "string" || !/^[a-z0-9_]{1,40}$/.test(alias)) {
    throw new ReadOnlyViolation(`Unsafe tenant alias: ${JSON.stringify(alias)}`);
  }
  return alias;
}

/** Escape a string literal for safe inline use in a read-only query. */
export function sqlString(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}
