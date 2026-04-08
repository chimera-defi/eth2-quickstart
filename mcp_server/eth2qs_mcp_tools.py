#!/usr/bin/env python3
"""Thin MCP tool adapter for the eth2-quickstart wrapper."""

from __future__ import annotations

import os
import json
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional

ROOT_DIR = Path(__file__).resolve().parent.parent
CLIENT_OPTIONS_FILE = ROOT_DIR / "config" / "client_options.json"
ALLOWED_CHAINS = {"ethereum", "monad"}
ALLOWED_LOG_TARGETS = {"run1", "run2"}
ALLOWED_DEBUG_SERVICES = {
    "eth1",
    "cl",
    "validator",
    "mev",
    "commit-boost-pbs",
    "commit-boost-signer",
    "ethgas",
    "nginx",
    "caddy",
}
MAX_LOG_LINES = 500
MAX_DEBUG_LINES = 200
MAX_HISTORY_LIMIT = 20
CONFIRM_TOKEN = "apply"


def _load_client_options() -> Dict[str, Any]:
    return json.loads(CLIENT_OPTIONS_FILE.read_text(encoding="utf-8"))


CLIENT_OPTIONS = _load_client_options()
ALLOWED_EXECUTION_CLIENTS = set(CLIENT_OPTIONS["execution_clients"])
ALLOWED_CONSENSUS_CLIENTS = set(CLIENT_OPTIONS["consensus_clients"])
ALLOWED_MEV_OPTIONS = set(CLIENT_OPTIONS["mev_options"])


def resolve_repo_root() -> Path:
    repo_root = os.environ.get("REPO_ROOT")
    if repo_root:
        return Path(repo_root).resolve()
    return ROOT_DIR


def eth2qs_path() -> Path:
    return resolve_repo_root() / "scripts" / "eth2qs.sh"


def _run(command: List[str]) -> Dict[str, Any]:
    completed = subprocess.run(
        command,
        cwd=str(resolve_repo_root()),
        text=True,
        capture_output=True,
        check=False,
    )
    return {
        "command": command,
        "cwd": str(resolve_repo_root()),
        "exit_code": completed.returncode,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
        "ok": completed.returncode == 0,
    }


def _eth2qs(*args: str) -> Dict[str, Any]:
    path = eth2qs_path()
    return _run([str(path), *args])


def _validate_chain(chain: Optional[str]) -> List[str]:
    if not chain:
        return []
    if chain not in ALLOWED_CHAINS:
        raise ValueError(f"Unsupported chain: {chain}")
    return [f"--chain={chain}"]


def _validate_log_target(target: str) -> str:
    if target not in ALLOWED_LOG_TARGETS:
        raise ValueError(f"Unsupported log target: {target}")
    return target


def _validate_lines(lines: int) -> int:
    if lines < 1 or lines > MAX_LOG_LINES:
        raise ValueError(f"lines must be between 1 and {MAX_LOG_LINES}")
    return lines


def _validate_debug_lines(lines: int) -> int:
    if lines < 1 or lines > MAX_DEBUG_LINES:
        raise ValueError(f"lines must be between 1 and {MAX_DEBUG_LINES}")
    return lines


def _validate_history_limit(limit: int) -> int:
    if limit < 1 or limit > MAX_HISTORY_LIMIT:
        raise ValueError(f"limit must be between 1 and {MAX_HISTORY_LIMIT}")
    return limit


def _validate_service(service: Optional[str]) -> List[str]:
    if not service:
        return []
    if service not in ALLOWED_DEBUG_SERVICES:
        raise ValueError(f"Unsupported service: {service}")
    return ["--service", service]


def _require_confirm(confirm: bool, token: str) -> None:
    if not confirm or token != CONFIRM_TOKEN:
        raise ValueError("This action requires confirm=true and confirmation_token='apply'")


def _optional_choice(flag: str, value: Optional[str], allowed: set[str]) -> List[str]:
    if value is None:
        return []
    if value not in allowed:
        raise ValueError(f"Unsupported {flag}: {value}")
    return [f"--{flag}={value}"]


