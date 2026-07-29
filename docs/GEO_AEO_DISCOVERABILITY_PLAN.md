# GEO / AEO + SEO Discoverability Plan — eth2-quickstart

**Status:** APPROVED (2026-07-29) — chimera_defi approved the plan. Decisions: **(A)** build it out now via a Sonnet builder subagent + Devin adversarial-review delegate → one PR (no self-merge); **(B)** dedicated `/agents` page = YES; **(C)** also scope a hosted/remote MCP as a follow-up. Website code scope is being implemented on branch `feat/geo-aeo-agent-discoverability`. Off-site/auth-gated items (A1 repo metadata, A4 registries, A5 backlinks) and the hosted-MCP scope are captured in companion docs.
**Author:** Claude Opus 4.8 (cloud agent session `ah-eth2qs-orch-0729-1649`).
**Goal:** make this Ethereum node-setup tooling + its website maximally discoverable and *usable* by AI agents (GEO/AEO), on top of traditional SEO for humans — so that when a user tells *their* agent "set up an Ethereum validator," ours is found, chosen, and driven end-to-end.

---

## TL;DR — the one strategic insight

The **repo already has a mature agent-operability layer** (a skill-creator-format skill, an MCP server, a stable `./scripts/eth2qs.sh` wrapper with `--json` everywhere, `llms.txt` + `llms-full.txt`, ClawHub/Claude-plugin packaging). The "an agent CAN drive it" half is **largely solved and should not be rebuilt.**

The gap is **discovery and the website**, in three specific ways:

1. **FIND (off-site) is neglected.** The GitHub repo — the single most likely thing an agent actually lands on — has a dated one-line description, **zero topics**, no homepage URL, and no custom social image. The MCP server/skill are in **no public registry**. This is the cheapest, highest-leverage work and it's almost entirely untouched.
2. **The website (eth2quickstart.com) exposes none of the agent layer** and lacks the structured data + prompt-aligned content that answer-engines actually reward. `eth2quickstart.com/llms.txt` returns **404** (verified). No `SoftwareApplication`/`HowTo`/`FAQPage` JSON-LD. No "For AI Agents" surface.
3. **The two surfaces are half-bridged.** README → website link exists; website → agent-layer link does **not**. `llms.txt` never mentions the website.

**Honest framing (grounded in mid-2026 research, not hype):** `llms.txt` today has ~6–10% adoption and AI crawlers rarely fetch it — it's a cheap, forward-looking, no-downside complement, **not** a citation-lift lever. Generative engines crawl **HTML directly**, so the real AEO wins are **structured data + question-shaped content + off-site distribution**. `SoftwareApplication` schema is the defensible centerpiece; `FAQPage`/`HowTo` help **LLM answer extraction** (Google curtailed FAQ rich-results to gov/health and deprecated HowTo rich-results ~2023 — do not promise Google snippets).

---

## Framework: the user's own three verbs

Every recommendation maps to one stage of the target scenario:

| Verb | Question it answers | Where it lives |
|------|--------------------|----------------|
| **FIND** | Does the agent surface us at all? | Off-site distribution, SEO, structured data |
| **CHOOSE** | Once found, does the agent pick us? | Prompt-aligned content, comparison, credibility |
| **DRIVE** | Once chosen, can the agent operate us end-to-end? | The repo agent layer (**already strong** — gaps only) |

---

## Current-state audit (credit where due — do NOT rebuild)

