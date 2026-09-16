#!/usr/bin/env node
// Usage: node render.mjs <srcDir|url> <outDir> [widths=390,1280]
// Fallback when Chrome DevTools MCP is unavailable. Requires `playwright`.
// For a URL argument, renders that single URL as "page".

import { chromium } from "playwright";
import { readdirSync, mkdirSync, writeFileSync } from "node:fs";
import { join, resolve, basename } from "node:path";
import { pathToFileURL } from "node:url";

const [src, outDir, widthsArg = "390,1280"] = process.argv.slice(2);
if (!src || !outDir) {
  console.error("usage: render.mjs <srcDir|url> <outDir> [widths]");
  process.exit(1);
}
const widths = widthsArg.split(",").map(Number);
mkdirSync(outDir, { recursive: true });

const targets = /^https?:\/\//.test(src)
  ? [{ name: "page", url: src }]
  : readdirSync(src)
      .filter((f) => f.endsWith(".html"))
      .map((f) => ({ name: basename(f, ".html"), url: pathToFileURL(resolve(src, f)).href }));

const browser = await chromium.launch();
for (const t of targets) {
  for (const w of widths) {
    const ctx = await browser.newContext({ viewport: { width: w, height: 900 }, deviceScaleFactor: 2 });
    const page = await ctx.newPage();
    await page.goto(t.url, { waitUntil: "networkidle" });
    await page.evaluate(() => document.fonts.ready);
    const shot = join(outDir, `${t.name}@${w}.png`);
    await page.screenshot({ path: shot, fullPage: true });
    if (w === widths[widths.length - 1]) {
      const tree = await page.accessibility.snapshot();
      writeFileSync(join(outDir, `${t.name}.a11y.json`), JSON.stringify(tree, null, 2));
    }
    console.log("wrote", shot);
    await ctx.close();
  }
}
await browser.close();
