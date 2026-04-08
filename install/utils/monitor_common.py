#!/usr/bin/env python3
"""Shared helpers for eth2-quickstart monitoring, debug, and update surfaces."""

from __future__ import annotations

import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parents[1]
SERVICES = [
    "eth1",
    "cl",
    "validator",
    "mev",
    "commit-boost-pbs",
    "commit-boost-signer",
    "ethgas",
    "nginx",
    "caddy",
]
CORE_SERVICES = {"eth1", "cl", "validator"}
COMPONENT_REPOS = {
    "geth": "ethereum/go-ethereum",
    "mev_boost": "flashbots/mev-boost",
    "prysm": "prysmaticlabs/prysm",
}
READ_ONLY_COMMAND = "./scripts/eth2qs.sh doctor --json"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def run(command: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=str(cwd or ROOT_DIR),
        text=True,
        capture_output=True,
        check=False,
    )


def run_text(command: list[str], *, cwd: Path | None = None) -> str:
    return run(command, cwd=cwd).stdout.strip()


def parse_json_command(command: list[str], *, cwd: Path | None = None) -> dict[str, Any] | None:
    completed = run(command, cwd=cwd)
    if not completed.stdout.strip():
        return None
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError:
        return None
    return payload if isinstance(payload, dict) else None


def service_status(service: str) -> str:
    units = run(
        ["systemctl", "list-unit-files", f"{service}.service", "--no-legend", "--plain"]
    )
    if units.returncode != 0 or f"{service}.service" not in units.stdout:
        return "not_installed"
    if run(["systemctl", "is-failed", "--quiet", service]).returncode == 0:
        return "failed"
    if run(["systemctl", "is-active", "--quiet", service]).returncode == 0:
        return "running"
    if run(["systemctl", "is-enabled", "--quiet", service]).returncode == 0:
        return "stopped"
    return "disabled"


def systemctl_show(service: str, *properties: str) -> dict[str, str]:
    if not properties:
        return {}
    completed = run(["systemctl", "show", service, *[f"--property={prop}" for prop in properties]])
    if completed.returncode != 0:
        return {}
    output: dict[str, str] = {}
    for line in completed.stdout.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        output[key] = value
    return output


def journal_lines(service: str, *, lines: int = 50) -> list[str]:
    completed = run(["journalctl", "-u", service, "-n", str(lines), "--no-pager"])
    if completed.returncode != 0:
        return []
    return [line.rstrip() for line in completed.stdout.splitlines() if line.strip()]


def recent_errors(service: str, *, lines: int = 200) -> dict[str, object] | None:
    matches = [line for line in journal_lines(service, lines=lines) if "error" in line.lower()]
    if not matches:
        return None
    return {"service": service, "count": len(matches), "sample": matches[-1]}


def duty_lines() -> list[str]:
    completed = run(["journalctl", "-u", "validator", "-n", "1000", "--no-pager"])
    if completed.returncode != 0:
        return []
    lines = [line.strip() for line in completed.stdout.splitlines() if "timeTillDuty" in line]
    return lines[-5:]


def repo_status() -> dict[str, object] | None:
    upstream = run_text(["git", "rev-parse", "--abbrev-ref", "@{upstream}"], cwd=ROOT_DIR)
    if not upstream:
        return None
    counts = run_text(["git", "rev-list", "--left-right", "--count", f"HEAD...{upstream}"], cwd=ROOT_DIR)
    if not counts:
        return {"upstream": upstream, "ahead": None, "behind": None}
    ahead, behind = counts.split()
    return {"upstream": upstream, "ahead": int(ahead), "behind": int(behind)}


def find_prysm_binary(component: str) -> Path | None:
    prysm_dist = Path.home() / "prysm" / "dist"
    if not prysm_dist.is_dir():
        return None
    candidates = sorted(
        path
        for path in prysm_dist.iterdir()
        if component in path.name and path.is_file() and path.stat().st_mode & 0o111
    )
    return candidates[-1] if candidates else None


def version_or_unavailable(command: list[str], *, default: str = "unavailable") -> str:
    completed = run(command)
    return completed.stdout.strip() or default if completed.returncode == 0 else default


def current_geth_version() -> tuple[str, str | None]:
    completed = run(["bash", "-lc", "command -v geth >/dev/null 2>&1 && geth version"])
    stdout = completed.stdout.strip()
    if completed.returncode != 0 or not stdout:
        return "not_installed", None
    return stdout, extract_version(stdout)


def current_mev_boost_version() -> tuple[str, str | None]:
    binary = Path.home() / "mev-boost" / "mev-boost"
    if not binary.exists():
        return "not_installed", None
    stdout = run_text([str(binary), "-version"])
    return stdout or "unknown", extract_version(stdout)


def current_prysm_version() -> tuple[str, str | None]:
    binary = find_prysm_binary("validator") or find_prysm_binary("beacon-chain")
    if not binary:
        return "not_installed", None
    stdout = run_text([str(binary), "--version"])
    return stdout or "unknown", extract_version(stdout)


def get_versions() -> dict[str, str]:
    versions = {
        "mev_boost": "not_installed",
        "prysm_beacon": "not_installed",
        "prysm_validator": "not_installed",
        "geth": "not_installed",
    }
    mev_boost = Path.home() / "mev-boost" / "mev-boost"
    if mev_boost.exists():
        versions["mev_boost"] = version_or_unavailable([str(mev_boost), "-version"])
    beacon = find_prysm_binary("beacon-chain")
    if beacon:
        versions["prysm_beacon"] = version_or_unavailable([str(beacon), "--version"])
    elif (Path.home() / "prysm" / "prysm.sh").exists():
        versions["prysm_beacon"] = "unavailable (bootstrap script present, local binary not downloaded)"
    validator = find_prysm_binary("validator")
    if validator:
        versions["prysm_validator"] = version_or_unavailable([str(validator), "--version"])
    elif (Path.home() / "prysm" / "prysm.sh").exists():
        versions["prysm_validator"] = "unavailable (bootstrap script present, local binary not downloaded)"
    if run(["bash", "-lc", "command -v geth >/dev/null 2>&1"]).returncode == 0:
        versions["geth"] = version_or_unavailable(["geth", "version"])
    return versions


def extract_version(text: str) -> str | None:
    patterns = (
        r"Version:\s*([0-9A-Za-z._+-]+)",
        r"\bv?(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z._-]+)?)\b",
    )
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            return match.group(1).lstrip("v")
    return None


def version_key(version: str | None) -> tuple[int, ...] | None:
    if not version:
        return None
    digits = re.findall(r"\d+", version)
    if not digits:
        return None
    return tuple(int(part) for part in digits[:4])


def compare_versions(current: str | None, latest: str | None) -> str:
    current_key = version_key(current)
    latest_key = version_key(latest)
    if not current_key or not latest_key:
        return "unknown"
    if current_key < latest_key:
        return "outdated"
    if current_key > latest_key:
        return "ahead"
    return "current"


def listening_ports(pid: int | None = None) -> list[dict[str, str]]:
    completed = run(["ss", "-ltnpH"])
    if completed.returncode != 0:
        return []
    results: list[dict[str, str]] = []
    pid_fragment = f"pid={pid}," if pid else None
    for line in completed.stdout.splitlines():
        if pid_fragment and pid_fragment not in line:
            continue
        parts = line.split()
        if len(parts) < 5:
            continue
        results.append(
            {
                "local_address": parts[3],
                "peer_address": parts[4],
                "raw": line.strip(),
            }
        )
    return results
