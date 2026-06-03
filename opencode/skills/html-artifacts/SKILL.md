---
name: html-artifacts
description: Produce a single self-contained .html file instead of a wall of markdown whenever the output is something the user would scan, point at, tune, or manipulate rather than read top-to-bottom. Use this whenever you're about to hand back a long markdown comparison, plan, code review, PR writeup, module/architecture overview, design-system or component reference, flowchart or diagram, slide deck, status report, post-mortem, concept explainer, or any "pick one of these options" output — and ESPECIALLY when the user needs a throwaway editor, triage board, toggle panel, or other small interface to do something hard to describe in a text box. Reach for it even when the user never said "HTML" — if the information is spatial (diffs, call graphs, timelines), comparative (options side by side), interactive (motion, click-through), or editable (rearranged and handed back), an .html file beats markdown. Skip it only for short factual answers, small code snippets, or when the user explicitly wants markdown/plain text.
---

# HTML Artifacts

Markdown flattens everything into one scrollable column. A lot of agent output isn't a column — it's a comparison you point at, a diff with spatial shape, a timeline, a thing you tune until it feels right, or a small tool you manipulate and hand back. For that work, produce **one self-contained `.html` file** the user opens directly in a browser. It trades a document they'd skim for one they'd actually read.

This is not about making things fancy. It's about matching the format to the shape of the information.

## When to produce HTML instead of markdown

Reach for an `.html` file when the content is any of:

- **Comparative** — several options/approaches/designs the user picks between. Side-by-side beats three sequential walls they have to hold in their head.
- **Spatial** — diffs, call graphs, module maps, data flows, timelines. The arrangement *is* the information; a column destroys it.
- **Interactive / felt** — motion, easing, click-through flows. You can't describe an animation; the user has to feel it in five seconds.
- **Editable** — the user will rearrange, toggle, or triage something and hand the result back. Give them a real interface, not a list they edit by hand.
- **Navigable reference** — design tokens, component variants, explainers with collapsible detail and a glossary. Structure makes a new topic browsable instead of linear.
- **Recurring + skimmable** — status updates, post-mortems. A small chart and a colored timeline turn something people skim into something they read.

**Stay in markdown / plain prose when:** the answer is a short fact, a small code snippet, a quick explanation, the user explicitly asked for markdown or plain text, or the output will be consumed by another tool that expects text. Don't wrap a two-sentence answer in HTML.

If you're unsure, ask yourself: *would the user rather read this, or look at / poke at it?* If the latter, build the page.

## Hard requirements

These are non-negotiable — they're what makes the artifact actually useful:

1. **One file, self-contained.** All CSS in an inline `<style>`, all JS in an inline `<script>`. The user double-clicks the file and it works from `file://` with no server, no build step, no `npm install`.
2. **No build tooling, no framework scaffold.** Vanilla HTML/CSS/JS. Inline SVG for diagrams. If you genuinely need a library (e.g. a charting lib), pull exactly one from a CDN via `<script src>` — but most pages need zero dependencies, and a page that works offline is better than one that doesn't. Default to none.
3. **Editors and boards ALWAYS end with an export.** If the page lets the user *do* something — reorder tickets, flip flags, tune a prompt — it must have a button that turns the current UI state back into text (markdown, JSON, or a diff) they can copy and paste back to you or commit. The whole point is keeping the human in the loop while tightening it. A board with no export is a dead end.
4. **Readable on its own.** It will be opened cold, days later, by someone who lost the chat context. Give it a title, brief framing, and enough labels that it stands alone.
5. **Use the house style.** Every page uses the warm editorial design system in `references/style.md` — ivory paper, slate ink, one clay accent, serif headings over a sans body. **Read that file and paste its `:root` token block before writing any markup.** Don't invent a palette per page, and don't default to dark mode. Go off-style only if the user explicitly asks.

## Output

Save the file with a descriptive name (e.g. `auth-approaches-comparison.html`, `incident-2026-05-timeline.html`) and present it to the user. Lead with one or two sentences on what it is and how to use it (e.g. "arrow keys to navigate", "drag tickets, then hit Export"). Don't dump the full source into the chat as a wall of code — the file is the deliverable.

## Pattern catalog

The article this skill is based on documents nine families of work, each with concrete techniques (annotated-diff layout, arrow-key deck JS, collapsible explainers, drag-and-drop boards with markdown export, inline-SVG flowcharts, and more). **Before building, read `references/patterns.md`** and find the pattern closest to the request — it tells you the layout, the interaction, and the export format that work for that kind of artifact, so you don't reinvent them each time.

For visual polish on anything design-facing, the look is fully specified in `references/style.md` (tokens, type, semantic colors, layout rules) — that file is authoritative for *how it looks*, while this skill and `patterns.md` govern *what format and structure* to use. If the `frontend-design` skill is available, it can supplement for one-off aesthetic decisions, but `style.md` is the default and takes precedence.
