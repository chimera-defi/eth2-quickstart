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

## Rules

- Do not treat host-specific observations as universal repo truths.
- Do not add memory files outside the repo's existing durable context pattern.
- Do not update the skill based on a one-off failure unless the failure exposed a real contract gap.
- Prefer improving references and tests over adding more prompt prose.
- If a workflow is chain-specific, expose it explicitly instead of hiding it behind ambiguous guidance.