def help_tool() -> Dict[str, Any]:
    return _eth2qs("help")


def doctor_json() -> Dict[str, Any]:
    return _eth2qs("doctor", "--json")


def plan_json(chain: Optional[str] = None) -> Dict[str, Any]:
    return _eth2qs("plan", "--json", *_validate_chain(chain))


def ensure_preview(chain: Optional[str] = None) -> Dict[str, Any]:
    return _eth2qs("ensure", *_validate_chain(chain))


def ensure_apply(chain: Optional[str] = None, *, confirm: bool = False, confirmation_token: str = "") -> Dict[str, Any]:
    _require_confirm(confirm, confirmation_token)
    return _eth2qs("ensure", "--apply", "--confirm", *_validate_chain(chain))


def phase1(*, confirm: bool = False, confirmation_token: str = "") -> Dict[str, Any]:
    _require_confirm(confirm, confirmation_token)
    return _eth2qs("phase1")


def phase2(
    execution: Optional[str] = None,
    consensus: Optional[str] = None,
    mev: Optional[str] = None,
    *,
    ethgas: bool = False,
    confirm: bool = False,
    confirmation_token: str = "",
) -> Dict[str, Any]:
    _require_confirm(confirm, confirmation_token)
    args = [
        "phase2",
        *_optional_choice("execution", execution, ALLOWED_EXECUTION_CLIENTS),
        *_optional_choice("consensus", consensus, ALLOWED_CONSENSUS_CLIENTS),
        *_optional_choice("mev", mev, ALLOWED_MEV_OPTIONS),
    ]
    if ethgas:
        args.append("--ethgas")
    return _eth2qs(*args)


def client_options() -> Dict[str, Any]:
    return _load_client_options()


def stats() -> Dict[str, Any]:
    return _eth2qs("stats")


def stats_json() -> Dict[str, Any]:
    return _eth2qs("stats", "--json")


def update_check_json() -> Dict[str, Any]:
    return _eth2qs("update-check", "--json")


def debug_json(service: Optional[str] = None, *, lines: int = 40) -> Dict[str, Any]:
    return _eth2qs(
        "debug",
        "--json",
        *_validate_service(service),
        "--lines",
        str(_validate_debug_lines(lines)),
    )


def monitor_export_json() -> Dict[str, Any]:
    return _eth2qs("monitor", "export", "--json")


def monitor_history_json(*, limit: int = 5) -> Dict[str, Any]:
    return _eth2qs("monitor", "history", "--json", "--limit", str(_validate_history_limit(limit)))


def repair_preview() -> Dict[str, Any]:
    return _eth2qs("repair")


def repair_apply(*, confirm: bool = False, confirmation_token: str = "") -> Dict[str, Any]:
    _require_confirm(confirm, confirmation_token)
    return _eth2qs("repair", "--apply", "--confirm")


def logs(target: str = "run2", lines: int = 200) -> Dict[str, Any]:
    target = _validate_log_target(target)
    lines = _validate_lines(lines)
    return _eth2qs("logs", f"--{target}", "-n", str(lines))


def start(*, confirm: bool = False, confirmation_token: str = "") -> Dict[str, Any]:
    _require_confirm(confirm, confirmation_token)
    return _eth2qs("start")


def stop(*, confirm: bool = False, confirmation_token: str = "") -> Dict[str, Any]:
    _require_confirm(confirm, confirmation_token)
    return _eth2qs("stop")


def restart(*, confirm: bool = False, confirmation_token: str = "") -> Dict[str, Any]:
    _require_confirm(confirm, confirmation_token)
    return _eth2qs("restart")


def clean_data_dry_run() -> Dict[str, Any]:
    return _eth2qs("clean-data", "--dry-run")


def cleanup_host_dry_run() -> Dict[str, Any]:
    return _eth2qs("cleanup-host", "--dry-run")


