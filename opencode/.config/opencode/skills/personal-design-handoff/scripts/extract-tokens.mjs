#!/usr/bin/env node
// Usage: node extract-tokens.mjs <dir-or-file> [...more] > tokens.json
// Deterministically pulls design tokens out of HTML/CSS files. No dependencies.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, extname } from "node:path";

const files = [];
function walk(p) {
  const st = statSync(p);
  if (st.isDirectory()) return readdirSync(p).forEach((f) => walk(join(p, f)));
  if ([".html", ".css", ".dc.html"].some((e) => p.endsWith(e))) files.push(p);
}
process.argv.slice(2).forEach(walk);

const out = {
  files,
  customProperties: {}, // name -> { value, definedIn:[], usedCount }
  themeBlocks: [], // Tailwind v4 @theme { ... } raw bodies
  fontFamilies: {}, // family -> count
  breakpoints: {}, // media query -> count
  literalColors: {}, // hex/rgb/hsl literal -> count (outside var definitions)
};

const reProp = /(--[\w-]+)\s*:\s*([^;}]+)[;}]/g;
const reUse = /var\(\s*(--[\w-]+)/g;
const reTheme = /@theme[^{]*\{([\s\S]*?)\}/g;
const reFont = /font-family\s*:\s*([^;}]+)/g;
const reMedia = /@media\s*([^{]+)\{/g;
const reColor = /#(?:[0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})\b|rgba?\([^)]*\)|hsla?\([^)]*\)|oklch\([^)]*\)/gi;

for (const f of files) {
  const src = readFileSync(f, "utf8");
  for (const m of src.matchAll(reProp)) {
    const [, name, value] = m;
    const e = (out.customProperties[name] ??= { value: value.trim(), definedIn: [], usedCount: 0 });
    if (!e.definedIn.includes(f)) e.definedIn.push(f);
  }
  for (const m of src.matchAll(reUse)) {
    const e = (out.customProperties[m[1]] ??= { value: null, definedIn: [], usedCount: 0 });
    e.usedCount++;
  }
  for (const m of src.matchAll(reTheme)) out.themeBlocks.push({ file: f, body: m[1].trim() });
  for (const m of src.matchAll(reFont)) {
    const fam = m[1].trim();
    out.fontFamilies[fam] = (out.fontFamilies[fam] ?? 0) + 1;
  }
  for (const m of src.matchAll(reMedia)) {
    const q = m[1].trim();
    out.breakpoints[q] = (out.breakpoints[q] ?? 0) + 1;
  }
  // literal colors outside custom-property definitions
  const stripped = src.replace(reProp, "");
  for (const m of stripped.matchAll(reColor)) {
    const c = m[0].toLowerCase();
    out.literalColors[c] = (out.literalColors[c] ?? 0) + 1;
  }
}

out.summary = {
  customProperties: Object.keys(out.customProperties).length,
  undefinedButUsed: Object.entries(out.customProperties)
    .filter(([, v]) => v.value === null)
    .map(([k]) => k),
  definedButUnused: Object.entries(out.customProperties)
    .filter(([, v]) => v.value !== null && v.usedCount === 0)
    .map(([k]) => k),
  literalColorCount: Object.keys(out.literalColors).length,
};

process.stdout.write(JSON.stringify(out, null, 2) + "\n");
