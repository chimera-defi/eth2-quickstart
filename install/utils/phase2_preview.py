#!/usr/bin/env python3
"""Preview the explicit Phase 2 command and config updates without mutating the host."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
CLIENT_OPTIONS_FILE = ROOT_DIR / "config" / "client_options.json"


def load_client_options() -> dict:
    return json.loads(CLIENT_OPTIONS_FILE.read_text(encoding="utf-8"))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="./install/utils/phase2_preview.py",
        description="Preview the explicit Phase 2 command and config updates.",
    )
    parser.add_argument("--json", action="store_true", help="Output JSON")
    parser.add_argument("--network")
    parser.add_argument("--execution")
    parser.add_argument("--consensus")
    parser.add_argument("--mev")
    parser.add_argument("--ethgas", action="store_true")
    parser.add_argument("--skip-deps", action="store_true")
    return parser.parse_args()


def validate_choice(name: str, value: str | None, allowed: set[str]) -> None:
    if value is not None and value not in allowed:
        raise SystemExit(f"Unsupported {name}: {value}")


def preview_payload(args: argparse.Namespace, options: dict) -> dict:
    validate_choice("network", args.network, set(options["networks"]))
    validate_choice("execution client", args.execution, set(options["execution_clients"]))
    validate_choice("consensus client", args.consensus, set(options["consensus_clients"]))
    validate_choice("mev", args.mev, set(options["mev_options"]))

    if args.ethgas and args.mev != options["ethgas_requires"]["mev"]:
        raise SystemExit("ETHGas requires --mev=commit-boost")

    interactive = not any([args.execution, args.consensus, args.mev, args.ethgas])
    wrapper_command = ["./scripts/eth2qs.sh", "phase2"]
    run_2_command = ["./run_2.sh"]
    if args.execution:
        wrapper_command.append(f"--execution={args.execution}")
        run_2_command.append(f"--execution={args.execution}")
    if args.consensus:
        wrapper_command.append(f"--consensus={args.consensus}")
        run_2_command.append(f"--consensus={args.consensus}")
    if args.mev:
        wrapper_command.append(f"--mev={args.mev}")
        run_2_command.append(f"--mev={args.mev}")
    if args.ethgas:
        wrapper_command.append("--ethgas")
        run_2_command.append("--ethgas")
    if args.skip_deps:
        wrapper_command.append("--skip-deps")
        run_2_command.append("--skip-deps")

    config_updates: dict[str, str] = {}
    if args.network:
        config_updates["ETH_NETWORK"] = args.network
        config_updates["ETHGAS_NETWORK"] = args.network

    notes = []
    if interactive:
        notes.append("No explicit execution/consensus/MEV flags were provided; running phase2 bare will enter the interactive installer.")
    else:
        notes.append("The preview is explicit and non-interactive if you run the returned command as the configured non-root operator.")
    if config_updates:
        notes.append("Apply the returned config_updates to config/user_config.env before running phase2 if you want the network override persisted.")

    return {
        "requested": {
            "network": args.network,
            "execution": args.execution,
            "consensus": args.consensus,
            "mev": args.mev,
            "ethgas": args.ethgas,
            "skip_deps": args.skip_deps,
        },
        "interactive": interactive,
        "wrapper_command": wrapper_command,
        "run_2_command": run_2_command,
        "config_updates": config_updates,
        "constraints": {"ethgas_requires": options["ethgas_requires"]},
        "source_of_truth": {
            "client_options_json": "./config/client_options.json"
        },
        "notes": notes,
    }


def print_human(payload: dict) -> None:
    print("Phase 2 preview")
    print(f"Interactive:     {payload['interactive']}")
    print("Wrapper command: " + " ".join(payload["wrapper_command"]))
    print("run_2 command:   " + " ".join(payload["run_2_command"]))
    if payload["config_updates"]:
        print("Config updates:")
        for key, value in payload["config_updates"].items():
            print(f"  - {key}={value}")
    else:
        print("Config updates:  none")
    print("Notes:")
    for note in payload["notes"]:
        print(f"  - {note}")


def main() -> None:
    args = parse_args()
    payload = preview_payload(args, load_client_options())
    if args.json:
        print(json.dumps(payload, indent=2))
        return
    print_human(payload)


if __name__ == "__main__":
    main()
