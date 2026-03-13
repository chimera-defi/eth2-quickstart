# Agent Skill Plan

Last updated: 2026-03-13

## Goal

Provide an installable agent skill that can use this repo to bootstrap, operate, diagnose, and clean up Ethereum node stacks with clear safety guardrails.

## Recommendation

Build this in two layers:

1. **Primary**: a repo-owned Codex skill bundle
   - Add `skills/eth2-quickstart/SKILL.md`
   - Add concise references for workflows, safety, and command mapping
   - Reuse existing repo entrypoints such as `scripts/eth2qs.sh`, `install.sh`, `run_1.sh`, `run_2.sh`, `install/utils/doctor.sh`, and `install/utils/purge_ethereum_data.sh`

2. **Secondary**: publishable metadata/package for external agent registries
   - Add `agents/openai.yaml` for UI-facing skill metadata
   - Optionally package the same skill for ClawHub or another skill registry after the local skill is stable

## Non-Recommendation

Do not make `npx install eth2quickstart-skill` the primary path.

Why:
- this repo is shell-first, not npm-first
- the skill content is mostly markdown, references, and wrappers, not a Node runtime tool
- npm-based install adds another packaging surface that is not needed for the actual workflow

If a CLI installer is desired later, prefer a small shell/bootstrap path or a registry-native skill installer over `npx`.

## Scope for V1

The first skill should cover:
- selecting the right entrypoint for install vs operations vs diagnostics
- safe defaults for non-interactive bootstrap
- explicit warnings around root-required steps, reboot boundary, and secret-preserving cleanup
- canonical service names and health checks
- machine-readable output path via `doctor --json`

The first skill should not:
- generate validator keys
- manage secrets outside the repo's existing documented flows
- promise fully autonomous production deployment without a human confirming host/domain/fee-recipient inputs

## Proposed Skill Shape

```text
skills/eth2-quickstart/
├── SKILL.md
├── agents/openai.yaml
└── references/
    ├── workflow.md
    ├── commands.md
    ├── safety.md
    └── clients.md
```

## Phase Plan

### Phase 1: Local skill for Codex

- Create `skills/eth2-quickstart/SKILL.md`
- Map user intents to existing commands:
  - install/bootstrap
  - configure
  - phase1 / phase2
  - doctor / status
  - logs
  - clean-data
  - update-all
- Keep the skill thin and point to repo references instead of duplicating docs

### Phase 2: Agent ergonomics hardening

- Add a dry-run oriented workflow where possible
- Standardize which commands the skill should prefer for humans vs agents
- Document expected outputs, especially JSON output and systemd checks
- Decide whether more agent-safe wrappers are needed beyond `scripts/eth2qs.sh`

### Phase 3: Registry packaging

- Add `agents/openai.yaml`
- Validate the skill can be installed through a registry flow such as ClawHub
- Only after that, decide whether a separate installer/distribution wrapper is still useful

## Open Questions

- Should the skill target only local repo usage, or also remote host orchestration over SSH?
- Should the skill expose client-selection logic directly, or always route through existing configure/bootstrap flows?
- Do we want a dedicated agent-safe wrapper command set beyond `scripts/eth2qs.sh` before publishing the skill externally?
- If we publish to ClawHub, what is the desired update story: pin to git tag, branch, or release artifact?

## Success Criteria

- An agent can discover the skill and choose the correct workflow with minimal repo-specific prompting
- The skill reuses canonical repo commands instead of re-describing logic in prose
- Safety boundaries are explicit: root steps, reboot boundary, secret preservation, and destructive cleanup
- The published skill path does not introduce a second competing UX that drifts from the repo
