# superset-mcp

Read-only SQL access to the Perselio analytics database, over Superset's SQL Lab
REST API.

## Why the REST API and not Postgres

Postgres (`superset-1.hetzner.internal.zoe-ai.eu:5432`) is reachable only from
inside the Hetzner network or through an SSH tunnel on port 6011. The SQL Lab
API is reachable over HTTPS with the VPN, and is the same path
`perselio-console` uses.

Neither path is safer than the other, for the reason below.

## Read-only is enforced here, and only here

Superset's `PostgreSQL` connection (`database_id: 1`) is configured with:

```
allow_dml:  true
allow_ctas: true
allow_cvas: true
```

and SQL Lab executes as the Postgres role `superset`, which **owns** the
analytics tables. A `CREATE TABLE` sent through this account succeeds.

So `src/readonly.js` is not a convenience check. It is the only thing preventing
a write against production analytics data. Every change to it is
security-relevant; keep `test/readonly.test.js` green.

### Making this defence in depth

Two server-side changes would move enforcement off the client. Both need
Superset admin, and the first is a checkbox:

1. **Turn off DML on the analytics connection.** In Superset, *Data → Databases →
   PostgreSQL → Advanced → SQL Lab*, clear "Allow DML", "Allow CREATE TABLE AS"
   and "Allow CREATE VIEW AS". This protects every consumer, not just this
   server — `perselio-console`, `query_superset.py` and the nightshift jobs all
   run through the same connection.

2. **Give the service account a read-only Postgres role.** Today it connects as
   the table owner:

   ```sql
   CREATE ROLE superset_ro LOGIN PASSWORD '...';
   GRANT CONNECT ON DATABASE superset TO superset_ro;
   GRANT USAGE ON SCHEMA data TO superset_ro;
   GRANT SELECT ON ALL TABLES IN SCHEMA data TO superset_ro;
   ALTER DEFAULT PRIVILEGES IN SCHEMA data GRANT SELECT ON TABLES TO superset_ro;
   ```

   Then point a second Superset database connection at `superset_ro` and set
   `SUPERSET_DATABASE_ID` to it.

## What the guard blocks

`assertReadOnly` sanitizes the statement first — string literals, quoted
identifiers, dollar-quoted blocks and comments become inert placeholders — so
keyword matching only ever sees real SQL tokens. It then requires a single
statement starting with `SELECT`, `WITH`, `EXPLAIN`, `SHOW`, `DESCRIBE`, `TABLE`
or `VALUES`, and rejects:

- write keywords, including `INTO` — `SELECT * INTO t FROM x` is Postgres'
  spelling of `CREATE TABLE AS` and passes a prefix-only check
- writable CTEs: `WITH x AS (DELETE ... RETURNING *) SELECT * FROM x`
- a second statement after a semicolon, including one hidden behind a `--`
  comment
- routines a word-boundary match misses because `_` is a word character:
  `dblink_exec`, `query_to_xml`, `pg_read_file`, `lo_export`, `pg_sleep`,
  `pg_terminate_backend`, and similar

A write keyword inside a string literal is data and stays allowed:
`SELECT * FROM t WHERE q = 'drop table users'` runs fine.

### Known false positives

The keyword list errs strict. `FETCH FIRST n ROWS ONLY`, `EXPLAIN ANALYZE`, and
a bare column named `comment`, `close` or `set` are rejected. Use `LIMIT`, plain
`EXPLAIN`, and quote the column — `SELECT "comment" FROM …` — which the
sanitizer treats as an identifier.

## Tools

| Tool | Purpose |
| --- | --- |
| `superset_query` | Run one read-only statement. `limit` (default 1000, max 10000), `timeoutMs` (default 60s, max 300s). Reports `truncated` when the row cap is hit. |
| `superset_list_tables` | Tables/views in a schema, filtered by name substring. |
| `superset_describe_table` | Columns, types, nullability, plus sample rows. |
| `superset_list_tenants` | Tenant aliases and which per-tenant tables each has. Reads table metadata, so it returns immediately. |

## Querying the data

Analytics tables live in schema `data` and are EAV-shaped: one row per
`(day, stat, metric, dimensions)` with the number in `value`. Filter on `stat`
(`sessions`, `users`, `item_view`, `item_click`, `add_to_cart`, `purchase`,
`order`, `rcb_first`, `rcb_all`) and `metric` (`count`, `price`, `margin`), and
pin `experiment = 'ALL' AND variation = 'ALL'` unless you want an A/B split.

Prefer per-tenant tables — `{alias}_daily_aggregations`, `_items`,
`_search_queries`, `_copilot_conversations` — over the cross-tenant `*_simple`
views, which are large enough to time out.

```sql
SELECT day, SUM(value) AS sessions
FROM sps_daily_aggregations
WHERE stat = 'sessions' AND metric = 'count'
  AND experiment = 'ALL' AND variation = 'ALL'
  AND day >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY day ORDER BY day;
```

Schema `public` holds Superset's own metadata (dashboards, users, logs).

## Credentials

Same pattern as the `prometheus` and `idoklad` servers: the secret lives in the
macOS keychain and never touches disk.

```sh
security add-generic-password -a "$USER" -s "superset-sdp" -w "<password>" -U
```

`~/.zsh_secrets` reads it through a file descriptor and exports
`SUPERSET_PASSWORD`, alongside `SUPERSET_URL` and `SUPERSET_USER`.
`opencode.jsonc` passes all three through with `{env:...}`.

Optional overrides: `SUPERSET_DATABASE_ID`, `SUPERSET_CATALOG`,
`SUPERSET_SCHEMA`, `SUPERSET_TIMEOUT_MS`.

## Enabling

The server is registered with `"enabled": false` in `opencode.jsonc`, since
analytics questions are occasional and the tools cost context in every session.
Flip it to `true` when you need it.

## Tests

```sh
npm test
```

Covers the guard only; it makes no network calls.
