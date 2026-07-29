# Off-Site Discoverability Checklist (auth-gated — not code)

These items live outside the repo tree (GitHub settings, external registries, third-party lists) and need
**repo-admin / external-account auth**, so they are NOT part of the website PR. Run them yourself, or
authorize the agent to run the `gh` ones. Companion to `docs/GEO_AEO_DISCOVERABILITY_PLAN.md`.

---

## A1 — GitHub repo metadata — ✅ DONE 2026-07-29 (except the social image)

**Applied and verified** by the agent on 2026-07-29 (authorized by chimera_defi: "do what you can
autonomously"). Read back via `gh repo view --json description,homepageUrl,repositoryTopics`:

- **description** → `Set up a production Ethereum validator/node (13 clients, MEV, hardening) via one script — with an AI-agent skill, MCP server & JSON CLI.` (was the dated *"Scripts to get a eth2 merge ready node setup in seconds "*). Note the count is **13**, matching `TOTAL_CLIENTS`; the old site copy said 12 and was wrong.
- **homepageUrl** → `https://eth2quickstart.com` (was empty)
- **topics** → 15 applied: `ai-agents, claude, devops, ethereum, ethereum-node, geth, lighthouse, llms-txt, mcp, mev-boost, node-operator, proof-of-stake, prysm, staking, validator` (was **none**)

⬜ **STILL TODO — social preview image (human, web UI only).** GitHub exposes **no API** for this, so it
could not be automated. Settings → General → "Social preview" → upload a 1280×640 PNG (reuse
`frontend/public/og.png` styling). Until then link unfurls use GitHub's generic auto-image.

Note: `gh repo edit` fails in some environments with a Projects-classic GraphQL deprecation error — the
REST equivalents used here work: `gh api -X PATCH repos/OWNER/REPO -f description=... -f homepage=...`
and `gh api -X PUT repos/OWNER/REPO/topics -f names[]=...`.

<details><summary>Original state (for rollback)</summary>

description: `Scripts to get a eth2 merge ready node setup in seconds ` · homepage: `null` · topics: none
</details>

---

## A4 — Registry / directory listings (P1 — most direct "agent finds an invokable tool" path)

The MCP server and skill are in **no public registry** today. These are where agents actually look for tools.

### Official MCP registry — researched 2026-07-29, manifest PREPARED

**The key question was whether we're even eligible**, since our MCP server is a Python script inside a git
repo — **not** published to PyPI/npm, and stdio-only (not a remote URL). Verified answer: **yes, eligible.**
The `server.json` spec supports servers with *no* `packages` and *no* `remotes`, using `websiteUrl` for
"servers that follow a custom installation path" — exactly our case. So **PyPI packaging is NOT a
prerequisite**, which is what the earlier draft of this checklist assumed.

✅ **`server.json` created at the repo root** and validated against
`https://static.modelcontextprotocol.io/schemas/2025-09-29/server.schema.json`:
required fields are `name`, `description`, `version`; `name` matches the required reverse-DNS pattern
(`io.github.chimera-defi/eth2-quickstart`); `description` is 92 chars (limit 100); `repository` carries the
required `url` + `source`. No `packages`/`remotes` — deliberate, per the custom-install-path case.

⬜ **Publishing still needs a human** (could not be automated): it requires the `mcp-publisher` CLI (not
installed here) and an **interactive GitHub OAuth** login to prove ownership of the `io.github.chimera-defi`
namespace. Steps:

```bash
# install mcp-publisher (see modelcontextprotocol/registry releases), then:
mcp-publisher login github     # interactive OAuth; proves the io.github.chimera-defi namespace
mcp-publisher publish          # reads ./server.json
```

- **Sequencing note:** `websiteUrl` currently points at `https://eth2quickstart.com` (live today) rather than
  `/agents`, because the `/agents` route ships in **PR #218** and would 404 until that merges. After #218 is
  merged and deployed, consider pointing `websiteUrl` at `https://eth2quickstart.com/agents` — it is the
  purpose-built landing page for exactly this audience.
- **Verify after publishing:** the server resolves in the registry and its listed install path works from a
  clean environment.

### Other directories (each needs its own account / submission)

- [ ] **mcp.so** — community MCP directory listing.
- [ ] **PulseMCP** — MCP server directory.
- [ ] **Smithery** — MCP registry/host (also relevant if we pursue hosted MCP — see `HOSTED_MCP_SCOPE.md`).
- [ ] **ClawHub** — publish the skill (already the intended packaging path per `llms.txt` / SKILL.md).
      Note: no `clawhub` CLI is installed in the agent environment, so this needs a human or a published CLI.
- [ ] Any Claude plugin marketplace the `.claude-plugin/{marketplace.json,plugin.json}` target.
- **Verify (each):** the listing resolves and its `install`/`add` instructions work from a clean environment.
- **Note:** listing requirements change; confirm each registry's current submission format before filing.

---

## A5 — Backlinks from authority lists (P1, propose-only)

Read by humans and by the crawlers that feed answer-engines; also raise traditional SEO authority.

- [ ] `awesome-ethereum` — PR adding eth2-quickstart under node/staking tooling.
- [ ] `awesome-staking` (and similar curated staking lists) — PR.
- [ ] Check whether ethereum.org "run a node" / "staking" resource pages accept a link or PR.
- **Verify (each):** merged link is present on the list's rendered page.

---

## Lightweight GEO measurement (before/after, since GEO impact is hard to prove and geo-personalized)

Not a promised ranking gain — just a sanity check. Before and ~2–4 weeks after shipping:

- [ ] Ask ChatGPT (with web/SearchGPT), Perplexity, and Claude-with-web: *"How do I set up an Ethereum validator
      on a Linux server?"* and *"What's a good script/tool to set up an Ethereum node?"* — log whether
      eth2-quickstart / eth2quickstart.com is mentioned or cited, and in what position.
- [ ] Re-check from at least one non-US IP (AI answers are geo-personalized).
