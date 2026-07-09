# Improvement Loop

Use this when the agent needs to improve its future performance in this repo without drifting away from the real command surface.

## Loop

1. Observe with machine-readable outputs first:
   - `./scripts/eth2qs.sh plan --json`
   - `./scripts/eth2qs.sh doctor --json`
   - relevant test output
2. Form the smallest possible fix:
   - prefer wrapper or shared-library reuse
   - avoid adding a second command path for the same job
3. Validate locally:
   - targeted test first
   - then repo entrypoints like `./test/run_tests.sh --unit` or `./scripts/pre-commit.sh`
4. Persist only durable learnings:
   - update `docs/agent-handoff.md`
   - add or tighten tests when behavior changed
   - update the skill references only if the operator contract changed

## Durable learnings observed in this repo

- Validator lifecycle work should expose a read-only inventory command first, then branch into focused exit, standard-creation, or compounding flows. The current surface is `./scripts/eth2qs.sh validators --json`, `validator-exit`, `validator-create-0x01`, `validator-create-0x02`, `validator-withdrawal-changes`, and `validator-manage`.
- New `install/utils` validator helpers should reuse the local inventory path, keep offline command templates useful when client tooling is absent, and document the wrapper commands in both the skill and `docs/SCRIPTS.md`.
- Local end-to-end validation for validator flow changes should include a real execution/consensus pair when available; the validated combo for this branch was Geth + Prysm via `./test/run_e2e.sh --phase=2`.
- BLS-to-execution change workflows should surface withdrawal credential type in the validator inventory, normalize keystore pubkeys before beacon queries, then use the official deposit CLI to generate signed messages and the beacon REST API to submit them.
- Withdrawal-change submission should be manifest-gated: generate into a staging directory, write a manifest, and refuse to post stale JSON that does not match the current selection.
- Consolidation flows should validate source and target pubkeys against the local inventory before any transaction is broadcast, and they should prefer temporary-keystore signing over exposing `--private-key` on the command line.
- For production-key safety, rehearse the withdrawal-change flow with a fixture-backed `--validators-json` file and stubbed deposit/curl commands before touching live keys.
- Withdrawal-change helpers should support `--dry-run`, stage-by-stage preview output, and a live Prysm + geth smoke test in the phase-2 container so agents can validate the exact operator path before production. Prysm inventory discovery should also fall back to the wallet v2 accounts listing, and Prysm voluntary exit should respect an overrideable RPC provider.

## Rules

- Do not treat host-specific observations as universal repo truths.
- Do not add memory files outside the repo's existing durable context pattern.
- Do not update the skill based on a one-off failure unless the failure exposed a real contract gap.
- Prefer improving references and tests over adding more prompt prose.
- If a workflow is chain-specific, expose it explicitly instead of hiding it behind ambiguous guidance.
- Shell helpers that are intended to be reused in tests should guard both the top-level option parser and the `main` invocation with `if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then ... fi`. Without that, sourcing the helper in a regression test can accidentally trigger its CLI parser.
- Destructive validator flows should normalize local selections to concrete pubkeys before confirmation. That catches invalid tokens early and prevents the operator from confirming a prompt for a selection that will later fail to resolve.
