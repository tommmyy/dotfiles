#!/usr/bin/env node
/**
 * MCP server for the Perselio analytics database, via Superset SQL Lab.
 *
 * READ-ONLY. Every statement passes through src/readonly.js before it is sent.
 * That guard is not a formality: the Superset connection it talks to has
 * allow_dml, allow_ctas and allow_cvas enabled and runs as the Postgres role
 * that owns the analytics tables, so nothing downstream will stop a write.
 * See README.md for the server-side fix that would make this defence in depth.
 *
 * Credentials come from the environment, sourced from the macOS keychain via
 * ~/.zsh_secrets:
 *   SUPERSET_URL SUPERSET_USER SUPERSET_PASSWORD
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

import { clientFromEnv } from "./src/client.js";
import { sqlString } from "./src/readonly.js";

const client = clientFromEnv();
const server = new McpServer({ name: "superset", version: "1.0.0" });

const ok = (value) => ({
  content: [{ type: "text", text: JSON.stringify(value, null, 2) }],
});
const fail = (error) => ({
  content: [{ type: "text", text: `Superset error: ${error.message}` }],
  isError: true,
});
const tool = (handler) => async (args) => {
  try {
    return ok(await handler(args));
  } catch (error) {
    return fail(error);
  }
};

const SCHEMA_NOTE =
  "Analytics tables live in schema `data` and are EAV-shaped: one row per " +
  "(day, stat, metric, dimensions) with the number in `value`. Filter on " +
  "stat (sessions, users, item_view, item_click, add_to_cart, purchase, order, " +
  "rcb_first, rcb_all) and metric (count, price, margin), and pin " +
  "experiment='ALL' AND variation='ALL' unless you specifically want an A/B split.";

server.registerTool(
  "superset_query",
  {
    title: "Run a read-only SQL query",
    description:
      "Execute a single read-only SQL statement against the Perselio analytics database (PostgreSQL) " +
      "and return the rows. Only SELECT / WITH / EXPLAIN / SHOW / DESCRIBE / TABLE / VALUES are accepted; " +
      "writes, multi-statement input and side-effecting routines are rejected before the query is sent. " +
      SCHEMA_NOTE +
      " Prefer per-tenant tables ({alias}_daily_aggregations, _items, _search_queries, " +
      "_copilot_conversations) over the cross-tenant *_simple views, which are large and time out. " +
      "Always bound exploratory queries with a LIMIT and a day range.",
    inputSchema: {
      sql: z.string().describe("A single read-only SQL statement, no trailing semicolon needed"),
      limit: z
        .number()
        .int()
        .min(1)
        .max(10000)
        .default(1000)
        .describe("Maximum rows returned; results are reported as truncated when this is hit"),
      timeoutMs: z
        .number()
        .int()
        .min(1000)
        .max(300000)
        .default(60000)
        .describe(
          "Query timeout in milliseconds. Aggregations over large tenants often need more than the default.",
        ),
      schema: z.string().optional().describe('Override the default schema ("data")'),
    },
  },
  tool(async ({ sql, limit, timeoutMs, schema }) => {
    const result = await client.query(sql, { limit, timeoutMs, schema });
    return {
      rowCount: result.rowCount,
      columns: result.columns,
      rows: result.rows,
      ...(result.truncated
        ? {
            truncated: true,
            note: `Output cut off at ${limit} rows. Raise limit, or aggregate in SQL instead of fetching raw rows.`,
          }
        : {}),
    };
  }),
);

server.registerTool(
  "superset_list_tables",
  {
    title: "List tables",
    description:
      "List tables and views in the analytics database, optionally filtered by a substring of the name. " +
      "Use this to discover which tenant prefixes exist (e.g. sps_, agb_) before querying.",
    inputSchema: {
      pattern: z
        .string()
        .optional()
        .describe('Case-insensitive substring of the table name, e.g. "sps_" or "search_queries"'),
      schema: z.string().default("data").describe('Schema to list; "public" holds Superset metadata'),
      limit: z.number().int().min(1).max(2000).default(200),
    },
  },
  tool(async ({ pattern, schema, limit }) => {
    const where = [`table_schema = ${sqlString(schema)}`];
    if (pattern) where.push(`table_name ILIKE ${sqlString(`%${pattern}%`)}`);
    const sql = `
      SELECT table_name, table_type
      FROM information_schema.tables
      WHERE ${where.join(" AND ")}
      ORDER BY table_name
      LIMIT ${limit}
    `;
    const result = await client.query(sql, { limit });
    return {
      schema,
      tableCount: result.rowCount,
      tables: result.rows,
    };
  }),
);

server.registerTool(
  "superset_describe_table",
  {
    title: "Describe a table",
    description:
      "Return the column names, types and nullability of one table, plus a small sample of rows. " +
      "Use this before writing a query against an unfamiliar table.",
    inputSchema: {
      table: z.string().describe('Table name without schema, e.g. "sps_daily_aggregations"'),
      schema: z.string().default("data"),
      sampleRows: z
        .number()
        .int()
        .min(0)
        .max(50)
        .default(3)
        .describe("Rows of sample data to include; 0 to skip"),
    },
  },
  tool(async ({ table, schema, sampleRows }) => {
    const columns = await client.query(
      `
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_schema = ${sqlString(schema)}
        AND table_name = ${sqlString(table)}
      ORDER BY ordinal_position
    `,
      { limit: 500 },
    );

    if (columns.rowCount === 0) {
      throw new Error(
        `Table ${schema}.${table} not found. Use superset_list_tables to find the correct name.`,
      );
    }

    const out = { schema, table, columns: columns.rows };

    if (sampleRows > 0) {
      // information_schema confirmed the table exists, so the identifier is a
      // real object name rather than caller-controlled text.
      const sample = await client.query(
        `SELECT * FROM ${schema}.${table} LIMIT ${sampleRows}`,
        { limit: sampleRows },
      );
      out.sample = sample.rows;
    }

    return out;
  }),
);

server.registerTool(
  "superset_list_tenants",
  {
    title: "List tenant aliases",
    description:
      "List the tenant aliases that have data, and which per-tenant tables each one has. Use this to " +
      "map a customer to its short alias (e.g. sps, agb, rts) before querying. " +
      "Derived from table metadata, so it returns immediately.",
    inputSchema: {
      schema: z.string().default("data"),
    },
  },
  tool(async ({ schema }) => {
    // Read the alias off the table names rather than SELECT DISTINCT tenant:
    // the cross-tenant views are large enough that scanning one for a list of
    // aliases takes minutes, while information_schema answers instantly.
    const result = await client.query(
      `
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = ${sqlString(schema)}
        AND table_name LIKE '%\\_daily\\_aggregations%'
        AND table_name NOT LIKE '%\\_runs'
        AND table_name NOT LIKE '%\\_removed'
        AND table_name NOT LIKE 'daily\\_aggregations%'
      ORDER BY table_name
    `,
      { limit: 2000 },
    );

    const KINDS = {
      _daily_aggregations_copilot_conversations: "copilot_conversations",
      _daily_aggregations_search_queries: "search_queries",
      _daily_aggregations_items: "items",
      _daily_aggregations: "sessions",
    };

    const tenants = new Map();
    for (const { table_name: name } of result.rows) {
      // Longest suffix first, so `_items` is not swallowed by `_daily_aggregations`.
      const suffix = Object.keys(KINDS).find((s) => name.endsWith(s));
      if (!suffix) continue;
      const alias = name.slice(0, -suffix.length);
      if (!alias) continue;
      if (!tenants.has(alias)) tenants.set(alias, { alias, tables: [] });
      tenants.get(alias).tables.push(KINDS[suffix]);
    }

    const list = [...tenants.values()].sort((a, b) => a.alias.localeCompare(b.alias));
    return {
      tenantCount: list.length,
      tenants: list,
      note: "Query a per-tenant table (e.g. {alias}_daily_aggregations) for that tenant's day range.",
    };
  }),
);

await server.connect(new StdioServerTransport());