**Already in place (DRIVE — mature):**
- `skills/eth2-quickstart/SKILL.md` — Anthropic skill-creator format, strong trigger-phrase `description`, routing, safety rules, 10 reference docs (`workflow`, `operator`, `commands`, `safety`, `sizing`, `outputs`, `examples`, `mcp`, `improvement`, `evals`).
- `mcp_server/` — Python MCP server (`eth2qs_mcp_server.py` + tools), `run_eth2qs_mcp.sh`, `scripts/install_claude_eth2qs_mcp.sh`. Read-only funds-safety contract (`eth2qs_validators`, `eth2qs_validator_op_preview`).
- `scripts/eth2qs.sh` — one wrapper, ~28 subcommands, `--json` on `doctor`/`stats`/`plan`/`debug`/`update-check`/`monitor export`/`client-options`/`validators`. Non-interactive `bootstrap --non-interactive`, `phase1`, `phase2 --execution=… --consensus=… --mev=…`.
- `llms.txt` + `llms-full.txt` at repo root — valid llms.txt format, links to skill/refs/MCP.
- `.claude-plugin/{marketplace.json,plugin.json}`, `docs/AGENT_SKILL_LISTING.md`, `docs/AGENT_SKILL_PLAN.md` — packaging + listing groundwork.
- `README.md` — keyword-rich `# Ethereum Node Quick Setup`, a "For External Agents" section, links to the website.

**Already in place (SEO — good baseline):**
- `frontend/app/layout.tsx` — correct `metadataBase: https://eth2quickstart.com`, OpenGraph + Twitter `summary_large_image`, `next/font` (fonts load), skip-to-content.
- `frontend/app/sitemap.ts` + `robots.ts` — dynamic, cover homepage/quickstart/blog/4 articles/deck.
- `frontend/components/ui/ArticleJsonLd.tsx` — `BlogPosting` + `BreadcrumbList` JSON-LD on all 4 blog articles, per-article OG cards.
- `frontend/lib/articles.ts` — single source of truth for article identity; `SITE_CONFIG.url`.

**The gaps this plan fills** are enumerated below by verb.

---

## TRACK A — FIND (highest ROI, mostly off-site, mostly cheap)

### A1. GitHub repo metadata *(P0 — trivial, high impact)*
The repo is the most likely agent landing point and its metadata is weak.
- **Description** (current: `"Scripts to get a eth2 merge ready node setup in seconds "` — dated "merge" framing, trailing space). Proposed:
  `Set up a production Ethereum validator/node (12 clients, MEV, hardening) via one script — with an AI-agent skill, MCP server & JSON CLI.`
- **Topics** (current: **none**). Propose: `ethereum`, `ethereum-node`, `validator`, `staking`, `proof-of-stake`, `geth`, `prysm`, `lighthouse`, `mev-boost`, `node-operator`, `devops`, `ai-agents`, `mcp`, `claude`, `llms-txt`.
- **Homepage URL** (current: empty) → `https://eth2quickstart.com`.
- **Custom social-preview image** (`usesCustomOpenGraphImage: false`) → upload a branded 1280×640 (reuse `frontend/public/og.png` styling).
- **Execution:** GitHub *settings*, not repo files. `gh repo edit chimera-defi/eth2-quickstart --description "…" --homepage "…" --add-topic ethereum …` (topics/description/homepage); social image is a web-UI upload (Settings → General). **Needs repo-admin auth.**
- **Verify:** `gh repo view --json description,repositoryTopics,homepageUrl` reflects the changes.

### A2. Serve `/llms.txt` + `/llms-full.txt` on the website *(P0 — cheap; honest framing)*
Today only in repo root; `eth2quickstart.com/llms.txt` = 404. Agents that land on the site can't find the agent layer.
- **Change:** add `frontend/app/llms.txt/route.ts` (a Next route handler returning `text/plain`) **generated from the repo-root `llms.txt`** — do **not** hand-copy into `frontend/public/` (that forks maintenance). Same for `llms-full.txt`.
- **Anti-drift:** the route reads the canonical repo-root file at build time (or a small `frontend/scripts/sync-llms.mjs` copies it into `public/` as a prebuild step with a CI check that they match). Pick one; document it so the two never diverge.
- **Also:** the website copy should add a top line pointing back to `https://eth2quickstart.com` and the repo, so the bridge works both directions.
- **Verify:** `curl -sI https://eth2quickstart.com/llms.txt` → `200 text/plain`; content byte-matches repo root (modulo the added site header); add to `sitemap.ts`.
- **Honesty note:** frame in the plan/PR as forward-looking hygiene, **not** a ranking/citation lever.

