#!/usr/bin/env node
// Usage: node diff.mjs <design.png> <impl.png> <out.png>
// Prints mismatch ratio; writes a heatmap. Requires `pixelmatch` and `pngjs`.
// Both images are cropped to the common width/height so full-page shots of
// different length still compare over the overlapping region.

import { readFileSync, writeFileSync } from "node:fs";
import { PNG } from "pngjs";
import pixelmatch from "pixelmatch";

const [a, b, out] = process.argv.slice(2);
const A = PNG.sync.read(readFileSync(a));
const B = PNG.sync.read(readFileSync(b));
const w = Math.min(A.width, B.width);
const h = Math.min(A.height, B.height);

function crop(img) {
  const c = new PNG({ width: w, height: h });
  PNG.bitblt(img, c, 0, 0, w, h, 0, 0);
  return c;
}
const ca = crop(A), cb = crop(B);
const diff = new PNG({ width: w, height: h });
const n = pixelmatch(ca.data, cb.data, diff.data, w, h, { threshold: 0.1, includeAA: false });
writeFileSync(out, PNG.sync.write(diff));
console.log(JSON.stringify({
  compared: { w, h },
  heightDelta: A.height - B.height,
  mismatchedPixels: n,
  mismatchRatio: +(n / (w * h)).toFixed(4),
  heatmap: out,
}));
