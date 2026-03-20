# Agent Skill Listing

Use this copy for registry listings, launch posts, README snippets, or website blurbs.

## Short Description

Repo-aware Ethereum node ops skill for `eth2-quickstart`.

## Listing Copy

Bootstrap, operate, diagnose, update, and safely clean Ethereum node stacks through the real repo command surface. The skill is designed to run inside an `eth2-quickstart` checkout, routes through `./scripts/eth2qs.sh`, uses `doctor --json` for machine-readable health, and preserves keys and secrets during cleanup.

## Install

- Primary: `clawhub install eth2-quickstart`
- Fallback: `git clone --depth 1 https://github.com/chimera-defi/eth2-quickstart.git && cd eth2-quickstart`
- Codex fallback: `python ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py --repo chimera-defi/eth2-quickstart --path skills/eth2-quickstart`
- Raw-ingest fallback: share `llms.txt` or `llms-full.txt`

## Demo

```bash
./scripts/eth2qs.sh phase2 --execution=geth --consensus=prysm --mev=mev-boost
./scripts/eth2qs.sh monad-install
./scripts/eth2qs.sh doctor --json
./scripts/eth2qs.sh stats
./scripts/eth2qs.sh logs --run2 -n 200
./scripts/eth2qs.sh clean-data --dry-run
sudo ./scripts/eth2qs.sh cleanup-host --dry-run
```

## Do Not Claim

- Do not claim it is a global standalone agent package
- Do not claim it manages validator secrets
- Do not claim it replaces human confirmation for root, reboot, or destructive actions