### A3. `SoftwareApplication` JSON-LD on the homepage *(P0 — cheap, defensible)*
The single most credible structured-data win — this *is* a software tool.
- **Change:** new `frontend/components/ui/SoftwareAppJsonLd.tsx`, rendered in `app/page.tsx`. Fields: `@type: SoftwareApplication`, `applicationCategory: DeveloperApplication`, `operatingSystem: Linux (Ubuntu 20.04+)`, `name`, `description`, `url`, `sameAs: [github]`, `offers: {price:0}` (free/open-source), `softwareRequirements` (disk/RAM/CPU from `PREREQUISITES`), `featureList` (clients/MEV/hardening).
- **Verify:** view-source shows one `application/ld+json`; passes validator.schema.org and Google Rich Results Test with no errors.

### A4. Public registry / directory listings *(P1 — propose-only; the most *direct* "agent finds an invokable tool" path)*
Plausibly higher real ROI than llms.txt because these are where agents look for tools.
- **MCP registries:** submit the eth2qs MCP server to the emerging registries (Anthropic's MCP registry, `mcp.so`, PulseMCP, Smithery). Needs a short server manifest + README section.
- **Skill directory:** publish the skill to ClawHub (already referenced as the intended path) and any Claude skill/plugin marketplace the `.claude-plugin/` files target.
- **Verify:** the listing resolves and `install`/`add` instructions work from a clean environment.
- **Ownership:** needs external accounts → **decision A** below (who executes).

### A5. Backlinks from authority lists *(P1 — propose-only)*
- Open PRs adding eth2-quickstart to `awesome-ethereum`, `awesome-staking`, and similar curated lists; check whether ethereum.org's "run a node / staking" resources can link it. These are read by both humans and the crawlers that feed answer-engines.
- **Verify:** merged link present on the list's rendered page.

### A6. Website structured-data + sitemap hygiene *(P1)*
- Add `WebSite` + `Organization` JSON-LD in `layout.tsx` (`Organization.sameAs: [github]`; `WebSite.potentialAction` SearchAction only if a real search exists — otherwise omit, don't fake it).
- Add `/llms.txt`, `/agents` (see B2) to `sitemap.ts`.
- **Verify:** validator.schema.org clean; sitemap lists the new routes.

---

## TRACK B — CHOOSE (make the agent pick us once found)

### B1. Prompt-aligned FAQ with `FAQPage` JSON-LD *(P1 — medium; frame as LLM extraction)*
Answer-engines extract Q&A blocks. Add a visible FAQ (homepage or `/quickstart`) whose questions mirror real agent/user prompts, each with a tight, quotable answer:
- "How do I set up an Ethereum validator?" / "…a node?" / "…an RPC endpoint?"
- "Which Ethereum client should I choose?" (points to the bake-off) 
- "How much disk / RAM / CPU does an Ethereum node need?"
- "Is it safe? How are keys/secrets handled?"
- "Can an AI agent set this up for me?" → yes, via the skill/MCP (bridges to B2).
- **Schema:** `FAQPage` JSON-LD mirroring the visible Q&A.
- **Verify:** validator.schema.org clean; each answer is self-contained and quotable in isolation.
- **Honesty note:** value is AI answer-extraction, **not** Google FAQ rich snippets.

### B2. A "For AI Agents" page on the website — `/agents` *(P1 — the most on-thesis new artifact)*
Mirror the repo agent layer so an agent that lands on the site discovers how to drive the tool without spelunking GitHub:
- Copy-paste **MCP add** command (`claude mcp add …`, `codex mcp add …`).
- **Skill install** (ClawHub + GitHub-path fallback).
- The **wrapper JSON** commands (`doctor --json`, `plan --json`, `phase2 --execution=…`).
- Link to `llms.txt`, `SKILL.md`, `docs/VALIDATOR_MANAGEMENT.md`, the safety contract.
- One-paragraph **safety contract** (no key-gen, no secret removal, human-confirm for root/reboot/destructive).
- **Verify:** page renders, links resolve 200, commands copy correctly; add to nav/footer + sitemap.
- Add `SoftwareApplication`/`HowTo` `potentialAction` or at least prominent internal links so crawlers associate the agent layer with the product.

### B3. Homepage above-the-fold quick-answer + question-shaped headings *(P1 — content)*
- Add a one- to two-sentence quick-answer block near the top ("eth2-quickstart turns a fresh Ubuntu server into a hardened Ethereum validator/RPC node in ~30 min, across 12 clients, with one script — drivable by humans or AI agents").
- Reword some section H2s into question form where natural (helps extraction).
- **Verify:** quick-answer appears in initial HTML (SSR), not client-only.

### B4. Credibility signals *(P2)*
- Surface the bake-off (empirical, measured client comparison) prominently from the homepage as an authority/credibility asset — it's exactly the differentiated, citation-worthy content GEO rewards.
- Footer → Blog link (currently missing), homepage blog teaser (noted in prior session memory as remaining polish).

---

## TRACK C — DRIVE (already strong — gaps only)

### C1. Bridge repo → website *(P0 — cheap)*
- `llms.txt` / `llms-full.txt` never mention `eth2quickstart.com`. Add the site as a human-facing entrypoint line. (README already links the site — good.)
- **Verify:** grep shows the URL present.

### C2. MCP hosting model *(decision — see below)*
- The MCP server is **stdio + requires a repo clone**. That's correct for an operator on the node, but a *remote/hosted* MCP would let an agent connect with zero clone — bigger lift, bigger discovery win. Flagged as **decision C**, not assumed.

### C3. Non-interactive completeness spot-check *(P2)*
- Confirm every operator path an agent would drive has a documented non-interactive form (bootstrap/phase2/mev already do). Audit `configure`/`select_clients` for a headless path; document any that still require a TTY.
- **Verify:** each command runs to completion in the Docker test env with no TTY.

---

## Phasing (impact × effort)

**P0 — quick wins (cheap, high-impact, low-risk, mostly reversible via one PR):**
A1 (repo metadata), A2 (serve `/llms.txt`), A3 (`SoftwareApplication` JSON-LD), C1 (repo→site bridge).

**P1 — the substantive discovery build:**
A4 (registries), A5 (backlinks), A6 (site schema), B1 (FAQ+schema), B2 (`/agents` page), B3 (homepage content).

**P2 — polish & durability:**
B4 (credibility/blog nav), C3 (headless audit), llms.txt anti-drift mechanism hardening, RSS (previously deferred).

---

## Honesty caveats (this repo's review culture punishes overclaims)

1. **llms.txt ≠ citations.** Low adoption, crawlers rarely fetch it. Ship it as no-downside hygiene, not a growth lever.
2. **FAQPage/HowTo ≠ Google rich snippets** in 2026 (curtailed/deprecated). Value = LLM answer extraction.
3. **SoftwareApplication** is the defensible schema win — lead with it.
4. **GEO impact is hard to measure and geo-personalized.** Propose a lightweight before/after check (query ChatGPT/Perplexity/Claude-with-web for "set up an ethereum validator" and log whether we're cited), not a promised ranking gain.

---

## Decisions needed before implementation (the genuine forks)

- **Decision A — implement vs hand-off + off-site ownership.** After approval, should this session implement the P0 quick wins now (single reviewable PR, no auto-merge), or purely hand off a task list? And the off-site items (A1 `gh repo edit`, A4 registries, A5 backlinks) need repo-admin/external auth — do you run those, or authorize me to?
- **Decision B — dedicated `/agents` page (B2)?** Recommended yes (clean, linkable, on-thesis) vs. fold agent info into the existing `/quickstart` page.
- **Decision C — MCP hosting.** Keep stdio-only (clone required) vs. also scope a hosted/remote MCP so agents connect with no clone.

## Coordination / non-conflict notes
- Open PRs #213/#215/#216 are all **bakeoff/harness/docs** — **no overlap** with this frontend/discovery work. Clear lane.
- The earlier blog + clobbered-commits investigations already landed (#209 merged; git history confirmed intact).
- This plan file is written to `docs/GEO_AEO_DISCOVERABILITY_PLAN.md`, **uncommitted**, pending approval. Nothing pushed.
