# Commands

Canonical command surface:

- Bootstrap repo install: `./scripts/eth2qs.sh bootstrap --non-interactive`
- Configure scripts: `./scripts/eth2qs.sh configure --non-interactive`
- Detect the next safe install step: `./scripts/eth2qs.sh plan --json`
- Preview/apply the next safe step: `./scripts/eth2qs.sh ensure` or `./scripts/eth2qs.sh ensure --apply --confirm`
- Run Phase 1 hardening: `sudo ./scripts/eth2qs.sh phase1`
- Run Phase 2 install: `./scripts/eth2qs.sh phase2 --execution=geth --consensus=prysm --mev=mev-boost`
- Run explicit Monad install: `./scripts/eth2qs.sh monad-install`
- Health/status: `./scripts/eth2qs.sh doctor --json`
- Human-readable status: `./scripts/eth2qs.sh status`
- Start services: `./scripts/eth2qs.sh start`
- Stop services: `./scripts/eth2qs.sh stop`
- Restart services: `./scripts/eth2qs.sh restart`
- Service/system stats: `./scripts/eth2qs.sh stats`
- View logs: `./scripts/eth2qs.sh logs --run2 -n 200`
- Clean default data dirs only: `./scripts/eth2qs.sh clean-data --dry-run`
- Confirm cleanup after review: `./scripts/eth2qs.sh clean-data --confirm`
- Update installed components: `./scripts/eth2qs.sh update-all`

Prefer these commands over direct utility-script paths unless a task specifically needs the lower-level script.
