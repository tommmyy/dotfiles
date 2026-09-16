# Spec: <page or component name>

Source: <projectId / file> · Screens: `shots/<file>@390.png`, `shots/<file>@1280.png`

## 1. Purpose
One or two sentences: what this screen is for, who uses it, primary action.

## 2. Layout
| Region | 390 | 768 | 1280 | Notes |
|---|---|---|---|---|
| header | full, 56h | … | full, 64h | sticky |
| main | 1 col, px `--space-4` | … | max-w `--container-lg`, 12-col grid gap `--space-6` | |
| sidebar | hidden | hidden | 3/12 | |
| footer | … | … | … | |

Stacking / order changes between breakpoints:
- …

## 3. Component inventory
| # | Component | Existing equivalent in codebase | Variants | States present in design | Notes |
|---|---|---|---|---|---|
| 1 | ProductCard | `packages/ui/Card` (partial) | default, compact | default, hover | image aspect 4:5 |

For each component: slots/props it clearly needs, and which are fixed vs data-driven.

## 4. Tokens used
Colors (by role): `--color-primary` (CTA bg), `--color-surface-2` (cards) …
Typography: h1 `--text-3xl/--font-display/700`, body `--text-base` …
Spacing: section gaps `--space-12` desktop / `--space-8` mobile …
Radius / shadow / border: …
Untokenised values found: `13px` letter-spacing on eyebrow (flag)

## 5. Copy & content
Exact strings, grouped by region. Mark placeholder/lorem vs. real. CTA hierarchy:
primary → …, secondary → ….

## 6. Interaction & responsive behaviour
- Nav collapses to … at < 768
- Cards: 1 / 2 / 4 per row
- Hover/focus/active behaviours visible in HTML (`:hover`, `data-state`, JS): …
- Animations/transitions present: …

## 7. Accessibility observations (from `take_snapshot`)
Landmarks, heading order, unlabeled controls, contrast concerns.

## 8. Open questions for the user
Things the design does not answer: empty/error/loading states, long-text
overflow, RTL, keyboard nav, what "…" links to, etc.

## 9. Decisions from handoff chat (if a bundle with `chats/` was provided)
Bullet the iteration decisions that constrain implementation.
