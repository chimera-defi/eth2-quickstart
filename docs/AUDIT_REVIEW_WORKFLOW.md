# Audit & Review Workflow

A repeatable, delegation-driven process for auditing this repository for security, correctness, dead code, incomplete work, and broken client installs. This handles **real validator funds**, so the workflow biases toward verified findings over speed.

## Goals

Each pass answers five questions:

1. Is there dead code or non-working code?
2. Are there files no longer required?
3. Is there incomplete / half-finished work?
4. Are there security vulnerabilities or bug-prone areas?
5. Do any clients fail to install / run end-to-end?

## Delegation model

Discovery is gated by a token-reduce hook. **Always start a discovery round with `token-reduce-adaptive <topic words>`** before broad scans — never raw repo-wide `find` / `grep`.

| Role | Tool | Used for |
|------|------|----------|
| Bounded read-only audit | `kd` (kimi-delegate) | Per-client / per-helper static audits, dead-code call-graphs. Cheap, parallel. |
| Cross-file / sandboxed work | `devin-delegate --task ... --workspace <repo>` | Multi-file dead-code tracing, debugging failing installs, multi-file fixes. |
| Write-mode fixes | `codex` / `spark` | Implementing fixes spanning files (writes to disk; only summary returns to orchestrator). |
| Advisor / second opinion | `gstack-claude` (review / challenge) | Independent cross-check of each findings batch + final diff. |
| Built-in review gates | `/security-review`, `/code-review` | Run on the resulting diff before opening a PR. |
| Root-cause | `/investigate` | Any failing client install during E2E. |

**Advisor pattern (required):** every findings batch produced by one model is challenged by a *different* model before any fix is applied (e.g. kimi finds → gstack-claude or codex challenges). This prevents hallucinated "dead code" deletions and false-positive vulnerability reports. The orchestrator holds only synthesis; delegates write artifacts to disk to protect context.

Preflight before delegating: `devin-delegate --check`, `kd --check`.

## Phases

### Phase 0 — Scaffold & baseline
- Fresh branch off current HEAD (`chore/security-quality-audit-<date>`).
- Working dir `artifacts/audit/` (gitignored) for raw delegate output; committed report at `docs/audit/FINDINGS-<date>.md`.
- Capture teardown baseline (`docker images`, `docker ps -a`, `docker system df`, `df -h /`) to `artifacts/audit/baseline.txt` so cleanup can be verified later.

### Phase 1 — Client setup verification (static)
Scope: `install/execution/*.sh`, `install/consensus/*.sh`, `install/mev/*.sh`, `configs/*`, client vars in `exports.sh`.
Per-client checks: required script structure (sources `exports.sh` + `lib/common_functions.sh`, `get_script_directories`, correct `require_root`); all function calls resolve; no duplicated common functions; download URLs valid (cross-check `test/validate_downloads.sh` + live GitHub asset check); config-template merge correctness (`merge_client_config`); MEV builder endpoints disabled-by-default; ports match `exports.sh`; dead code / unused vars / stray TODOs.
Delegate: `kd` batched A=execution, B=consensus, C=MEV → findings to disk. Advisor cross-check.

### Phase 2 — Helper scripts verification (static)
Scope: `lib/common_functions.sh`, `install/utils/*`, `install/security/*`, `install/web/*`, `scripts/*`, `./scripts/eth2qs.sh`, `mcp_server/*`.
Checks: unused/dead functions (call-graph across repo); orphaned files no longer referenced; incomplete work (TODO/FIXME/stubs/half-wired features); duplication to consolidate into `common_functions.sh`; security (secret handling, `600`/`700` perms, local binding, sudo usage, command injection, `eval` / unquoted expansions).
Delegate: `kd` read-only audits + dead-code call-graph; `devin-delegate` for cross-file tracing. Advisor cross-check.

### Phase 3 — Dynamic E2E verification
Static gates first (fast, local):
- `./scripts/pre-commit.sh`
- `bash -n` sweep + full shellcheck sweep (project exclusions)
- Validators: `test/validate_downloads.sh`, `validate_proxy_policy_sync.sh`, `validate_proxy_policy_toggles.sh`, `validate_caddy_config.sh`, `validate_nginx_config.sh`, `validate_review_guardrails.sh`
- Unit: `install/test/test_common_functions.sh`, MCP python tests

Then Docker E2E:
- Phase 1: `./test/run_e2e.sh --phase=1` (run_1 hardening, root context).
- Phase 2: choose combos so **every client is exercised at least once**, e.g. `E2E_EXECUTION=<x> E2E_CONSENSUS=<y> E2E_MEV=<z> ./test/run_e2e.sh --phase=2`. Use `SKIP_BUILD=true` after the first build.
- Any failure → `/investigate` root cause; record per-combo pass/fail; feed breakage into the fix queue.

### Phase 4 — Fix execution
Triage findings: **P0** security · **P1** broken client/bug · **P2** dead code/unused files · **P3** refactor. Delegate fixes per batch (`codex` / `spark` / `devin-delegate`); review each diff; re-run relevant validators/E2E after each batch (regression). Then `/security-review` + `/code-review` on the full diff; advisor final pass via `gstack-claude` challenge.

### Phase 5 — Document, commit, PR
Finalize `docs/audit/FINDINGS-<date>.md` (findings + resolutions + residual risk); update `docs/agent-handoff.md`; conventional commits per logical fix group; push branch; open PR.

### Phase 5.5 — Convergence loop (iterate until clean)

Client breakages **cascade** (fixing a download URL unmasks a runtime/version bug, which unmasks the next). So fixes are not one-shot — iterate until a clean pass:

1. Rebuild the image (**required** — the Dockerfile bakes repo code via `COPY`, so `SKIP_BUILD=true` tests stale code).
2. Run the canonical per-client-once matrix (`artifacts/audit/iterate_matrix.sh`).
3. Triage failures into: **fixable** (fix now), **flaky** (retry; e.g. nginx cache-hit), **exclusion set** (upstream/maintainer decisions — don't block convergence).
4. If any fixable failures → fix, go to 1.
5. **Converged** when a full matrix run has no new fixable failures (only exclusion-set/flaky remain) and no new static findings → finalize.

Guardrails: keep an explicit **exclusion set** + **iteration cap** (~6) in `artifacts/audit/loop-state.md` so the loop terminates instead of chasing upstream-only breakage forever. Tear down containers each iteration and prune dangling images between builds (disk).

### Phase 6 — Teardown (mandatory)
Stop/remove `e2e-phase*` containers; remove the `eth-node-test` image; prune dangling build layers (`docker image prune` / `builder prune`). **Do not remove unrelated images.** Verify `docker ps -a` / `docker images` / `df -h /` against `artifacts/audit/baseline.txt` and report reclaimed space.

## Anti-patterns to avoid

- Running raw `find` / `grep` sweeps instead of `token-reduce-adaptive` (blocked by hook).
- Acting on a single delegate's findings without an advisor cross-check.
- Inlining large file reads/writes into the orchestrator (delegate to disk instead).
- Deleting "dead" code without confirming no dynamic / string-built references.
- Combining run_1 / run_2 phases or skipping the reboot (breaks the two-phase security model).
- Removing unrelated Docker images during teardown.
