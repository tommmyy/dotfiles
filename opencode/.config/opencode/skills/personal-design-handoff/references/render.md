# Rendering design HTML for screenshots

Read this when doing step 3 (render) or step 6 (verify) of
personal-design-handoff.

## Which URL to render

Prefer `claude-design`'s `render_preview` → `serve_url`: relative subresources
(CSS, fonts, images, `support.js` for `.dc.html`) resolve there, which `file://`
on a locally saved copy often can't. Fall back to the local `src/` copy only
when the preview is unavailable.

`serve_url` goes into the browser tool and nowhere else — not into a file, a
reply, or a commit.

## A. Playwright MCP (enabled in this setup)

Per file, per width:

1. `browser_resize` → `{ width: 390, height: 844 }`, then `{ 1280, 800 }`
   (add `{ 768, 1024 }` when a tablet layout exists). Resize **before**
   navigating so first paint uses the right viewport.
2. `browser_navigate` → the `serve_url` (or
   `file:///<abs>/design/<slug>/src/<file>.html`).
3. Wait for fonts: `browser_evaluate` →
   `() => document.fonts.ready.then(() => true)`.
4. `browser_take_screenshot` with `fullPage: true`,
   `filename: "shots/<file>@<width>.png"`, `scale: "css"`.
5. Once per file (at 1280): `browser_snapshot` → save to
   `shots/<file>.a11y.txt`. The structural tree (landmarks, headings, buttons,
   form fields) is far more useful than the HTML.
6. `browser_console_messages` with `level: "error"` — a silent JS error is the
   usual cause of a half-rendered mockup.

Measurement calls below use `browser_evaluate` with the snippet wrapped as
`() => (...)`.

## B. Chrome DevTools MCP (if you enable it)

Same sequence, different verbs: `navigate_page`, `resize_page`,
`evaluate_script`, `take_screenshot`, `take_snapshot`.

Measuring for the spec (at each width):

```js
// returns rects of the top-level layout regions
[...document.body.querySelectorAll('header,nav,main,section,aside,footer,[data-region]')]
  .map(el => {
    const r = el.getBoundingClientRect();
    return { tag: el.tagName, id: el.id, cls: el.className, x: r.x, y: r.y, w: r.width, h: r.height };
  })
```

```js
// computed typography of headings + body
[...document.querySelectorAll('h1,h2,h3,h4,p,button,a')].slice(0,60).map(el => {
  const s = getComputedStyle(el);
  return { tag: el.tagName, text: el.textContent.trim().slice(0,40),
           font: s.fontFamily, size: s.fontSize, weight: s.fontWeight,
           lh: s.lineHeight, color: s.color };
})
```

Record measured values in the spec by mapping them back to `tokens.json`
entries (e.g. `24px` → `--space-6`). If a value has no token, flag it as
`(untokenised)` in the spec — that is a finding, not a problem to hide.

## C. Headless script fallback

Batch capture without a browser MCP:

```
node <skill>/scripts/render.mjs design/<slug>/src design/<slug>/shots 390,768,1280
```

Requires `playwright` in the repo or globally (`npx playwright install
chromium` once). Accepts a URL instead of a directory for the step-6
implementation render.

## D. Why a render comes out blank/broken

| Symptom | Cause | Fix |
|---|---|---|
| Blank white page | script-driven mockup (React via CDN) blocked offline / CSP | render the `render_preview` `serve_url`, or serve `src/` with `npx serve` and navigate to `http://localhost:…` instead of `file://` |
| Literal `&lt;div&gt;` on screen | saved `read_file` output without decoding HTML entities | re-save the file with `&amp;` `&lt;` `&gt;` decoded |
| `.dc.html` renders unstyled/inert | `./support.js` missing next to it | copy `support.js` from the project into the same dir as the `.dc.html`, or render via `serve_url` |
| Fallback fonts | webfont loaded from Google Fonts / `@import` | allow network for the render, or map the family to a local font and note it in spec |
| Missing images | relative `./assets/...` not exported | fetch the assets dir via the MCP too; keep the same relative structure |
| Layout collapses at 390 | mockup has no responsive rules | record "desktop-only design" in spec → open question for the user |
| Elements overlap | `.dc.html` components expect a host stylesheet | render inside `assets/dc-host.html` shell which links the token/base CSS first |

## E. Implementation render (step 6)

Point the same procedure at the running app (`http://localhost:<port>/<route>`)
and save to `shots/impl/<page>@<width>.png`. Use the **same** widths and
`fullPage` setting, otherwise the diff is meaningless.
