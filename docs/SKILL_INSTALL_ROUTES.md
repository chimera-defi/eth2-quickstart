# Skill Installation Routes

This document describes all supported ways to install and use the eth2-quickstart skill for agent-driven Ethereum node deployment.

## Current Installation Methods

### 1. Codex GitHub-Path Installer (Ready Now)

**For agents in Codex environments with skill-installer available.**

```bash
python ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo chimera-defi/eth2-quickstart \
  --path skills/eth2-quickstart
```

**How it works:**
- The skill-installer downloads the skill from GitHub directly
- It extracts `skills/eth2-quickstart/` from the repo
- Users must have an `eth2-quickstart` repo checkout to use the skill
- Once installed, the skill resolves the repo root and invokes canonical commands

**Test coverage:** `test/ci_test_skill_install_e2e.sh` — Test 1 (Codex GitHub-path)
- Resolver finds repo from skill directory ✅
- Resolver finds repo from repo root ✅
- Wrapper commands work from repo ✅
- doctor --json output is valid ✅

---

### 2. Direct Git Clone (Ready Now)

**For workspace-style agents or manual setups.**

```bash
git clone --depth 1 https://github.com/chimera-defi/eth2-quickstart.git
cd eth2-quickstart
# skill is at ./skills/eth2-quickstart/
```

**How it works:**
- User clones the repo (minimal depth to save bandwidth)
- Navigate into the repo
- The skill is available at `./skills/eth2-quickstart/` with no extra install
- Use `./scripts/eth2qs.sh` wrapper or invoke skill references directly

**When to use:** Agents that can execute `git clone`, workspace-aware workflows

**Test coverage:** `test/ci_test_skill_install_e2e.sh` — All tests use this structure
- Repository structure is fully validated ✅
- Resolver paths tested from multiple contexts ✅
- Wrapper commands tested ✅

---

### 3. ClawHub Registry (Ready When Published)

**For agents in OpenClaw/Claude environments using `npx clawhub`.**

```bash
# Option A: clawhub CLI
clawhub install eth2-quickstart

# Option B: npx
npx clawhub install eth2-quickstart
```

**Status:** Not yet published to ClawHub registry
- **Code is ready:** SKILL.md has required metadata, resolver is portable
- **Tests pass:** Distribution contract validated, resolver tested
- **Next step:** Publish to ClawHub and run smoke test with real `npx clawhub install`

**How it works:**
1. User runs `npx clawhub install eth2-quickstart`
2. ClawHub downloads and installs the skill package
3. User clones/checks out the eth2-quickstart repo locally
4. The skill resolves the repo root and invokes canonical commands
5. All commands (`./scripts/eth2qs.sh doctor --json`, etc.) work as documented

**Test coverage:** `test/ci_test_skill_install_e2e.sh` — Test 2 (clawhub contract)
- OpenClaw metadata present in SKILL.md ✅
- Resolver is executable ✅
- Resolver finds repo from skill directory ✅
- Resolver finds correct repo root ✅
- Workflow docs mention clawhub install ✅
- All reference docs present (safety, commands, operator, examples) ✅

---

## Resolver Mechanism

All installation routes rely on `skills/eth2-quickstart/scripts/resolve_repo_root.sh` to locate the eth2-quickstart repository from an installed skill context.

**Resolver algorithm:**
1. Try git root (`git rev-parse --show-toplevel`)
2. Try 3 levels up from script directory (works when skill is inside repo)
3. Try PWD and walk up parent directories
4. Fail with helpful error message

**Design rationale:**
- **Git context first:** supports most development environments
- **Relative path:** supports skill copied into repo
- **PWD walk:** supports running from anywhere inside repo
- **Clear failure:** user knows to run from/near repo root

---

## Installation Path Contracts

| Path | User Action | Skill Context | Commands Work | Test Status |
|------|-----------|---|---|---|
| **Codex GitHub-path** | `python ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py --repo chimera-defi/eth2-quickstart --path skills/eth2-quickstart` | Extracted into Codex skills directory, repo nearby | ✅ `./scripts/eth2qs.sh`, `doctor --json` | ✅ Passing |
| **Git clone** | `git clone https://github.com/chimera-defi/eth2-quickstart.git && cd eth2-quickstart` | Skill inside repo at `./skills/eth2-quickstart/` | ✅ Direct use | ✅ Passing |
| **npx clawhub** | `npx clawhub install eth2-quickstart` | Installed to `~/.claude/skills/eth2-quickstart/`, repo checked out locally | ✅ Resolver finds repo, all commands work | ⏳ Ready, awaiting ClawHub publish |

---

## E2E Test Coverage

**File:** `test/ci_test_skill_install_e2e.sh`

This test validates both installation routes work correctly by simulating real-world environments and verifying:

### Test 1: Codex GitHub-Path (4 assertions)
- ✅ Resolver works from installed skill directory
- ✅ Resolver works from repo root
- ✅ Wrapper help command accessible
- ✅ doctor --json produces valid JSON

### Test 2: npx clawhub (5 assertions)
- ✅ SKILL.md has OpenClaw metadata
- ✅ Resolver script is executable
- ✅ Resolver finds repo from skill directory
- ✅ Workflow docs reference clawhub install
- ✅ All reference docs present

### Test 3: Cross-Installation Consistency (2 assertions)
- ✅ Both paths produce valid JSON from doctor
- ✅ Both paths have identical wrapper help

**Total: 11 tests, all passing**

---

## Integration in CI/CD

The e2e test runs in two places:

1. **Pre-commit hook** (`scripts/pre-commit.sh`)
   - Run locally before pushing
   - Validates resolver and installation contract
   - Takes ~5 seconds

2. **GitHub Actions** (`.github/workflows/ci.yml`)
   - Runs on every commit to master and PRs
   - `agent-skill` job validates all skill tests
   - Prevents regressions in installation paths

---

## Deployment Readiness Checklist

### ✅ Code Ready for ClawHub Publish
- [x] SKILL.md has required metadata (`metadata.openclaw.skillKey: eth2-quickstart`)
- [x] Resolver portable and tested
- [x] All reference docs present (operator, commands, safety, sizing, examples, improvement)
- [x] Distribution contract documented and tested
- [x] No remote bootstrap code (uses canonical repo scripts only)

### ⏳ Next Steps to Go Live via npx clawhub
- [ ] Publish skill package to ClawHub registry
- [ ] Run smoke test: `npx clawhub install eth2-quickstart`
- [ ] Verify `./scripts/eth2qs.sh doctor --json` works from checkout
- [ ] Update README to reflect published status

---

## Quick Reference for Agent Users

**I want to use the eth2-quickstart skill:**

1. **If you're in Codex:** Use GitHub-path installer (ready now)
2. **If you have git:** Clone the repo (ready now)
3. **If you prefer registries:** Wait for ClawHub publish, then use `npx clawhub install`

**After installing:**
```bash
# Navigate to repo root
cd eth2-quickstart

# Use the wrapper
./scripts/eth2qs.sh help
./scripts/eth2qs.sh doctor --json
./scripts/eth2qs.sh configure
./scripts/eth2qs.sh phase1
# ... see SKILL.md for full routing
```

---

## References

- **Skill definition:** `skills/eth2-quickstart/SKILL.md`
- **Operator workflows:** `skills/eth2-quickstart/references/operator.md`
- **Safety guardrails:** `skills/eth2-quickstart/references/safety.md`
- **Sizing guidance:** `skills/eth2-quickstart/references/sizing.md`
- **Installation examples:** `skills/eth2-quickstart/references/examples.md`
- **Test script:** `test/ci_test_skill_install_e2e.sh`
