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

2. **Secondary**: keep future registry packaging separate from the repo skill
   - Avoid registry-specific metadata in the repo skill unless a follow-up PR explicitly needs it
   - If registry packaging is revisited later, keep it separate from the repo-owned skill content

## Non-Recommendation

Do not make `npx install eth2quickstart-skill` the primary path.

Why:
- this repo is shell-first, not npm-first
- the skill content is mostly markdown, references, and wrappers, not a Node runtime tool
- npm-based install adds another packaging surface that is not needed for the actual workflow

If a CLI installer is desired later, prefer a small shell/bootstrap path or a registry-native skill installer over `npx`.

## Example Inputs Reviewed

This plan was shaped against four concrete patterns:

- **OpenClaw/OpenClaw docs**: skills live as folders with `SKILL.md` under the agent workspace and are loaded via progressive disclosure.
- **SKILL.md support guidance**: keep metadata small, push detail into references, and let scripts/references carry the heavy context.
- **General skill-library pattern**: public skill catalogs often use a flat `skills/<name>/` layout and a separate installer/registry layer.
- **Current registry risk**: public skill registries are an active supply-chain target, especially for crypto/blockchain-adjacent skills, so provenance and no-remote-installer rules need to be first-class.

What I did not find useful as a model:

- public "blockchain" or "solidity" agent skills tend to be generic domain-expert prompts, not operational skills wired to a real repo command surface
- many are prose-heavy and would drift quickly from this repo's actual scripts and supported workflows

So the right pattern here is not "web3 knowledge skill". It is a thin repo-operator skill with strict command mapping and safety checks.

## Security Requirements

The skill must:
- avoid any instruction that pulls and executes remote code inline
- prefer repo-local scripts and checked-in references
- state clearly that installing a skill is equivalent to trusting local executable instructions
- require human confirmation before destructive or host-wide operations

The first public registry version should not ship until we have:
- explicit publisher provenance
- a human-readable review checklist
- local validation that the skill never instructs the agent to fetch external bootstrap code outside the repo's canonical install paths

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
└── references/
    ├── workflow.md
    ├── commands.md
    ├── safety.md
    ├── operator.md
    ├── outputs.md
    ├── examples.md
    ├── mcp.md
    ├── improvement.md
    └── sizing.md
```

## Phase Plan

### Phase 0: Build Spec and Test Harness

- Create the skill directory contract before writing the skill:
  - `skills/eth2-quickstart/SKILL.md`
  - `skills/eth2-quickstart/references/*.md`
- Add a lightweight repo test that verifies:
  - required skill files exist
  - `SKILL.md` frontmatter is valid
  - linked reference files exist
  - command examples in the skill resolve to real repo entrypoints
  - the skill does not contain forbidden remote bootstrap patterns such as `curl ... | bash`

### Phase 0.5: First Implementation Contract

The first implementation PR should create exactly these files:

```text
skills/eth2-quickstart/
├── SKILL.md
└── references/
    ├── workflow.md
    ├── commands.md
    ├── safety.md
    ├── operator.md
    ├── outputs.md
    ├── examples.md
    ├── mcp.md
    ├── improvement.md
    └── sizing.md
```

File responsibilities:
- `SKILL.md`: trigger metadata, intent routing, when to load each reference
- `references/workflow.md`: install vs operate vs diagnose vs clean decision tree
- `references/commands.md`: canonical mapping to `scripts/eth2qs.sh`, `install.sh`, `run_1.sh`, `run_2.sh`, and utility scripts
- `references/safety.md`: destructive boundaries, secrets policy, reboot/root boundaries
- `references/outputs.md`: expected command outputs, JSON paths, and service checks an agent can rely on

The first implementation PR should not add:
- a separate Node CLI
- remote-install helpers
- duplicated copies of repo docs under `skills/`
- client-specific deep reference files unless the generic command mapping proves insufficient

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

- Keep registry packaging out of the repo skill by default
- If a registry flow is needed later, build it in a separate PR after the local skill stays green

## TDD Shape

This should be built test-first, not prose-first.

Implementation order:
1. Add the skill-structure validation test and make it fail.
2. Add the minimal skill skeleton and make the test pass.
3. Add reference files and command-mapping checks.
4. Add negative checks for unsafe installer patterns.
5. Revisit registry packaging only in a separate PR if needed.

Acceptance tests for the implementation PR:
- skill structure test passes locally and in CI
- docs consistency still passes
- command examples in the skill resolve to current repo commands
- no remote installer pattern is introduced into skill content
- `scripts/eth2qs.sh` remains the canonical command surface for the skill

Suggested first red/green test split:
1. `test/ci_test_skill_structure.sh`
   - fail if any required skill file is missing
   - fail if `SKILL.md` lacks required frontmatter keys
   - fail if referenced files do not exist
2. `test/ci_test_skill_command_mapping.sh`
   - fail if documented commands do not point at real repo entrypoints
   - fail if the skill routes install/diagnose/cleanup to non-canonical scripts
3. `test/ci_test_skill_safety.sh`
   - fail on forbidden inline remote bootstrap patterns
   - fail if cleanup guidance contradicts the repo's "preserve secrets" policy

This is enough to one-shot a first buildout. It is not enough to one-shot a polished public-registry release, which should remain a second PR after the local skill exists and passes tests.

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
- The first implementation PR can be built from this plan without reopening architecture questions
