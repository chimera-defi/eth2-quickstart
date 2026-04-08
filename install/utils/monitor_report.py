#!/usr/bin/env python3
"""Compact monitoring export, history, and snapshot helpers."""

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

from monitor_common import now_iso  # noqa: E402
import stats_json  # noqa: E402
import update_check  # noqa: E402


MONITOR_DIR_ENV = "ETH2QS_MONITOR_DIR"
MONITOR_STATS_FIXTURE_ENV = "ETH2QS_MONITOR_STATS_FIXTURE"
MONITOR_UPDATE_FIXTURE_ENV = "ETH2QS_MONITOR_UPDATE_FIXTURE"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("action", nargs="?", default="export", choices=("export", "snapshot", "history"))
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("-h", "--help", action="store_true")
    return parser.parse_args(argv)


def monitor_dir() -> Path:
    configured = os.environ.get(MONITOR_DIR_ENV)
    if configured:
        return Path(configured).expanduser().resolve()
    return (Path.home() / ".eth2qs-monitor").resolve()


def snapshots_dir() -> Path:
    return monitor_dir() / "snapshots"


def _current_stats_payload() -> dict[str, Any]:
    fixture = os.environ.get(MONITOR_STATS_FIXTURE_ENV)
    if fixture:
        return json.loads(fixture)
    return stats_json.build_payload()


def _current_update_payload() -> dict[str, Any]:
    fixture = os.environ.get(MONITOR_UPDATE_FIXTURE_ENV)
    if fixture:
        return json.loads(fixture)
    return update_check.build_payload()


def _combined_status(*statuses: str) -> str:
    values = set(statuses)
    if "fail" in values:
        return "fail"
    if "warn" in values:
        return "warn"
    if "pass" in values:
        return "pass"
    return "info"


