# Help System Rearchitecture - Plan & Specification

## 1. Current State

### What Exists Today
- **help.sh** – Reads scripts.manifest; outputs human or Markdown (--markdown)
- **scripts.manifest** – ` :: ` delimiter; 6 fields per line
- **test/validate_help.sh** – Validates manifest and help output; wired into run_tests.sh
- **--help** on run_1.sh, run_2.sh, install.sh – Point to `./help.sh`

### Resolved (as of rearch)
1. ~~Manifest parsing bug~~ – Fixed with ` :: ` delimiter
2. ~~No regression tests~~ – validate_help.sh added
3. ~~Format fragility~~ – ` :: ` supports pipe in usage

### Script Inventory & Value Prioritization

**High value** (post-install, debug, fix – feature prominently):
- doctor.sh, stats.sh, view_logs.sh, refresh.sh, start.sh, update.sh, update_all.sh, update_git.sh, verify_client_configs.sh, purge_ethereum_data.sh

**Lower value** (one-time, optional): run_1/2, install.sh, configure.sh, select_clients.sh, run_manifest.sh, optional_tools, install_dependencies, SSL/web, MEV, security scripts

**Quick Reference set**: doctor, stats, view_logs, refresh, start, update/update_all

**System commands**: `sudo systemctl status/restart eth1 cl validator mev`, `sudo journalctl -fu eth1`

---

## 2. Task List

### Task 1: Fix Manifest Format (Phase 1a) ✅
- [x] 1.1 Convert scripts.manifest to ` :: ` delimiter
- [x] 1.2 Update help.sh parser to use `awk -F' :: '`
- [x] 1.3 Verify all lines parse correctly

### Task 2: Create validate_help.sh (Phase 1b) ✅
- [x] 2.1 Create test/validate_help.sh
- [x] 2.2 Assert: manifest parses, all paths exist, help.sh exits 0
- [x] 2.3 Assert: output contains TWO-PHASE, run_1.sh, doctor, post-install
- [x] 2.4 Assert: Markdown has ## Two-Phase and post-install
- [x] 2.5 Wire into test/run_tests.sh

### Task 3: Complete Manifest Inventory (Phase 2) ✅
- [x] 3.1 Manifest has all user-facing scripts
- [x] 3.2 Manifest header documents format

### Task 4: Enhance Help Output (Phase 3) ✅
- [x] 4.1 Add "Post-install: keep your node healthy" section
- [x] 4.2 System commands table in Markdown
- [x] 4.3 Best practices section present
- [x] 4.4 Markdown structure for agents

### Task 5: Multi-Pass Review & Cleanup ✅
- [x] 5.1 Pass 1: Functionality
- [x] 5.2 Pass 2: Architecture (manifest source of truth; post-install highlighted)
- [x] 5.3 Pass 3: Cleanup

---

## 3. Manifest Format Specification

**Format**: `path :: category :: description :: usage :: flags :: requires`

**Delimiter**: ` :: ` (space-colon-colon-space) – avoids pipe in usage, unambiguous

**Categories**: core, maintenance, diagnostics, configuration, optional, ssl_web, mev, security, examples

**Requires**: root, non_root, or empty

**Example**:
```
run_1.sh :: core :: Phase 1: System hardening. Run as root, then reboot. :: sudo ./run_1.sh ::  :: root
install/utils/doctor.sh :: diagnostics :: Health check: system, services, config, ports. :: ./install/utils/doctor.sh ::  :: 
```

---

## 4. Best Practices

### For Spec Maintainers
- Keep task list granular; each task completable in one session
- Update "Current State" when tasks complete
- Document decisions in Open Questions when resolved

### For Implementers
- Run `./help.sh` and `./help.sh --markdown` after any manifest/help change
- Run `./test/validate_help.sh` before commit
- Add new scripts to manifest with format: `path :: category :: description :: usage :: flags :: requires`
- Post-install tools (doctor, stats, view_logs, refresh, start, update) must be easy to find

### For Agents
- Use `./help.sh --markdown` for structured output; Markdown parses well
- Quick Reference set is the primary debugging/maintenance flow
- Manifest path is `scripts.manifest` at project root

---

## 5. Handoff Document

### Agent Handoff Checklist
When handing off to another agent or developer:

1. **Context**: Help system rearch – manifest-driven, agent-friendly output
2. **Key files**: `help.sh`, `scripts.manifest`, `test/validate_help.sh`
3. **Current phase**: See task list checkboxes; Phase 1–3 status
4. **Blocker**: None known; manifest parsing was the main bug

### What to Run
```bash
./help.sh                    # Human output
./help.sh --markdown         # Agent output
./test/validate_help.sh      # Validation
./test/run_tests.sh --lint-only  # Full lint
```

### What Not to Change
- run_1.sh, run_2.sh, install.sh – already point to help.sh; do not modify
- lib/common_functions.sh – not part of help rearch

### Dependencies
- help.sh sources lib/common_functions.sh for colors
- scripts.manifest must exist; help.sh exits 1 if missing

---

## 6. Regression Prevention

| Test | Purpose |
|------|---------|
| help.sh exits 0 | Runnability |
| help.sh --markdown exits 0 | Markdown path |
| Manifest parses | No format errors |
| All manifest paths exist | No broken refs |
| Output contains TWO-PHASE, doctor | Core content |
| No duplicate paths | Data quality |

---

## 7. Rollback Plan

- Revert help.sh to hardcoded version; remove scripts.manifest if needed
- Phases 1–3 are additive; Phase 4 (dispatcher) is optional

---

## 8. Success Criteria

- [ ] help.sh runs without error
- [ ] help.sh --markdown produces valid Markdown
- [ ] Manifest is single source of truth
- [ ] validate_help.sh passes in CI
- [ ] Post-install tools prominently featured
- [ ] Best practices and usage guidance visible

---

## 9. Open Questions

1. Snapshot testing for help output?
2. install_phase1/2 – note as "generated" in manifest?
