# Design: Full campaign articles, native on the site

**Date:** 2026-07-21
**Status:** Implemented in PR #209
**Branch:** feat/onsite-campaign-articles

## Problem

The bake-off blog page (`/blog/ethereum-client-bakeoff`) on the live site
(`eth2quickstart.com`) shows only a TL;DR + scorecard and links **out to GitHub**
for the full write-up. The campaign's long-form articles (the bake-off write-up,
the "how we tested with Claude" 23-day harness story, the harness engineering
deep-dive, and the raw results) are not readable natively on the site. The owner
wants to fully browse every article **on the site** — not be bounced to GitHub —
before signing off on the content.

## Goal

All four campaign articles render as native, on-site JSX pages under `/blog`,
faithful to their source markdown, styled with the existing design system.

## Source docs → routes

| Route | Source doc | Owner |
|---|---|---|
| `/blog/ethereum-client-bakeoff` (expand in place) | `docs/CLIENT_BAKEOFF_BLOG.md` | this branch |
| `/blog/bakeoff-harness` (new) | `docs/CLIENT_BAKEOFF_HARNESS.md` | this branch |
| `/blog/bakeoff-results` (new) | `docs/CLIENT_BAKEOFF_RESULTS.md` | this branch |
| `/blog/how-we-tested-with-claude` | `docs/HOW_WE_TESTED_WITH_CLAUDE.md` | PR #209 (integrated from #208, stacked on #207) |

## Approach (decided)

- **Hand-authored JSX pages**, one per article — no markdown pipeline. Matches the
  existing bake-off page and the integrated how-we-tested page from #208 (the gold-standard full-article
  template: sections TL;DR → At a glance → narrative → Reproduce it).
- **Design system only:** `Card`, `Badge`, `Button`, `CodeBlock`, responsive tables
  (desktop `<table>` + mobile stacked cards), inline SVG charts. No new dependencies.
- **Fidelity is the point:** every number, verdict, and claim must match the source
  `.md` exactly. Builders must not paraphrase data or invent figures. Reviewer (Opus)
  diffs each finished page against its source doc before it counts as done.
- **Bake-off page:** keep the existing TL;DR/scorecards as the lede; add the full
  write-up narrative below; demote the four GitHub buttons to a "Sources" footer
  (view-on-GitHub), since the content now lives on-site.
- **Blog index (`/blog`):** list all four articles.

## Build mechanism

Opus orchestrates and reviews; **fresh Sonnet subagents** each author one page
(the delegation pattern used when the original article was built). Builders touch
only their single page file and do not run installs/builds — Opus verifies centrally
(typecheck + production build + render check) and reviews fidelity vs source.

## Integration status

- Commit `01683f2` integrated the final how-we-tested page and screenshots from #208, plus #207's final restructured source document and Mermaid evidence.
- PR #209 now owns the combined four-article delivery; #207 and #208 are superseded and must not merge separately.

## Deliverable

A running build of the site with all four full articles rendering. Provide the owner
a way to read each (screenshots per page and/or the built pages) to vet content
before anything is pushed.

## Non-goals

- No markdown/MDX pipeline.
- No merge to master until the owner signs off on content.
- No separate merge of the superseded #207 or #208 branches.

## Verification

`bunx tsc --noEmit` clean · `bun run build` succeeds with all routes generated ·
each page renders (prerendered HTML contains its sections) · Opus fidelity-diff of
each page against its source doc.