def build_export_payload(
    *,
    stats_payload: dict[str, Any] | None = None,
    update_payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    stats_data = stats_payload or _current_stats_payload()
    update_data = update_payload or _current_update_payload()
    top_issues = [
        issue
        for issue in stats_data.get("issues", [])
        if issue.get("severity") in {"warn", "fail"}
    ][:5]
    update_findings = [
        check
        for check in update_data.get("checks", [])
        if check.get("status") == "warn"
    ][:5]
    summary = {
        "status": _combined_status(
            stats_data["summary"]["status"],
            update_data["summary"]["status"],
        ),
        "stats_status": stats_data["summary"]["status"],
        "update_status": update_data["summary"]["status"],
        "services_failed": stats_data["summary"]["services_failed"],
        "issues_detected": stats_data["summary"]["issues_detected"],
        "outdated_components": update_data["summary"]["outdated_components"],
        "repo_behind_commits": update_data["summary"]["repo_behind_commits"],
    }
    return {
        "generated_at": now_iso(),
        "summary": summary,
        "top_issues": top_issues,
        "update_findings": update_findings,
        "stats": {
            "summary": stats_data["summary"],
            "doctor_summary": stats_data.get("doctor_summary"),
            "repair_preview": stats_data.get("repair_preview", []),
        },
        "update_check": {
            "summary": update_data["summary"],
            "checks": update_data.get("checks", []),
        },
    }


def snapshot_filename(generated_at: str) -> str:
    safe = generated_at.replace(":", "").replace("+00:00", "Z")
    return f"{safe}.json"


def write_snapshot() -> dict[str, Any]:
    stats_payload = _current_stats_payload()
    update_payload = _current_update_payload()
    export_payload = build_export_payload(stats_payload=stats_payload, update_payload=update_payload)
    target_dir = snapshots_dir()
    target_dir.mkdir(parents=True, exist_ok=True)
    path = target_dir / snapshot_filename(export_payload["generated_at"])
    payload = {
        "generated_at": export_payload["generated_at"],
        "export": export_payload,
        "stats": stats_payload,
        "update_check": update_payload,
    }
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return {
        "generated_at": export_payload["generated_at"],
        "summary": export_payload["summary"],
        "path": str(path),
    }


def _load_snapshot(path: Path) -> dict[str, Any] | None:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def build_history_payload(limit: int = 5) -> dict[str, Any]:
    paths = sorted(snapshots_dir().glob("*.json"), reverse=True)[:limit]
    entries: list[dict[str, Any]] = []
    for path in paths:
        payload = _load_snapshot(path)
        if not payload:
            continue
        export = payload.get("export", {})
        summary = export.get("summary", {})
        entry = {
            "generated_at": payload.get("generated_at"),
            "path": str(path),
            "summary": summary,
        }
        entries.append(entry)
    for index, entry in enumerate(entries[:-1]):
        next_summary = entries[index + 1]["summary"]
        summary = entry["summary"]
        entry["delta"] = {
            "issues_detected": summary.get("issues_detected", 0) - next_summary.get("issues_detected", 0),
            "services_failed": summary.get("services_failed", 0) - next_summary.get("services_failed", 0),
            "outdated_components": summary.get("outdated_components", 0) - next_summary.get("outdated_components", 0),
        }
    return {
        "generated_at": now_iso(),
        "summary": {
            "entries": len(entries),
            "monitor_dir": str(monitor_dir()),
        },
        "entries": entries,
    }


def print_export_human(payload: dict[str, Any]) -> None:
    summary = payload["summary"]
    print("=== Monitor Export ===")
    print(
        f"status={summary['status']} "
        f"stats={summary['stats_status']} "
        f"updates={summary['update_status']} "
        f"issues={summary['issues_detected']} "
        f"services_failed={summary['services_failed']} "
        f"outdated_components={summary['outdated_components']} "
        f"repo_behind={summary['repo_behind_commits']}"
    )
    if payload["top_issues"]:
        print("top_issues=")
        for issue in payload["top_issues"]:
            print(f"  - [{issue['severity']}] {issue['kind']}: {issue['summary']}")
    if payload["update_findings"]:
        print("update_findings=")
        for check in payload["update_findings"]:
            print(f"  - {check['component']}: {check['summary']}")


def print_history_human(payload: dict[str, Any]) -> None:
    print("=== Monitor History ===")
    print(f"entries={payload['summary']['entries']} dir={payload['summary']['monitor_dir']}")
    for entry in payload["entries"]:
        summary = entry["summary"]
        line = (
            f"- {entry['generated_at']} "
            f"status={summary.get('status')} "
            f"issues={summary.get('issues_detected')} "
            f"failed={summary.get('services_failed')} "
            f"outdated={summary.get('outdated_components')} "
            f"path={entry['path']}"
        )
        if "delta" in entry:
            delta = entry["delta"]
            line += (
                f" delta(issues={delta['issues_detected']},"
                f" failed={delta['services_failed']},"
                f" outdated={delta['outdated_components']})"
            )
        print(line)


def main() -> None:
    args = parse_args(sys.argv[1:])
    if args.help:
        print("Usage: ./install/utils/monitor.sh [export|snapshot|history] [--json] [--limit N]")
        return

    if args.action == "snapshot":
        payload = write_snapshot()
        if args.json:
            print(json.dumps(payload, indent=2))
            return
        print(f"Saved monitor snapshot: {payload['path']}")
        print(
            f"status={payload['summary']['status']} "
            f"issues={payload['summary']['issues_detected']} "
            f"failed={payload['summary']['services_failed']} "
            f"outdated={payload['summary']['outdated_components']}"
        )
        return

    if args.action == "history":
        payload = build_history_payload(limit=args.limit)
        if args.json:
            print(json.dumps(payload, indent=2))
            return
        print_history_human(payload)
        return

    payload = build_export_payload()
    if args.json:
        print(json.dumps(payload, indent=2))
        return
    print_export_human(payload)


if __name__ == "__main__":
    main()
