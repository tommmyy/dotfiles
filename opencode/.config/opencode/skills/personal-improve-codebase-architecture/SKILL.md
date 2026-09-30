---
name: personal-improve-codebase-architecture
description: Scan a codebase for deepening opportunities (shallow modules that should become deep ones), present them as a visual HTML report, then grill the user through whichever one they pick.
metadata:
  opencode/autoinvoke: false
---

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities**: refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

Ported from Matt Pocock's [`improve-codebase-architecture`](https://github.com/mattpocock/skills/tree/main/skills/engineering/improve-codebase-architecture) (MIT, see `LICENSE`).

This command is _informed_ by the project's domain model and built on a shared design vocabulary:

- Load the `personal-codebase-design` skill for the architecture vocabulary (**module**, **interface**, **depth**, **seam**, **adapter**, **leverage**, **locality**) and its principles (the deletion test, "the interface is the test surface", "one adapter = hypothetical seam, two = real"). Use these terms exactly in every suggestion, and don't drift into "component," "service," "API," or "boundary."
- The domain language in `GLOSSARY.md` gives names to good seams; ADRs in `docs/adr/` record decisions this command should not re-litigate. Many repos have neither; also read `AGENTS.md` / `CLAUDE.md` and any architecture docs for the same purpose.

## Process

### 1. Explore

**Scope before you scan: YAGNI.** Deepening a module pays off by making future changes to it easier, so put extra weight on the parts of the codebase that have recently changed. Decide *where* to look before you look:

- If the user named a direction (a module, a subsystem, a pain point), take it, and skip the inference below.
- Otherwise, walk back a good stretch of the commit history to find the codebase's hot spots, the files and areas that keep coming up, and let those paths pull your attention first. If the changes are scattered with no clear hot spot, widen the net. A quick churn ranking:

  ```sh
  git log --since='3 months ago' --name-only --format= | grep -v '^$' | sort | uniq -c | sort -rn | head -40
  ```

Read the project's domain glossary (`GLOSSARY.md`, or `GLOSSARY-MAP.md` for multi-context repos) and any ADRs in the area you're touching first.

Then spawn an `explore` subagent (thoroughness "very thorough") to walk the scoped area. For a large scope, split it and run several in parallel. Paste the Glossary section of the `personal-codebase-design` skill into each prompt, since subagents start with no context. Don't follow rigid heuristics; explore organically and note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow**, with an interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow: would deleting it concentrate complexity, or just move it? A "yes, concentrates" is the signal you want. Verify each finding against the code yourself before it goes into the report.

### 2. Present candidates as an HTML report

Write a self-contained HTML file to the temp directory so nothing lands in the repo: `$TMPDIR/architecture-review-<repo>-<YYYYMMDD-HHMMSS>.html` (fall back to `/tmp` if `$TMPDIR` is unset), so each run gets a fresh file. Show it to the user with `browser.preview` via `execute` (opens it in the Review pane); if that's unavailable, run `open <path>`. Always print the absolute path.

The report uses **Tailwind via CDN** for layout and styling, and **Mermaid via CDN** for diagrams where a graph/flow/sequence reliably communicates the structure. Mix Mermaid with hand-crafted CSS/SVG visuals: use Mermaid when relationships are graph-shaped (call graphs, dependencies, sequences), and hand-built divs/SVG when you want something more editorial (mass diagrams, cross-sections, collapse animations). Each candidate gets a **before/after visualisation**. Be visual.

For each candidate, render a card with:

- **Files**: which files/modules are involved
- **Problem**: why the current architecture is causing friction
- **Solution**: plain English description of what would change
- **Benefits**: explained in terms of locality and leverage, and how tests would improve
- **Before / After diagram**: side-by-side, custom-drawn, illustrating the shallowness and the deepening
- **Recommendation strength**: one of `Strong`, `Worth exploring`, `Speculative`, rendered as a badge

End the report with a **Top recommendation** section: which candidate you'd tackle first and why.

**Use GLOSSARY.md vocabulary for the domain, and the `personal-codebase-design` vocabulary for the architecture.** If `GLOSSARY.md` defines "Order," talk about "the Order intake module," not "the FooBarHandler," and not "the Order service."

**ADR conflicts**: if a candidate contradicts an existing ADR, only surface it when the friction is real enough to warrant revisiting the ADR. Mark it clearly in the card (e.g. a warning callout: _"contradicts ADR-0007, but worth reopening because…"_). Don't list every theoretical refactor an ADR forbids.

See [HTML-REPORT.md](HTML-REPORT.md) for the full HTML scaffold, diagram patterns, and styling guidance.

Before handing it over, check that the Mermaid diagrams render: load the file in the headless Playwright browser and look for Mermaid error blocks ("Syntax error in text"). Fix any that fail.

Do NOT propose interfaces yet. After the file is written, list the candidates in chat (title + strength, one line each) and ask the user: "Which of these would you like to explore?"

### 3. Grilling loop

Once the user picks a candidate, load the `personal-grilling` skill to walk the decision tree with them: constraints, dependencies, the shape of the deepened module, what sits behind the seam, what tests survive. Fact-finding questions go to an `explore` subagent, not to the user.

Side effects happen inline as decisions crystallize; load the `personal-domain-modeling` skill to keep the domain model current as you go:

- **Naming a deepened module after a concept not in `GLOSSARY.md`?** Add the term to `GLOSSARY.md`. Create the file lazily if it doesn't exist.
- **Sharpening a fuzzy term during the conversation?** Update `GLOSSARY.md` right there.
- **User rejects the candidate with a load-bearing reason?** Offer an ADR, framed as: _"Want me to record this as an ADR so future architecture reviews don't re-suggest it?"_ Only offer when the reason would actually be needed by a future explorer to avoid re-suggesting the same thing; skip ephemeral reasons ("not worth it right now") and self-evident ones.
- **Want to explore alternative interfaces for the deepened module?** Follow `DESIGN-IT-TWICE.md` from the `personal-codebase-design` skill (parallel `general` subagents).

The session ends when the grilling frontier is empty and the user confirms shared understanding. Don't start implementing unless the user asks for it.
