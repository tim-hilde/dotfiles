# Pattern catalog

Nine families of work where a self-contained `.html` file beats markdown. Find the one
closest to the request, then use its layout / interaction / export recipe. These are
starting points, not rigid templates — adapt freely.

## Contents

1. [Exploration & Planning](#1-exploration--planning)
2. [Code Review & Understanding](#2-code-review--understanding)
3. [Design](#3-design)
4. [Prototyping](#4-prototyping)
5. [Illustrations & Diagrams](#5-illustrations--diagrams)
6. [Decks](#6-decks)
7. [Research & Learning](#7-research--learning)
8. [Reports](#8-reports)
9. [Custom Editing Interfaces](#9-custom-editing-interfaces)
10. [Shared techniques](#shared-techniques) — copy-export, arrow-key nav, collapsibles, tabs, inline SVG

---

## 1. Exploration & Planning

*When the user isn't sure what they want yet, or has decided and needs a plan to hand off.*

- **Multiple approaches side by side.** Render N options (code strategies, layouts) in
  parallel columns or cards so the user can point at one instead of holding three
  sequential descriptions in their head. Call out trade-offs inline under each option —
  a small "pros / cons / cost" block, not a separate section the reader has to cross-reference.
- **Visual design directions.** Render the actual layouts/palettes live so the user reacts
  to them rather than imagining them. A swatch they can see beats a hex code they have to picture.
- **Implementation plan (the handoff).** Milestones on a horizontal timeline, a data-flow
  diagram (inline SVG), inline mockups of key screens, the genuinely risky code shown
  verbatim, and a risk table. This is the plan the implementer actually reads.

Export: for approach comparisons, a "copy the chosen approach as markdown" button helps the
user feed their pick straight into the next prompt.

## 2. Code Review & Understanding

*Diffs and call graphs are spatial; markdown flattens them.*

- **Annotated diff.** Render the diff with margin notes, severity tags (info / warn /
  blocker as colored pills), and jump links to each file. Easier to scan than scrolling a terminal.
- **PR writeup for reviewers.** The author's side: motivation, before/after, a file-by-file
  tour explaining the *why* of each change, and an explicit "focus your review here" pointer.
- **Module map.** Draw an unfamiliar package as boxes and arrows (inline SVG), highlight the
  hot path, list entry points. Make the shape of the code visible at a glance.

## 3. Design

*HTML is the medium a design system ships in, so it's the natural format to discuss it.*

- **Living design system.** Pull colors / type scale / spacing tokens from the repo and
  render them as swatches and specimens the user can copy values from.
- **Component variants (contact sheet).** Every size, state, and intent of one component
  laid out on a single sheet for review.

The artifact can be fed straight back into the next prompt as the source of truth.

## 4. Prototyping

*Motion and interaction can only be felt, not described.*

- **Animation sandbox.** The transition in isolation, with sliders for duration and easing
  so the user can tune it before it gets wired in. Show the resulting CSS live.
- **Clickable flow.** A handful of linked screens — just enough fidelity to feel whether the
  interaction is right. Plain anchor links or a tiny show/hide router is enough.

## 5. Illustrations & Diagrams

*Inline SVG gives you a real pen.*

- **SVG figure sheet.** The diagrams for a post, drawn inline as vector art the user can
  tweak by hand or copy out one figure at a time.
- **Annotated flowchart.** A pipeline or process as a real flowchart; make each step
  clickable to reveal what runs, timings, and failure paths.

Hand-authored inline `<svg>` (paths, rects, text) beats an image — it's editable and crisp.

## 6. Decks

*A few `<section>` tags plus ~20 lines of JS is a slide deck — no Keynote, no export step.*

- One `<section>` per slide, all but the first hidden. Left/right arrow keys (and click)
  advance. A small slide counter helps. Point the agent at a thread or doc and get something
  the user can arrow-key through in a meeting. See [Shared techniques](#shared-techniques).

## 7. Research & Learning

*An explainer with structure reads very differently from the same words dumped linearly.*

- **Feature explainer ("how does X work in this repo").** TL;DR box up top, collapsible
  request-path / step-by-step sections, tabbed code snippets for different configs, and an FAQ.
- **Concept explainer.** Teach with a live interactive widget where it helps (e.g. a ring you
  add/remove nodes from for consistent hashing), a comparison table, and a hover-linked glossary
  in the margin so terms are defined without breaking the reading flow.

## 8. Reports

*Recurring documents benefit most from a little structure and color.*

- **Weekly status.** What shipped, what slipped, and one small chart — formatted for a quick
  Monday skim, not a paragraph to parse.
- **Incident timeline / post-mortem.** A minute-by-minute colored timeline, log excerpts in
  monospace blocks, and a follow-up checklist.

A small inline chart or a colored timeline turns something people skim into something they read.

## 9. Custom Editing Interfaces

*When it's hard to describe what you want in a text box, ask for a throwaway editor for the
exact thing you're working on. **Always end with an export button.***

- **Triage board.** Drag items across columns (Now / Next / Later / Cut), then copy the final
  ordering out as markdown.
- **Toggle / config editor.** Settings grouped by area, dependency warnings when a prerequisite
  is off, and a "copy diff" button for just the changed keys.
- **Prompt tuner.** An editable template on the left with variable slots highlighted; sample
  inputs on the right that re-render live as the user types.

The rule: the user manipulates the UI, the export turns whatever they did back into text they
paste to the agent or commit. The human stays in the loop; the loop gets tighter.

---

## Shared techniques

Small, dependency-free building blocks. All inline, all work from `file://`.

### Copy / export to clipboard (the most important one)

```js
function exportState() {
  // build markdown / JSON / diff from current DOM or state, then:
  const text = buildExportText();
  navigator.clipboard.writeText(text)
    .then(() => { btn.textContent = 'Copied!'; setTimeout(() => btn.textContent = 'Export', 1200); });
  // also drop it in a <textarea> as a fallback for file:// clipboard restrictions
  document.getElementById('out').value = text;
}
```

Always provide a visible `<textarea>` fallback — `navigator.clipboard` is sometimes blocked on
`file://`. Never ship an editor without this.

### Arrow-key slide deck

```html
<section class="slide">…</section>  <!-- repeat per slide -->
<script>
  const slides = [...document.querySelectorAll('.slide')];
  let i = 0;
  const show = n => slides.forEach((s, k) => s.hidden = k !== n);
  addEventListener('keydown', e => {
    if (e.key === 'ArrowRight') i = Math.min(i + 1, slides.length - 1);
    if (e.key === 'ArrowLeft')  i = Math.max(i - 1, 0);
    show(i);
  });
  show(0);
</script>
```

### Collapsible sections

Prefer native `<details><summary>Heading</summary> … </details>` — zero JS, accessible,
works everywhere.

### Tabs (e.g. config snippets)

Radio inputs + labels + CSS sibling selectors give tabs with no JS; or a few lines toggling a
`.active` class. Keep it minimal.

### Inline SVG diagrams

Author `<svg viewBox="0 0 W H">` with `<rect>`, `<line>`/`<path>` (use `marker` for arrowheads),
and `<text>`. It stays editable and crisp, and the user can copy a single figure out. Reach for a
JS diagram library only for genuinely dynamic graphs; static boxes-and-arrows are just SVG.

### Small charts without a dependency

A bar chart is `<div>`s with percentage heights/widths; a sparkline or line chart is one inline
`<svg>` `<polyline>`. Only pull in a charting library (single CDN `<script>`) when the chart is
genuinely complex.

### Styling baseline

Use the house style in `references/style.md` — paste its `:root` token block, then build with
those variables (ivory page, white panels with `1.5px` `--g300` borders, serif headings, one clay
accent). That file is the single source of truth for the look; don't hand-roll a palette here.
