# Glossary

Append-only. See `SKILL.md` for the rules.

## People

- **Tomáš Konrády** — the user. Slack `@tom`. Writes the code, owns the tenants
  below. "Tomáš" in a pasted thread = the user, not a colleague.
  <!-- learned 2026-08-28 -->
- **Martin Bartoš** — colleague. Product/QA side: reports widget bugs and
  cosmetic feedback from live tenants, usually in Czech, usually as a bulleted
  list under a `@tom <tenant-shorthand> <topic>` header (e.g. `@tom kzd asistent`).
  His messages are the primary input for `personal-slack-feedback-intake`.
  <!-- learned 2026-08-28 -->
- **Martin Bartoš** — also owns the **backend / ingest** side, not only
  product/QA. Data-pipeline problems (feed → `items-search__<alias>` and the
  other Typesense collections) are handed off to him. He also ships code in
  this repo (e.g. branch `martinbartos/alk_discount_label`). Confirmed by the
  user when handing over CUS-1048 (pft feed rows never ingested).
  <!-- learned 2026-08-31 -->

## Tenants

Shorthands used in chat map to `packages/tenant-<code>/` in
`~/workspaces/sdp/s-analytics/sources`. A message header like `@tom kzd asistent`
means "tenant kzd, topic: copilot".

| Shorthand | Package | Domain |
|---|---|---|
| `pft` | `packages/tenant-pft` | perfetto.sk (SK domain only) |
| `kzd` | `packages/tenant-kzd` | knihykazda.cz |
| `sps` | `packages/tenant-sps` | — (multi-domain: cz/sk/hu/ro) |

<!-- learned 2026-08-28 -->

## Product vocabulary

- **asistent / copilot** — the Zoe Copilot chat surface. Czech "asistent" ==
  copilot. <!-- learned 2026-08-28 -->
- **FAB** — `ZoeCopilotFabV0`, the floating action button that opens the
  copilot. Component: `packages/widget-preact/ZoeCopilotFabV0/`. Per-tenant
  wiring: `packages/tenant-<code>/domain-<cc>/copilotFab.js`.
  <!-- learned 2026-08-28 -->
- **touchpoint** — `ZoeCopilotTouchpointV0`, the in-content copilot entry point
  rendered next to/inside product widgets. Component:
  `packages/widget-preact/ZoeCopilotTouchpointV0/`. Per-tenant wiring:
  `packages/tenant-<code>/domain-<cc>/copilotTouchpoint.js`.
  <!-- learned 2026-08-28 -->
- **precart** — the **tenant's own native** add-to-cart modal/overlay (not ours).
  Appears after an add-to-cart and can cover our surfaces.
  <!-- learned 2026-08-28 -->
- **HP** — homepage. **SERP** — search results page.
  <!-- learned 2026-08-28 -->

## Agreed decisions

- **2026-08-28, Slack thread `@tom kzd asistent`** — first-time-user hint that
  the assistant exists should be a **tooltip like the one on tenant `sps`**,
  shown **once per session**, implemented **generically in the FAB**
  (`ZoeCopilotFabV0`) rather than per-tenant. Agreed by Martin (👍) and Tomáš.
  <!-- learned 2026-08-28 -->

## Tooling behaviour (measured)

- **Linear Slack bot** (`@Linear add the whole thread to the new triage issue.
  assign to me`) — captures the WHOLE thread, auto-sets the tenant project, the
  assignee and Triage. It writes an **English LLM summary**, not the Czech
  original, and it converts questions into imperatives. Provenance is the Slack
  permalink in `attachments[0].url`; the reporter's name is in
  `attachments[0].title`, while `createdBy` is whoever invoked the bot.
  **Linear → Slack comment sync is OFF.** <!-- learned 2026-08-28 -->
- **kzd copilot is dark-launched**: `copilot_init_alpha` treatment has weight 0
  (`tenant-kzd/common.js:54-61`). QA via `?saexp=copilot_init_alpha&sagrp=1`.
  `--variant=SA1.a.1%3BSA1.b.1` silently dropped the second experiment; the URL
  override merges correctly. Appending `&saexp=…` to a kzd *search* URL
  redirects to the homepage — seed on the homepage, then load a clean SERP URL.
  <!-- learned 2026-08-28 -->

## Open questions

- **How does one add a product to the cart from the assistant on kzd?** Across
  7 prompts + the PD context screen, no chat reference card renders an
  add-to-cart button: `tenant-kzd/src/widgets/templates/ProductBox.jsx:24-27`
  requires exactly one `type` param value, and kzd titles have two (Tištěná
  kniha / E-kniha). Blocks verification of PER-1063. <!-- learned 2026-08-28 -->

