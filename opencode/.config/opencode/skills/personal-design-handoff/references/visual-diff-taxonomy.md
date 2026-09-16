# Visual diff taxonomy for `verify.md`

Use these categories and severities so diffs are comparable across runs.

| Category | What it means | Default severity |
|---|---|---|
| structure | region missing, extra, or in different order | high |
| layout | wrong column count, width, alignment, stacking at a breakpoint | high |
| spacing | padding/gap/margin differs by > 1 spacing step | medium |
| typography | wrong family/size/weight/line-height for a role | medium (high for h1 / CTA) |
| color | wrong token role (e.g. surface-2 vs surface-1) | medium |
| component | wrong variant or state rendering | medium |
| content | copy differs, truncation, wrapping differs | low (high if CTA text) |
| asset | image aspect/crop/missing icon | medium |
| motion | transition/animation missing | low |
| untokenised | implementation uses literal value where a token exists | medium (always fix) |

`verify.md` format:

```
# Verify: <page> @ <width>

| # | Region | Category | Expected (design) | Actual (impl) | Severity | Fixed? |
|---|---|---|---|---|---|---|
| 1 | hero | spacing | gap --space-12 (48px) | 32px | medium | yes |
```

Rules:
- Measure with `getBoundingClientRect` / `getComputedStyle` on both renders;
  don't guess pixel values from screenshots.
- A diff caused by the design being desktop-only (no rules at 390) is not an
  implementation bug — log it under "design gaps", not the diff table.
- Fix all `high` before reporting; report `medium`/`low` with a proposal each.
