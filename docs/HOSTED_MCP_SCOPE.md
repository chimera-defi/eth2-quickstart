# Hosted / Remote MCP — Scoping (follow-up, not built)

**Status:** SCOPE ONLY (2026-07-29). chimera_defi asked to "also scope a hosted/remote MCP." This documents
whether/how to do it and the hard constraints. No implementation here. Companion to
`docs/GEO_AEO_DISCOVERABILITY_PLAN.md` (decision C).

---

## The goal and why it's a discovery win

Today the eth2qs MCP server (`mcp_server/eth2qs_mcp_server.py`, `FastMCP`, `transport="stdio"`) requires the
agent to **clone the repo and run a local process**. A *remote* MCP endpoint (a public URL) would let a user's
agent connect with **zero clone** — the most direct "agent finds and invokes our tool" path, and it shows up in
MCP registries as a hosted server (higher discovery than a stdio-only entry).

## The hard constraint (this is the whole scoping problem)

**This tool installs and operates validator infrastructure — with real ETH at stake — on a *specific* host.**
The privileged, mutating operations inherently must execute **on the user's own server**:

- `ensure_apply`, `repair_apply`, `start` / `stop` / `restart`, `monad_install` — mutate the host, gated by
  `confirm` + a confirmation token.
- `doctor`, `stats`, `logs`, `validators_list`, `debug` — read the *live local node* (systemd units, datadirs,
  beacon API on localhost).

A hosted endpoint at some URL **cannot and must not** reach into arbitrary user hosts to run these. Doing so
would mean SSH/agent footholds into strangers' validator boxes — an unacceptable security and liability posture
for a funds-bearing tool. So a hosted MCP can only safely offer the **host-independent, advisory/read-only
subset**, and must defer all execution to the local surface.

## Recommended architecture — two tiers, not a lift-and-shift

**Tier 1 — Local execution MCP (unchanged, stays primary):** the current stdio server, run on the target host
via `./mcp_server/run_eth2qs_mcp.sh`. This is where install/operate/validator actions actually happen. Correct
as-is. Do not weaken it.

**Tier 2 — Hosted *advisory* MCP (new, optional):** a public Streamable-HTTP endpoint exposing ONLY the
host-independent tools:

| Candidate hosted tool | Source today | Host-independent? |
|-----------------------|-------------|-------------------|
| `help` / `server_info` | static | ✅ |
| `client_options` | `client-options --json` (reads repo config, not host) | ✅ |
| sizing guidance | `skills/eth2-quickstart/references/sizing.md` | ✅ (static) |
| `plan` preview | planner logic | ✅ if made host-agnostic (takes desired stack as args, returns the plan/commands) |
| `validator_op_preview` | returns the exact node CLI command text | ✅ (generates text; never executes) |
| "what command do I run?" | maps a goal → exact `./scripts/eth2qs.sh …` command | ✅ |

Everything that reads a live node or mutates the host returns, instead of executing, a **precise command to run
on the user's host** (or a pointer to add the local Tier-1 MCP). This mirrors the existing funds-safety contract
(`validator_op_preview` already does exactly this).

Net behavior: a user's agent connects to the hosted URL, gets sizing/client/plan advice and the **exact commands**,
then runs them (or spins up the local MCP) on the user's actual server. Discovery win, no remote-execution risk.

## Technical path (small code, real ops lift)

- **Transport:** FastMCP supports Streamable HTTP — roughly `mcp.run(transport="streamable-http", host, port)`
  behind a reverse proxy. A *separate* entrypoint (`eth2qs_mcp_server_http.py`) that registers only the Tier-2
  tools keeps the privileged tools off the public surface entirely (defense in depth — don't just rely on a flag).
- **Hosting:** small always-on container/VM behind TLS (the same CloudFront/edge story as the site, or a tiny
  service). Stateless; no access to any node.
- **Auth / abuse:** likely anonymous read-only + rate limiting (no secrets involved since nothing executes). If
  any tool ever touches per-user state, add auth first.
- **Registry:** list the hosted URL in the MCP registries from the off-site checklist (A4) — hosted servers are
  first-class there.
- **Anti-drift:** Tier-2 must reuse the same underlying functions/data as the CLI (`client-options`, sizing docs)
  so hosted advice never diverges from what the repo actually does.

## Effort / recommendation

- **Code:** small (new HTTP entrypoint, tool subset, host-agnostic `plan`). ~1 focused PR.
- **Ops:** non-trivial and ongoing (a public always-on service to run, monitor, secure, and keep in sync).
- **Recommendation:** worth doing **as advisory-only Tier 2**, sequenced *after* the P0/P1 website + off-site
  work lands and after the local MCP is registry-listed (cheaper discovery first). Treat it as its own
  spec → plan → PR. Do **not** expose any mutating/host-reading tool remotely.

## Open questions for chimera_defi
1. Where would it host (reuse the CloudFront/AWS footprint, or a separate tiny service)?
2. Is anonymous + rate-limited acceptable (recommended, since nothing executes), or do you want auth from day one?
3. Should hosted `plan` accept a desired stack (execution/consensus/mev) as arguments and return commands, i.e.
   fully decoupled from any host? (Recommended — that's what makes it safely remote.)
