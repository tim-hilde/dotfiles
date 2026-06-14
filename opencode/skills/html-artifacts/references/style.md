# Visual style — the default look

Every artifact this skill produces should use this design system unless the user asks for
something else. It's a warm, light, editorial aesthetic: ivory paper, slate ink, a single clay
accent, serif headings over a sans body. Restraint reads as quality — resist dark mode, neon
accents, and heavy borders. Drop this `:root` block into every page and build from it.
A fully rendered page using this system lives at `example.html` in this folder — open it to see
the tokens, type, semantic colors, and layout applied; match it.

## Design tokens

Paste verbatim into the inline `<style>`:

```css
:root{
  /* surfaces */
  --ivory:#FAF9F5;   /* page background */
  --paper:#FFFFFF;   /* cards / panels */
  --g100:#F0EEE6;    /* subtle fills, code bg, alt rows */
  --g200:#E6E3DA;
  --g300:#D1CFC5;    /* borders */
  --g500:#87867F;    /* muted text */
  --g700:#3D3D3A;    /* secondary ink */
  /* ink + accent */
  --slate:#141413;   /* primary text */
  --clay:#D97757;    /* the one accent — links, active state, key marks */
  --clay-d:#B85C3E;  /* accent hover / pressed */
  --rust:#B04A3F;    /* errors, blockers, high severity */
  --olive:#788C5D;   /* success / positive / "good" */
  --oat:#E3DACC;     /* warm secondary fill, highlight bg */
  /* type */
  --serif:ui-serif,Georgia,"Times New Roman",Times,serif;
  --sans:system-ui,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  --mono:ui-monospace,"SF Mono",Menlo,Monaco,Consolas,monospace;
  /* shape */
  --radius-panel:12px;
  --radius-row:8px;
  --border:1.5px solid var(--g300);
}
```

## Base rules

```css
*{box-sizing:border-box}
body{
  margin:0; padding:56px 24px 120px;
  background:var(--ivory); color:var(--slate);
  font-family:var(--sans); font-size:15px; line-height:1.6;
  -webkit-font-smoothing:antialiased;
}
.wrap{max-width:920px;margin:0 auto}        /* 1100–1200px for multi-column boards */
h1{font-family:var(--serif);font-weight:500;font-size:36px;letter-spacing:-.01em;line-height:1.2;margin:0 0 18px}
h2{font-family:var(--serif);font-weight:500;font-size:24px;letter-spacing:-.01em;margin:28px 0 6px}
h3{font-family:var(--serif);font-weight:500;font-size:18px;margin:20px 0 4px}
a{color:var(--clay);text-decoration:none}
a:hover{color:var(--clay-d);text-decoration:underline}
code,pre{font-family:var(--mono);background:var(--g100);border-radius:6px}
code{padding:1px 5px;font-size:.86em}
pre{padding:12px 14px;overflow:auto;border:var(--border)}
.panel,.card{background:var(--paper);border:var(--border);border-radius:var(--radius-panel);padding:18px}
.muted{color:var(--g500)}
button{font:inherit;cursor:pointer;border:var(--border);background:var(--paper);color:var(--slate);
  border-radius:9px;padding:8px 14px}
button.primary{background:var(--clay);border-color:var(--clay);color:var(--paper);font-weight:600}
button:hover{filter:brightness(.98)}
```

## Principles

- **Serif headings, sans body, mono for code.** This contrast carries the editorial feel — never set headings in the sans font.
- **One accent.** Clay is the only color that draws the eye: links, the active item, the primary button, a key callout's left border. Don't introduce a second bright color.
- **Semantic colors are muted, not neon.** Use `--olive` for good/success, `--rust` for error/blocker/high-severity, `--clay` for "focus here / recommended". Render status as a small dot, a pill with a `1.5px` border, or a colored left-border — not large saturated fills.
- **Borders over shadows.** `1.5px solid var(--g300)` on white panels against the ivory page. Shadows, if any, are barely-there. Radius 12px panels, 8px rows.
- **Whitespace is the layout.** Generous body padding (`56px 24px 120px`), a readable `max-width`, real breathing room between sections. Don't crowd.
- **Light only.** This system is light by design. Only go dark if the user explicitly asks — and when they do, use the opt-in dark-mode recipe in `patterns.md` (FOUC-safe, warm token overrides, persisted), never a per-page palette.

## Quick semantic-color map

| meaning | token |
|---|---|
| good / success / positive / "kept" | `--olive` |
| error / blocker / high severity / "cut" | `--rust` |
| focus / recommended / active / link | `--clay` |
| neutral / info / muted | `--g500` |
| warm highlight / selected-row bg | `--oat` or `--g100` |

When a page needs more than these (e.g. a four-lane board), derive lanes from the palette
(clay, olive, a muted gray, rust) rather than reaching for new hues.
