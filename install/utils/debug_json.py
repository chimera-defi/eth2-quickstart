#!/usr/bin/env python3
"""Structured debug surface for eth2-quickstart services."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from monitor_common import (  # noqa: E402
    SERVICES,
    journal_lines,
    listening_ports,
    now_iso,
    recent_errors,
    service_status,
    systemctl_show,
)
import stats_json  # noqa: E402


FIXTURE_ENV = "ETH2QS_DEBUG_FIXTURE"
DEFAULT_LOG_LINES = 40
UNIT_PROPERTIES = (
    "LoadState",
    "UnitFileState",
    "ActiveState",
    "SubState",
    "FragmentPath",
    "ExecStart",
    "ExecMainPID",
)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--service", action="append", default=[])
    parser.add_argument("--lines", type=int, default=DEFAULT_LOG_LINES)
    parser.add_argument("-h", "--help", action="store_true")
    return parser.parse_args(argv)


def _validate_services(requested: list[str]) -> list[str]:
    if not requested:
        return []
    unknown = sorted({service for service in requested if service not in SERVICES})
    if unknown:
        raise SystemExit(f"Unsupported service(s): {', '.join(unknown)}")
    deduped: list[str] = []
    for service in requested:
        if service not in deduped:
            deduped.append(service)
    return deduped


def _selected_services(requested: list[str], service_states: dict[str, str]) -> list[str]:
    validated = _validate_services(requested)
    if validated:
        return validated
    installed = [service for service, state in service_states.items() if state != "not_installed"]
    return installed or list(SERVICES[:3])


def _safe_pid(value: str) -> int | None:
    try:
        pid = int(value)
    except (TypeError, ValueError):
        return None
    return pid if pid > 0 else None


def service_debug(service: str, *, service_state: str, log_lines: int) -> dict[str, Any]:
    unit = systemctl_show(service, *UNIT_PROPERTIES)
    pid = _safe_pid(unit.get("ExecMainPID", ""))
    logs = journal_lines(service, lines=log_lines)
    return {
        "service": service,
        "status": service_state,
        "unit": {
            "load_state": unit.get("LoadState"),
            "unit_file_state": unit.get("UnitFileState"),
            "active_state": unit.get("ActiveState"),
            "sub_state": unit.get("SubState"),
            "fragment_path": unit.get("FragmentPath"),
            "exec_start": unit.get("ExecStart"),
            "main_pid": pid,
        },
        "recent_error": recent_errors(service, lines=max(log_lines, 200)),
        "listen_sockets": listening_ports(pid=pid),
        "recent_log_tail": logs[-log_lines:],
    }


def build_payload(*, requested_services: list[str] | None = None, log_lines: int = DEFAULT_LOG_LINES) -> dict[str, Any]:
    fixture = os.environ.get(FIXTURE_ENV)
    if fixture:
        return json.loads(fixture)

    requested = requested_services or []
    validated_requested = _validate_services(requested)
    stats_payload = stats_json.build_payload(service_names=validated_requested or None)
    services = _selected_services(validated_requested, stats_payload["service_states"])
    debug_services = [
        service_debug(service, service_state=stats_payload["service_states"][service], log_lines=log_lines)
        for service in services
    ]
    failing_services = sum(1 for item in debug_services if item["status"] == "failed")
    stopped_services = sum(1 for item in debug_services if item["status"] == "stopped")
    return {
        "generated_at": now_iso(),
        "summary": {
            "status": stats_payload["summary"]["status"],
            "services_examined": len(debug_services),
            "services_failed": failing_services,
            "services_stopped": stopped_services,
            "issues_detected": stats_payload["summary"]["issues_detected"],
        },
        "doctor_summary": stats_payload.get("doctor_summary"),
        "repo_status": stats_payload.get("repo_status"),
        "issues": stats_payload["issues"],
        "services": debug_services,
    }


def print_human(payload: dict[str, Any]) -> None:
    summary = payload["summary"]
    print("=== Debug Summary ===")
    print(f"Status: {summary['status']}")
    print(
        "Services examined: "
        f"{summary['services_examined']} "
        f"(failed={summary['services_failed']}, stopped={summary['services_stopped']})"
    )
    print(f"Issues detected: {summary['issues_detected']}")
    print("")
    for item in payload["services"]:
        unit = item["unit"]
        print(f"=== {item['service']} ===")
        print(
            f"state={item['status']} "
            f"active={unit['active_state']} "
            f"sub={unit['sub_state']} "
            f"unit_file={unit['unit_file_state']}"
        )
        print(f"fragment={unit['fragment_path'] or 'n/a'}")
        print(f"exec={unit['exec_start'] or 'n/a'}")
        if item["recent_error"]:
            print(
                f"recent_error={item['recent_error']['count']} "
                f"sample={item['recent_error']['sample']}"
            )
        else:
            print("recent_error=none")
        if item["listen_sockets"]:
            print("listen_sockets=")
            for socket in item["listen_sockets"][:5]:
                print(f"  - {socket['local_address']} -> {socket['peer_address']}")
        if item["recent_log_tail"]:
            print("recent_log_tail=")
            for line in item["recent_log_tail"][-5:]:
                print(f"  - {line}")
        print("")


def main() -> None:
    args = parse_args(sys.argv[1:])
    if args.help:
        print("Usage: ./install/utils/debug.sh [--json] [--service <name>] [--lines <n>]")
        return
    payload = build_payload(requested_services=args.service, log_lines=args.lines)
    if args.json:
        print(json.dumps(payload, indent=2))
        return
    print_human(payload)


if __name__ == "__main__":
    main()
