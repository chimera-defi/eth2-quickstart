#!/usr/bin/env python3
"""Thin MCP tool adapter for the eth2-quickstart wrapper."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional

ROOT_DIR = Path(__file__).resolve().parent.parent
ALLOWED_CHAINS = {"ethereum", "monad"}
ALLOWED_LOG_TARGETS = {"run1", "run2"}
MAX_LOG_LINES = 500
CONFIRM_TOKEN = "apply"


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


def _require_confirm(confirm: bool, token: str) -> None:
    if not confirm or token != CONFIRM_TOKEN:
        raise ValueError("This action requires confirm=true and confirmation_token='apply'")


def server_info() -> Dict[str, Any]:
    return {
        "name": "eth2-quickstart-mcp",
        "repo_root": str(resolve_repo_root()),
        "wrapper": str(eth2qs_path()),
        "tools": list_tools(),
    }


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


def stats() -> Dict[str, Any]:
    return _eth2qs("stats")


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


def list_tools() -> List[Dict[str, Any]]:
    return [
        {
            "name": "eth2qs_help",
            "description": "Show the canonical eth2-quickstart wrapper help.",
            "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
        },
        {
            "name": "eth2qs_doctor_json",
            "description": "Run doctor --json for machine-readable node health and drift detection.",
            "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
        },
        {
            "name": "eth2qs_plan_json",
            "description": "Detect the next safe install step. Optional chain override: ethereum or monad.",
            "inputSchema": {
                "type": "object",
                "properties": {"chain": {"type": "string", "enum": ["ethereum", "monad"]}},
                "additionalProperties": False,
            },
        },
        {
            "name": "eth2qs_ensure_preview",
            "description": "Preview the next safe install step without changing the host.",
            "inputSchema": {
                "type": "object",
                "properties": {"chain": {"type": "string", "enum": ["ethereum", "monad"]}},
                "additionalProperties": False,
            },
        },
        {
            "name": "eth2qs_ensure_apply",
            "description": "Execute the next safe install step. Requires confirm=true and confirmation_token='apply'.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "chain": {"type": "string", "enum": ["ethereum", "monad"]},
                    "confirm": {"type": "boolean"},
                    "confirmation_token": {"type": "string"},
                },
                "required": ["confirm", "confirmation_token"],
                "additionalProperties": False,
            },
        },
        {
            "name": "eth2qs_stats",
            "description": "Show read-only service and system stats.",
            "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
        },
        {
            "name": "eth2qs_logs",
            "description": "Show bounded wrapper logs for run1 or run2.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "target": {"type": "string", "enum": ["run1", "run2"], "default": "run2"},
                    "lines": {"type": "integer", "minimum": 1, "maximum": 500, "default": 200},
                },
                "additionalProperties": False,
            },
        },
        {
            "name": "eth2qs_start",
            "description": "Start services. Requires confirm=true and confirmation_token='apply'.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "confirm": {"type": "boolean"},
                    "confirmation_token": {"type": "string"},
                },
                "required": ["confirm", "confirmation_token"],
                "additionalProperties": False,
            },
        },
        {
            "name": "eth2qs_stop",
            "description": "Stop services. Requires confirm=true and confirmation_token='apply'.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "confirm": {"type": "boolean"},
                    "confirmation_token": {"type": "string"},
                },
                "required": ["confirm", "confirmation_token"],
                "additionalProperties": False,
            },
        },
        {
            "name": "eth2qs_restart",
            "description": "Restart services. Requires confirm=true and confirmation_token='apply'.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "confirm": {"type": "boolean"},
                    "confirmation_token": {"type": "string"},
                },
                "required": ["confirm", "confirmation_token"],
                "additionalProperties": False,
            },
        },
        {
            "name": "eth2qs_clean_data_dry_run",
            "description": "Preview safe cleanup of default node data directories while preserving secrets.",
            "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
        },
        {
            "name": "eth2qs_cleanup_host_dry_run",
            "description": "Preview host-level cleanup for stale root-managed installs while preserving secrets and network keys.",
            "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
        },
        {
            "name": "eth2qs_monad_install",
            "description": "Run the explicit Monad install path. Requires confirm=true and confirmation_token='apply'.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "confirm": {"type": "boolean"},
                    "confirmation_token": {"type": "string"},
                },
                "required": ["confirm", "confirmation_token"],
                "additionalProperties": False,
            },
        },
    ]


def call_tool(name: str, arguments: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    arguments = arguments or {}
    mapping = {
        "eth2qs_help": lambda args: help_tool(),
        "eth2qs_doctor_json": lambda args: doctor_json(),
        "eth2qs_plan_json": lambda args: plan_json(chain=args.get("chain")),
        "eth2qs_ensure_preview": lambda args: ensure_preview(chain=args.get("chain")),
        "eth2qs_ensure_apply": lambda args: ensure_apply(
            chain=args.get("chain"),
            confirm=bool(args.get("confirm")),
            confirmation_token=str(args.get("confirmation_token", "")),
        ),
        "eth2qs_stats": lambda args: stats(),
        "eth2qs_logs": lambda args: logs(
            target=str(args.get("target", "run2")),
            lines=int(args.get("lines", 200)),
        ),
        "eth2qs_start": lambda args: start(
            confirm=bool(args.get("confirm")),
            confirmation_token=str(args.get("confirmation_token", "")),
        ),
        "eth2qs_stop": lambda args: stop(
            confirm=bool(args.get("confirm")),
            confirmation_token=str(args.get("confirmation_token", "")),
        ),
        "eth2qs_restart": lambda args: restart(
            confirm=bool(args.get("confirm")),
            confirmation_token=str(args.get("confirmation_token", "")),
        ),
        "eth2qs_clean_data_dry_run": lambda args: clean_data_dry_run(),
        "eth2qs_cleanup_host_dry_run": lambda args: cleanup_host_dry_run(),
        "eth2qs_monad_install": lambda args: monad_install(
            confirm=bool(args.get("confirm")),
            confirmation_token=str(args.get("confirmation_token", "")),
        ),
    }
    if name not in mapping:
        raise ValueError(f"Unknown tool: {name}")
    return mapping[name](arguments)


__all__ = [
    "call_tool",
    "clean_data_dry_run",
    "cleanup_host_dry_run",
    "CONFIRM_TOKEN",
    "doctor_json",
    "ensure_apply",
    "ensure_preview",
    "help_tool",
    "list_tools",
    "logs",
    "monad_install",
    "plan_json",
    "resolve_repo_root",
    "restart",
    "server_info",
    "start",
    "stats",
    "stop",
]