def monad_install(*, confirm: bool = False, confirmation_token: str = "") -> Dict[str, Any]:
    _require_confirm(confirm, confirmation_token)
    return _eth2qs("monad-install")


TOOL_NAMES = (
    "eth2qs_info",
    "eth2qs_help",
    "eth2qs_doctor_json",
    "eth2qs_plan_json",
    "eth2qs_ensure_preview",
    "eth2qs_ensure_apply",
    "eth2qs_client_options",
    "eth2qs_phase1",
    "eth2qs_phase2",
    "eth2qs_stats",
    "eth2qs_stats_json",
    "eth2qs_update_check_json",
    "eth2qs_debug_json",
    "eth2qs_monitor_export_json",
    "eth2qs_monitor_history_json",
    "eth2qs_repair_preview",
    "eth2qs_repair_apply",
    "eth2qs_logs",
    "eth2qs_start",
    "eth2qs_stop",
    "eth2qs_restart",
    "eth2qs_clean_data_dry_run",
    "eth2qs_cleanup_host_dry_run",
    "eth2qs_monad_install",
)


def server_info() -> Dict[str, Any]:
    return {
        "name": "eth2-quickstart-mcp",
        "repo_root": str(resolve_repo_root()),
        "wrapper": str(eth2qs_path()),
        "tool_names": list(TOOL_NAMES),
        "tool_groups": {
            "read_only": [
                "eth2qs_info",
                "eth2qs_help",
                "eth2qs_doctor_json",
                "eth2qs_plan_json",
                "eth2qs_ensure_preview",
                "eth2qs_client_options",
                "eth2qs_stats",
                "eth2qs_stats_json",
                "eth2qs_update_check_json",
                "eth2qs_debug_json",
                "eth2qs_monitor_export_json",
                "eth2qs_monitor_history_json",
                "eth2qs_repair_preview",
                "eth2qs_logs",
                "eth2qs_clean_data_dry_run",
                "eth2qs_cleanup_host_dry_run",
            ],
            "mutating_confirm_required": [
                "eth2qs_ensure_apply",
                "eth2qs_phase1",
                "eth2qs_phase2",
                "eth2qs_start",
                "eth2qs_stop",
                "eth2qs_restart",
                "eth2qs_repair_apply",
                "eth2qs_monad_install",
            ],
        },
        "call_examples": {
            "eth2qs_doctor_json": {},
            "eth2qs_plan_json": {"chain": "ethereum"},
            "eth2qs_client_options": {},
            "eth2qs_stats_json": {},
            "eth2qs_update_check_json": {},
            "eth2qs_debug_json": {"service": "cl", "lines": 40},
            "eth2qs_monitor_export_json": {},
            "eth2qs_monitor_history_json": {"limit": 5},
            "eth2qs_repair_preview": {},
            "eth2qs_phase1": {"confirm": True, "confirmation_token": "apply"},
            "eth2qs_phase2": {
                "execution": "geth",
                "consensus": "prysm",
                "mev": "mev-boost",
                "confirm": True,
                "confirmation_token": "apply",
            },
            "eth2qs_ensure_apply": {
                "chain": "ethereum",
                "confirm": True,
                "confirmation_token": "apply",
            },
            "eth2qs_repair_apply": {"confirm": True, "confirmation_token": "apply"},
            "eth2qs_clean_data_dry_run": {},
        },
    }


__all__ = [
    "clean_data_dry_run",
    "cleanup_host_dry_run",
    "client_options",
    "CONFIRM_TOKEN",
    "debug_json",
    "doctor_json",
    "ensure_apply",
    "ensure_preview",
    "phase1",
    "phase2",
    "help_tool",
    "logs",
    "monitor_export_json",
    "monitor_history_json",
    "monad_install",
    "plan_json",
    "repair_apply",
    "repair_preview",
    "resolve_repo_root",
    "restart",
    "server_info",
    "TOOL_NAMES",
    "start",
    "stats",
    "stats_json",
    "stop",
    "update_check_json",
]
