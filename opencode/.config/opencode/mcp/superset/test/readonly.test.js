import { strict as assert } from "node:assert";
import { describe, it } from "node:test";

import { assertReadOnly, assertSafeTenantAlias, sanitize, sqlString } from "../src/readonly.js";

const allows = (sql) => assert.doesNotThrow(() => assertReadOnly(sql), `should allow: ${sql}`);
const blocks = (sql) => assert.throws(() => assertReadOnly(sql), /./, `should BLOCK: ${sql}`);

describe("assertReadOnly — accepts genuine reads", () => {
  it("plain selects, any case, with or without a trailing semicolon", () => {
    allows("SELECT 1");
    allows("select day, sum(value) from sps_daily_aggregations group by day");
    allows("SELECT * FROM daily_aggregations_simple LIMIT 10;");
    allows("  \n SELECT 1 \n ");
  });

  it("the other read-only statement forms", () => {
    allows("WITH x AS (SELECT 1 AS n) SELECT * FROM x");
    allows("EXPLAIN SELECT * FROM sps_daily_aggregations");
    allows("SHOW TIMEZONE");
    allows("DESCRIBE sps_daily_aggregations");
    allows("TABLE daily_aggregations_simple");
    allows("(SELECT 1) UNION (SELECT 2)");
  });

  it("write keywords appearing inside string literals are data, not SQL", () => {
    allows("SELECT * FROM t WHERE note = 'please insert a row'");
    allows("SELECT * FROM t WHERE q = 'drop table users'");
    allows("SELECT * FROM t WHERE s = 'it''s an update'");
    allows("SELECT 'dblink_exec' AS harmless_text");
  });

  it("comments are stripped rather than trusted", () => {
    allows("SELECT 1 -- insert update delete\n");
    allows("SELECT /* drop table x */ 1");
    allows("SELECT /* nested /* deeper */ still */ 1");
  });

  it("a quoted identifier is the escape hatch for a column named like a keyword", () => {
    allows('SELECT "comment" FROM conversations LIMIT 5');
  });
});

describe("assertReadOnly — blocks writes", () => {
  it("the obvious DML and DDL", () => {
    blocks("INSERT INTO t VALUES (1)");
    blocks("UPDATE t SET x = 1");
    blocks("DELETE FROM t");
    blocks("DROP TABLE t");
    blocks("ALTER TABLE t ADD COLUMN x int");
    blocks("CREATE TABLE t (x int)");
    blocks("TRUNCATE t");
    blocks("GRANT SELECT ON t TO public");
  });

  it("SELECT ... INTO, which is Postgres' CREATE TABLE AS", () => {
    // Starts with SELECT and contains no other write keyword, so a prefix-only
    // guard lets this create a table.
    blocks("SELECT * INTO new_table FROM sps_daily_aggregations");
    blocks("SELECT day, value INTO TEMP t FROM sps_daily_aggregations");
  });

  it("writable CTEs hidden behind a WITH prefix", () => {
    blocks("WITH x AS (INSERT INTO t VALUES (1) RETURNING *) SELECT * FROM x");
    blocks("WITH x AS (DELETE FROM t RETURNING *) SELECT * FROM x");
  });

  it("a second statement smuggled in after a read", () => {
    blocks("SELECT 1; DROP TABLE t");
    blocks("SELECT 1;DROP TABLE t");
    // The comment ends at the newline, exposing the second statement.
    blocks("SELECT 1 --\n; DROP TABLE t");
  });

  it("routines whose names contain an underscore, which \\b keyword matching misses", () => {
    // \bexec\b does not match inside dblink_exec: `_` is a word character.
    blocks("SELECT dblink_exec('dbname=superset', 'DROP TABLE t')");
    blocks("SELECT * FROM dblink('dbname=superset', 'SELECT 1') AS x(a int)");
    blocks("SELECT query_to_xml('DROP TABLE t', false, false, '')");
  });

  it("filesystem and denial-of-service routines", () => {
    blocks("SELECT pg_read_file('/etc/passwd')");
    blocks("SELECT lo_export(1, '/tmp/x')");
    blocks("SELECT pg_sleep(10000)");
    blocks("SELECT pg_terminate_backend(1)");
  });

  it("session and transaction control", () => {
    blocks("SET search_path TO public");
    blocks("BEGIN");
    blocks("COMMIT");
    blocks("DO $$ BEGIN PERFORM 1; END $$");
  });

  it("empty or unparseable input", () => {
    blocks("");
    blocks("   ");
    blocks("SELECT 'unterminated");
    blocks("SELECT 1 /* unterminated");
  });
});

describe("sanitize", () => {
  it("keeps structure while neutralising literals and comments", () => {
    assert.equal(sanitize("SELECT 'abc'").trim(), "SELECT ''");
    assert.equal(sanitize("SELECT 1 -- x\n+ 2").replace(/\s+/g, " ").trim(), "SELECT 1 + 2");
    assert.equal(sanitize("SELECT $$raw$$").trim(), "SELECT ''");
    assert.equal(sanitize("SELECT $tag$raw$tag$").trim(), "SELECT ''");
  });

  it("does not let a quoted identifier glue two tokens together", () => {
    assert.match(sanitize('SELECT a."b"c'), /ident/);
  });
});

describe("assertSafeTenantAlias", () => {
  it("accepts real aliases", () => {
    for (const alias of ["sps", "agb", "rts", "a_b_1"]) {
      assert.equal(assertSafeTenantAlias(alias), alias);
    }
  });

  it("rejects anything that could break out of an identifier", () => {
    for (const bad of ["", "SPS", "sps;", "sps--", "sps ", "a".repeat(41), 'x"y', "a-b", null]) {
      assert.throws(() => assertSafeTenantAlias(bad), `should reject: ${JSON.stringify(bad)}`);
    }
  });
});

describe("sqlString", () => {
  it("doubles embedded single quotes", () => {
    assert.equal(sqlString("it's"), "'it''s'");
    assert.equal(sqlString("plain"), "'plain'");
  });

  it("produces a literal that survives the guard", () => {
    allows(`SELECT * FROM t WHERE x = ${sqlString("'; DROP TABLE t --")}`);
  });
});
