# Blog & Presentation Guide

How the marketing-site blog and the bake-off slide deck work — for presenting, sharing, and editing.

The blog lives in the Next.js frontend (`frontend/app/blog/`). Articles are **hand-authored TSX pages** (no CMS, no markdown pipeline) that reuse the site's design-system components. There are four campaign articles plus an index:

| Route | Source page |
|-------|-------------|
| `/blog` | `frontend/app/blog/page.tsx` (index) |
| `/blog/ethereum-client-bakeoff` | the full write-up |
| `/blog/how-we-tested-with-claude` | the AI-agent methodology |
| `/blog/bakeoff-harness` | the function-level harness reference |
| `/blog/bakeoff-results` | the raw results |

---

## Sharing an article — deep links to any subheading

Every section subheading is a **direct link**. On the live site:

1. Hover a subheading (on touch devices the icon is always faintly visible).
2. A **link icon** appears next to it — click it.
3. The exact URL is copied to your clipboard, e.g.
   `https://eth2quickstart.com/blog/ethereum-client-bakeoff#the-disk-story`
4. Paste it to a friend — their browser scrolls straight to that section/chart.

Each article also has a **Contents** nav near the top linking every section.

Under the hood this is the `AnchorHeading` component (`frontend/components/ui/AnchorHeading.tsx`): it renders a heading with a stable `id` and a copy-link button that sets the URL hash and copies the absolute URL (only confirming once the clipboard write succeeds). Use it for any new section heading:

```tsx
<AnchorHeading id="the-disk-story" className="text-lg sm:text-xl font-semibold text-foreground">
  The disk story
</AnchorHeading>
```

Slugs are kebab-case and must be unique per page; reuse a page's existing Contents slug so the nav keeps resolving.

## Link previews (OpenGraph)

Each article sets its own OpenGraph + Twitter card so a pasted link unfurls with a branded image, not bare text. The images live in `frontend/public/` (`og-bakeoff.png`, `og-how-we-tested.png`, `og-harness.png`, `og-results.png`; `og.png` is the site default). To regenerate them, edit the card definitions in [`frontend/scripts/gen-og-cards.py`](../frontend/scripts/gen-og-cards.py) and run `python3 frontend/scripts/gen-og-cards.py` (set `CHROME_BIN` to a Chromium/Chrome binary if it isn't auto-found) — it renders the card template to 1200×630 PNGs directly into `frontend/public/`. A page opts into its card via its `metadata` export:

```ts
openGraph: { type: 'article', images: ['/og-bakeoff.png'], url: '/blog/ethereum-client-bakeoff', ... },
twitter:  { card: 'summary_large_image', images: ['/og-bakeoff.png'], ... },
```

## Diagrams (no Mermaid)

The frontend has **no Mermaid renderer** — never paste raw Mermaid source into a `CodeBlock`, it renders as broken text. Diagrams are hand-authored div/SVG components. See the pattern in `how-we-tested-with-claude/page.tsx` (`FlowDiagram`, `AgentHierarchy`, `VerdictDiagram`, `CampaignTimeline`) and `bakeoff-harness/page.tsx` (`DataFlowDiagram`).

---

## The presentation deck

A self-contained slide deck of the bake-off, for presenting and sharing.

- **Live on the site:** [`/deck/bakeoff.html`](https://eth2quickstart.com/deck/bakeoff.html) — source: `frontend/public/deck/bakeoff.html`.
- **Hosted artifact (private, shareable):** https://claude.ai/code/artifact/42f02b4d-3a8e-4601-9ded-5ac2dd4bb643

### Controls

| Key / action | Does |
|--------------|------|
| `→` / `Space` / click right half | Next slide |
| `←` / click left half | Previous slide |
| `Home` / `End` | First / last slide |
| **`N`** | Toggle **speaker notes** (one prompt per slide) |
| **`P`** | **Print / export to PDF** — each slide becomes one landscape page |
| `#7` in the URL | Deep-link straight to slide 7 |
| ◐ (top-right) | Toggle light / dark |

### Presenting & handouts

- Present full-screen from the live URL or the artifact; press `N` to bring up your notes.
- To hand out slides, press `P` and "Save as PDF" (or `Cmd/Ctrl+P`). It's already sized for one 16:9 page per slide.

### Editing the deck

The deck is one HTML file (inline CSS/JS, no build step). Edit `frontend/public/deck/bakeoff.html`: slide content is in the `<section class="slide">` blocks; speaker notes are the `NOTES` array in the `<script>`; the data-gauge values are the `--v` CSS custom properties on each bar.

---

## Adding a new article

1. Create `frontend/app/blog/<slug>/page.tsx` — copy an existing article's structure (metadata export, `AnchorHeading` sections, design-system components).
2. Add its `openGraph`/`twitter`/`canonical` metadata and (optionally) a new `og-<slug>.png`.
3. Add a card for it to the blog index (`frontend/app/blog/page.tsx`) and cross-link it from the sibling articles' "Read next" sections.
4. `cd frontend && bun run build` to verify it compiles and prerenders.
