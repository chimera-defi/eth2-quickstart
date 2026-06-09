#!/usr/bin/env python3
"""Stdio MCP server for eth2-quickstart.

Requires the official Python MCP SDK:
  python3 -m pip install mcp
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from mcp_server.eth2qs_mcp_tools import (  # noqa: E402
    clean_data_dry_run,
    cleanup_host_dry_run,
    client_options,
    debug_json,
    doctor_json,
    ensure_apply,
    ensure_preview,
    help_tool,
    logs,
    monitor_export_json,
    monitor_history_json,
    monad_install,
    phase1,
    phase2,
    plan_json,
    repair_apply,
    repair_preview,
    restart,
    server_info,
    start,
    stats,
    stats_json,
    stop,
    update_check_json,
    validators_list,
    validator_op_preview,
)

try:
    from mcp.server.fastmcp import FastMCP  # type: ignore
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "Missing Python MCP SDK. Install it with: python3 -m pip install mcp"
    ) from exc

mcp = FastMCP("eth2-quickstart")


@mcp.tool(name="eth2qs_info")
def eth2qs_info() -> dict:
    """Show repo and tool metadata for this MCP server."""
    return server_info()


@mcp.tool(name="eth2qs_help")
def eth2qs_help() -> dict:
    """Show wrapper help."""
    return help_tool()


@mcp.tool(name="eth2qs_doctor_json")
def eth2qs_doctor_json() -> dict:
    """Run doctor --json for machine-readable node health and drift detection."""
    return doctor_json()


@mcp.tool(name="eth2qs_plan_json")
def eth2qs_plan_json(chain: str | None = None) -> dict:
    """Detect the next safe install step. Optional chain override: ethereum or monad."""
    return plan_json(chain=chain)


@mcp.tool(name="eth2qs_ensure_preview")
def eth2qs_ensure_preview(chain: str | None = None) -> dict:
    """Preview the next safe install step without changing the host."""
    return ensure_preview(chain=chain)


@mcp.tool(name="eth2qs_ensure_apply")
def eth2qs_ensure_apply(chain: str | None = None, confirm: bool = False, confirmation_token: str = "") -> dict:
    """Execute the next safe install step. Requires confirm=true and confirmation_token='apply'."""
    return ensure_apply(chain=chain, confirm=confirm, confirmation_token=confirmation_token)


@mcp.tool(name="eth2qs_client_options")
def eth2qs_client_options() -> dict:
    """List valid Phase 2 execution/consensus/MEV choices and a few common tested presets."""
    return client_options()


@mcp.tool(name="eth2qs_phase1")
def eth2qs_phase1(confirm: bool = False, confirmation_token: str = "") -> dict:
    """Run Phase 1 hardening. Requires confirm=true and confirmation_token='apply'."""
    return phase1(confirm=confirm, confirmation_token=confirmation_token)


@mcp.tool(name="eth2qs_phase2")
def eth2qs_phase2(
    execution: str | None = None,
    consensus: str | None = None,
    mev: str | None = None,
    ethgas: bool = False,
    confirm: bool = False,
    confirmation_token: str = "",
) -> dict:
    """Run Phase 2 install. Supports execution/consensus/mev flags. Requires confirm=true and confirmation_token='apply'."""
    return phase2(
        execution=execution,
        consensus=consensus,
        mev=mev,
        ethgas=ethgas,
        confirm=confirm,
        confirmation_token=confirmation_token,
    )


@mcp.tool(name="eth2qs_stats")
def eth2qs_stats() -> dict:
    """Show read-only service and system stats."""
    return stats()


@mcp.tool(name="eth2qs_stats_json")
def eth2qs_stats_json() -> dict:
    """Show machine-readable monitoring, issue classification, and repair previews."""
    return stats_json()


@mcp.tool(name="eth2qs_update_check_json")
def eth2qs_update_check_json() -> dict:
    """Compare installed client versions and repo state to the latest known upstream releases."""
    return update_check_json()


@mcp.tool(name="eth2qs_debug_json")
def eth2qs_debug_json(service: str | None = None, lines: int = 40) -> dict:
    """Show structured per-service debug details, unit metadata, log tails, and sockets."""
    return debug_json(service=service, lines=lines)


@mcp.tool(name="eth2qs_monitor_export_json")
def eth2qs_monitor_export_json() -> dict:
    """Show a compact machine-readable monitor summary for bots, dashboards, or cron hooks."""
    return monitor_export_json()


@mcp.tool(name="eth2qs_monitor_history_json")
def eth2qs_monitor_history_json(limit: int = 5) -> dict:
    """Show recent monitor snapshot summaries and simple deltas."""
    return monitor_history_json(limit=limit)


@mcp.tool(name="eth2qs_repair_preview")
def eth2qs_repair_preview() -> dict:
    """Show allowlisted smart repair candidates derived from current monitoring output."""
    return repair_preview()


@mcp.tool(name="eth2qs_repair_apply")
def eth2qs_repair_apply(confirm: bool = False, confirmation_token: str = "") -> dict:
    """Apply allowlisted smart repair actions. Requires confirm=true and confirmation_token='apply'."""
    return repair_apply(confirm=confirm, confirmation_token=confirmation_token)


@mcp.tool(name="eth2qs_logs")
def eth2qs_logs(target: str = "run2", lines: int = 200) -> dict:
    """Show bounded wrapper logs for run1 or run2."""
    return logs(target=target, lines=lines)


@mcp.tool(name="eth2qs_start")
def eth2qs_start(confirm: bool = False, confirmation_token: str = "") -> dict:
    """Start services. Requires confirm=true and confirmation_token='apply'."""
    return start(confirm=confirm, confirmation_token=confirmation_token)


@mcp.tool(name="eth2qs_stop")
def eth2qs_stop(confirm: bool = False, confirmation_token: str = "") -> dict:
    """Stop services. Requires confirm=true and confirmation_token='apply'."""
    return stop(confirm=confirm, confirmation_token=confirmation_token)


@mcp.tool(name="eth2qs_restart")
def eth2qs_restart(confirm: bool = False, confirmation_token: str = "") -> dict:
    """Restart services. Requires confirm=true and confirmation_token='apply'."""
    return restart(confirm=confirm, confirmation_token=confirmation_token)


@mcp.tool(name="eth2qs_clean_data_dry_run")
def eth2qs_clean_data_dry_run() -> dict:
    """Preview safe cleanup of default node data directories while preserving secrets."""
    return clean_data_dry_run()


@mcp.tool(name="eth2qs_cleanup_host_dry_run")
def eth2qs_cleanup_host_dry_run() -> dict:
    """Preview host-level cleanup for stale root-managed installs while preserving secrets and network keys."""
    return cleanup_host_dry_run()


@mcp.tool(name="eth2qs_monad_install")
def eth2qs_monad_install(confirm: bool = False, confirmation_token: str = "") -> dict:
    """Run the explicit Monad install path. Requires confirm=true and confirmation_token='apply'."""
    return monad_install(confirm=confirm, confirmation_token=confirmation_token)


@mcp.tool(name="eth2qs_validators")
def eth2qs_validators(
    min_balance: float | None = None,
    max_balance: float | None = None,
    withdrawal_type: str | None = None,
    status: str | None = None,
) -> dict:
    """Read-only: list local validators with index/status/balance/withdrawal
    credentials. Optional filters: min_balance/max_balance (ETH),
    withdrawal_type (0x00 BLS / 0x01 execution / 0x02 compounding), status substring."""
    return validators_list(
        min_balance=min_balance,
        max_balance=max_balance,
        withdrawal_type=withdrawal_type,
        status=status,
    )


@mcp.tool(name="eth2qs_validator_op_preview")
def eth2qs_validator_op_preview(operation: str) -> dict:
    """Read-only: return the exact node CLI command for a funds-affecting validator
    operation (exit, withdrawal-change, consolidate, eip7002-exit, create-0x02,
    deploy). These are NOT executed via MCP (irreversible, need secrets); run the
    returned command on the node CLI where it prompts for confirmation."""
    return validator_op_preview(operation=operation)


if __name__ == "__main__":  # pragma: no cover
    # Keep explicit stdio transport for Claude Code / Codex MCP use.
    mcp.run(transport="stdio")
