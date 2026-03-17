# Skill Installation Routes & E2E Test Coverage

Quick reference for eth2-quickstart skill installation methods and test validation. For detailed marketing copy, see [AGENT_SKILL_LISTING.md](AGENT_SKILL_LISTING.md).

## Installation Methods

| Route | Status | Use When | Test Coverage |
|-------|--------|----------|----------------|
| **Codex GitHub-path** | ✅ Ready now | Using Codex agent environment | `test/ci_test_skill_install_e2e.sh` Test 1 |
| **Git clone** | ✅ Ready now | Workspace-style or manual setup | `test/ci_test_skill_install_e2e.sh` (all tests) |
| **npx clawhub** | ⏳ Code ready, awaiting publish | When skill is in public ClawHub | `test/ci_test_skill_install_e2e.sh` Test 2 |

**See README.md "For External Agents" section for full installation commands.**

## E2E Test Coverage

**File:** `test/ci_test_skill_install_e2e.sh` (241 lines)

Simulates real-world installation environments and validates:

### Test 1: Codex GitHub-Path (4 assertions)
- ✅ Resolver finds repo from skill directory
- ✅ Resolver finds repo from repo root
- ✅ Wrapper help accessible
- ✅ doctor --json produces valid JSON

### Test 2: npx clawhub Contract (5 assertions)
- ✅ OpenClaw metadata in SKILL.md
- ✅ Resolver script executable and portable
- ✅ Resolver finds repo from skill directory
- ✅ Workflow docs reference clawhub
- ✅ All reference docs present

### Test 3: Cross-Installation Consistency (2 assertions)
- ✅ Both paths produce identical wrapper output
- ✅ Both paths generate valid JSON from doctor

**Total: 11 tests, all passing**

## Resolver Design

The skill locates the repo via `skills/eth2-quickstart/scripts/resolve_repo_root.sh`:

1. **Git root:** `git rev-parse --show-toplevel` (works in any git context)
2. **Relative path:** 3 levels up from script (works when skill inside repo)
3. **PWD walk:** Search up parent directories
4. **Fail gracefully** with helpful error message

This design supports all installation paths without modification.

## CI/CD Integration

- **Pre-commit:** `scripts/pre-commit.sh` runs test locally
- **GitHub Actions:** `.github/workflows/ci.yml` agent-skill job runs on all commits
- **Prevents regressions** in resolver portability and installation contracts

## Deployment Status

### ✅ Code Ready
- SKILL.md has required metadata
- Resolver tested and portable
- All reference docs present
- No external bootstrap code

### ⏳ Next Steps for npx clawhub
1. Publish to ClawHub registry
2. Run smoke test: `npx clawhub install eth2-quickstart`
3. Verify `./scripts/eth2qs.sh doctor --json` works from checkout
4. Update README deployment status

## References

- **Skill definition:** `skills/eth2-quickstart/SKILL.md`
- **Test script:** `test/ci_test_skill_install_e2e.sh`
- **Marketing copy:** `docs/AGENT_SKILL_LISTING.md`
- **Operator workflows:** `skills/eth2-quickstart/references/operator.md`
- **Full install methods:** README.md "For External Agents" section
