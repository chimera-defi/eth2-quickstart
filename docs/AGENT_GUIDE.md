# Agent Guide – Ethereum Node Quick Setup

**Purpose:** Consolidated entry point for AI agents and developers. Use this doc to understand the project, discover tools, and avoid common pitfalls.

---

## Quick Start for Agents

### 1. Discover All Scripts and Tools

```bash
./help.sh --markdown
```

Output is Markdown-formatted for easy parsing. Includes:
- Two-phase installation flow
- **Post-install: keep your node healthy** – doctor, stats, view_logs, refresh, start, update
- Full script inventory by category
- System commands (systemctl, journalctl)
- Best practices

### 2. Manifest (Machine-Readable)

- **scripts.manifest** – Single source of truth for help output
- Format: `path :: category :: description :: usage :: flags :: requires`
- Add new scripts here; help.sh reads it automatically

### 3. Key Paths

| What | Where |
|------|-------|
| Help output | `./help.sh` or `./help.sh --markdown` |
| Script manifest | `scripts.manifest` |
| Help spec | `docs/HELP_SYSTEM_REARCH_SPEC.md` |
| Config reference | `configs/AGENT_REFERENCE.md` |
| Two-phase security | `.cursorrules` (critical section) |

---

## Two-Phase Security Model (CRITICAL)

**This project handles real money (ETH validators).** Installation MUST follow a two-phase model with a **mandatory reboot** between phases.

| Phase | User | Scripts | Ends With |
|-------|------|---------|-----------|
| **Phase 1** | root | `run_1.sh`, `install_phase1.sh` | **REBOOT** |
| **Phase 2** | new user (NOT root) | `run_2.sh`, `install_phase2.sh` | Clients running |

### Never Do This

```bash
./run_1.sh && ./run_2.sh   # ❌ Skips reboot and verification
```

### Always Do This

```bash
sudo ./install_phase1.sh   # Phase 1 as root
sudo reboot               # MANDATORY
# SSH back as new user
./install_phase2.sh       # Phase 2 as new user
```

### Before Modifying Installation Flow

1. Read `run_1.sh` and `run_2.sh` to understand the security boundary
2. Verify changes preserve Phase 1 → REBOOT → Phase 2
3. Test that Phase 2 refuses to run as root
4. See `docs/archive/AGENT_HANDOFF.md` for full flywheel/install details

---

## Post-Install Tools (High Value)

These scripts users run most after install. Feature them when helping users debug or maintain:

| Script | Purpose |
|--------|---------|
| `./install/utils/doctor.sh` | Health check: system, services, config, ports |
| `./install/utils/stats.sh` | Client versions, service status, errors |
| `./install/utils/view_logs.sh` | Inspect logs (`--run2 -f` to follow) |
| `./install/utils/refresh.sh` | Restart all services |
| `./install/utils/start.sh` | Start services after reboot |
| `./install/utils/update.sh` | Update Ethereum clients |

---

## Documentation Map

### Install & Tooling

| Doc | Purpose |
|-----|---------|
| [HELP_SYSTEM_REARCH_SPEC.md](HELP_SYSTEM_REARCH_SPEC.md) | Help system spec, manifest format, handoff |
| [SCRIPTS.md](SCRIPTS.md) | Detailed script reference |
| [WORKFLOW.md](WORKFLOW.md) | Setup workflow |
| [archive/AGENT_HANDOFF.md](archive/AGENT_HANDOFF.md) | Two-phase model, flywheel, lessons learned |

### Configuration

| Doc | Purpose |
|-----|---------|
| [CONFIGURATION_GUIDE.md](CONFIGURATION_GUIDE.md) | Config architecture |
| [../configs/AGENT_REFERENCE.md](../configs/AGENT_REFERENCE.md) | Config agent reference |

### Frontend

| Doc | Purpose |
|-----|---------|
| [FRONTEND_SUMMARY.md](FRONTEND_SUMMARY.md) | Start here |
| [FRONTEND_AGENT_PROMPTS_V2.md](FRONTEND_AGENT_PROMPTS_V2.md) | Copy-paste prompts |
| [FRONTEND_AGENT_HANDOFF.md](FRONTEND_AGENT_HANDOFF.md) | Design specs, handoff |

### Development

| Doc | Purpose |
|-----|---------|
| [SHELL_SCRIPTING_BEST_PRACTICES_AND_LINTING_GUIDE.md](SHELL_SCRIPTING_BEST_PRACTICES_AND_LINTING_GUIDE.md) | Shell standards |
| [COMMIT_MESSAGES.md](COMMIT_MESSAGES.md) | Conventional commits |

---

## Agent Checklist

### Before Making Changes

- [ ] Run `./help.sh --markdown` to see current tool inventory
- [ ] Read relevant docs from the map above
- [ ] For install changes: read `run_1.sh` and `run_2.sh`
- [ ] For frontend: use Bun, never npm

### After Making Changes

- [ ] Run `./test/run_tests.sh --lint-only`
- [ ] Run `./test/validate_help.sh` if touching help/manifest
- [ ] Use conventional commits: `type(scope): description`

### Adding a New Script

1. Add line to `scripts.manifest`: `path :: category :: description :: usage :: flags :: requires`
2. Run `./help.sh` to verify
3. Run `./test/validate_help.sh`

---

## Common Pitfalls

1. **Combining phases** – Never run Phase 1 and Phase 2 without reboot
2. **Hardcoding in help.sh** – Use manifest; help.sh reads it
3. **npm in frontend** – Use Bun only
4. **Duplicating code** – Use `lib/common_functions.sh`
5. **Skipping validate_help** – Run it when changing help or manifest
