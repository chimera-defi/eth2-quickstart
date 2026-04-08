#!/usr/bin/env python3
"""Machine-readable monitoring and triage summary for eth2-quickstart."""

from __future__ import annotations

import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[2]
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
READ_ONLY_COMMAND = "./scripts/eth2qs.sh doctor --json"


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


def find_prysm_binary(component: str) -> Path | None:
    prysm_dist = Path.home() / "prysm" / "dist"
    if not prysm_dist.is_dir():
        return None
    candidates = sorted(
        path for path in prysm_dist.iterdir() if component in path.name and path.is_file() and path.stat().st_mode & 0o111
    )
    return candidates[-1] if candidates else None


def version_or_unavailable(command: list[str], *, default: str = "unavailable") -> str:
    completed = run(command)
    return completed.stdout.strip() or default if completed.returncode == 0 else default


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


def recent_errors(service: str) -> dict[str, object] | None:
    completed = run(["journalctl", "-u", service, "-n", "200", "--no-pager"])
    if completed.returncode != 0:
        return None
    matches = [line.strip() for line in completed.stdout.splitlines() if "error" in line.lower()]
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


def parse_json_command(command: list[str]) -> dict[str, Any] | None:
    completed = run(command, cwd=ROOT_DIR)
    if not completed.stdout.strip():
        return None
    try:
        return json.loads(completed.stdout)
    except json.JSONDecodeError:
        return None


def add_issue(
    issues: list[dict[str, object]],
    repair_preview: list[dict[str, object]],
    *,
    kind: str,
    severity: str,
    summary: str,
    suggested_action: str,
    service: str | None = None,
    safe: bool = False,
    command: str | None = None,
    evidence: str | None = None,
) -> None:
    issue = {
        "kind": kind,
        "severity": severity,
        "summary": summary,
        "suggested_action": suggested_action,
    }
    if service:
        issue["service"] = service
    if evidence:
        issue["evidence"] = evidence
    issues.append(issue)
    if command:
        preview = {"action": kind, "safe": safe, "command": command}
        if service:
            preview["service"] = service
        if preview not in repair_preview:
            repair_preview.append(preview)


def planner_follow_up(plan: dict[str, Any] | None) -> tuple[str | None, str | None]:
    if not plan:
        return None, None

    next_action = str(plan.get("next_action", ""))
    if next_action == "phase1":
        return "./scripts/eth2qs.sh phase1", "Run phase 1 system hardening before expecting core services"
    if next_action == "phase2":
        return "./scripts/eth2qs.sh phase2", "Run phase 2 install/config after phase 1 completes"
    if next_action == "monad_install":
        return "./scripts/eth2qs.sh monad-install", "Complete the Monad install before expecting services"
    if next_action == "relogin":
        return None, "Log in as the operator user before continuing with install steps"
    if next_action == "review":
        return READ_ONLY_COMMAND, "Review doctor/stats/logs before making changes"
    return None, None


def matches_any(sample: str, patterns: tuple[str, ...]) -> bool:
    return any(pattern in sample for pattern in patterns)


def classify_error_sample(
    item: dict[str, object],
    repair_preview: list[dict[str, object]],
    issues: list[dict[str, object]],
) -> bool:
    sample = str(item["sample"]).lower()
    service = str(item["service"])
    evidence = str(item["sample"])

    if matches_any(sample, ("connect: connection refused",)) and "18550" in sample:
        add_issue(
            issues,
            repair_preview,
            kind="mev_endpoint_unreachable",
            severity="warn",
            service=service,
            summary="Consensus client cannot reach the builder/MEV endpoint",
            suggested_action="Check MEV service health and restart the active MEV stack if needed",
            safe=True,
            command="./scripts/eth2qs.sh restart",
            evidence=evidence,
        )
        return True

    if "address already in use" in sample:
        add_issue(
            issues,
            repair_preview,
            kind="port_conflict",
            severity="fail",
            service=service,
            summary="A required port is already in use",
            suggested_action="Inspect the conflicting listener before restarting services",
            safe=True,
            command=f"journalctl -u {service} -n 50 --no-pager",
            evidence=evidence,
        )
        return True

    if matches_any(
        sample,
        (
            "peer database: resource temporarily unavailable",
            "could not open node's peer database",
        ),
    ):
        add_issue(
            issues,
            repair_preview,
            kind="db_lock_or_dual_process",
            severity="warn",
            service=service,
            summary="Client appears to have a locked database or duplicate process",
            suggested_action="Stop duplicate processes and inspect the service journal before restart",
            safe=True,
            command=f"journalctl -u {service} -n 50 --no-pager",
            evidence=evidence,
        )
        return True

    if matches_any(
        sample,
        (
            "wallet is not ready",
            "no wallet found",
            "could not create validator runner",
        ),
    ):
        add_issue(
            issues,
            repair_preview,
            kind="validator_wallet_missing",
            severity="fail",
            service=service,
            summary="Validator service cannot start because the wallet or keys are missing",
            suggested_action="Create/import the validator wallet or point the service at the correct wallet directory",
            safe=True,
            command=f"journalctl -u {service} -n 50 --no-pager",
            evidence=evidence,
        )
        return True

    if matches_any(
        sample,
        (
            "unexpected argument",
            "unknown argument",
            "unrecognized option",
        ),
    ):
        add_issue(
            issues,
            repair_preview,
            kind="service_flag_mismatch",
            severity="fail",
            service=service,
            summary="Service unit arguments do not match the installed binary",
            suggested_action="Review the unit/config against the installed version before restarting or updating",
            safe=False,
            command="./scripts/eth2qs.sh update-all --git-only --backup",
            evidence=evidence,
        )
        return True

    if matches_any(sample, ("toml parse error", "yaml: unmarshal errors", "invalid configuration")):
        add_issue(
            issues,
            repair_preview,
            kind="config_parse_error",
            severity="fail",
            service=service,
            summary="A service configuration file cannot be parsed",
            suggested_action="Fix the generated config syntax before attempting another restart",
            safe=True,
            command=f"journalctl -u {service} -n 50 --no-pager",
            evidence=evidence,
        )
        return True

    if matches_any(
        sample,
        (
            "failed to find and dial peers",
            "no peers found",
            "dial peers",
        ),
    ):
        add_issue(
            issues,
            repair_preview,
            kind="peer_connectivity_degraded",
            severity="warn",
            service=service,
            summary="Consensus networking is degraded and peers are not being maintained",
            suggested_action="Inspect networking, peer configuration, and sync reachability before restart",
            safe=True,
            command=f"journalctl -u {service} -n 50 --no-pager",
            evidence=evidence,
        )
        return True

    count = int(item.get("count", 0))
    if count >= 3:
        add_issue(
            issues,
            repair_preview,
            kind="recent_errors_detected",
            severity="warn" if service in CORE_SERVICES else "info",
            service=service,
            summary=f"Recent error logs detected for {service}",
            suggested_action="Inspect the journal before restarting or updating this service",
            safe=True,
            command=f"journalctl -u {service} -n 50 --no-pager",
            evidence=evidence,
        )
        return True

    return False


def classify_issues(
    service_states: dict[str, str],
    error_summary: list[dict[str, object]],
    doctor: dict[str, Any] | None,
    plan: dict[str, Any] | None,
    repo: dict[str, Any] | None,
) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    issues: list[dict[str, object]] = []
    repair_preview: list[dict[str, object]] = []
    plan_state = str(plan.get("state", "")) if plan else ""
    planner_command, planner_hint = planner_follow_up(plan)

    for service, status in service_states.items():
        if service in CORE_SERVICES and status in {"failed", "stopped"}:
            add_issue(
                issues,
                repair_preview,
                kind="restart_service",
                severity="fail",
                service=service,
                summary=f"{service} is installed but not running",
                suggested_action=f"Restart {service} and inspect logs if it fails again",
                safe=True,
                command=f"sudo systemctl restart {service}",
            )
        elif service in CORE_SERVICES and status == "disabled":
            add_issue(
                issues,
                repair_preview,
                kind="core_service_disabled",
                severity="warn" if plan_state == "installed" else "info",
                service=service,
                summary=f"{service} is installed but disabled",
                suggested_action=planner_hint or "Enable/restart the service only after confirming the host is fully configured",
                safe=False,
                command=None if planner_command else f"sudo systemctl restart {service}",
            )
        elif service in CORE_SERVICES and status == "not_installed":
            add_issue(
                issues,
                repair_preview,
                kind="core_service_missing",
                severity="info" if plan_state.startswith("needs_") else "fail",
                service=service,
                summary=f"{service} is not installed",
                suggested_action=planner_hint or "Use the planner/ensure path to complete installation",
                safe=False,
                command=planner_command or "./scripts/eth2qs.sh ensure",
            )

    if plan and plan_state not in {"", "installed"}:
        add_issue(
            issues,
            repair_preview,
            kind="planner_state",
            severity="warn",
            summary=f"Planner reports host state: {plan_state}",
            suggested_action=planner_hint or str(plan.get("reason", "Review planner output before modifying services")),
            safe=False,
            command=planner_command,
        )

    for item in error_summary:
        classify_error_sample(item, repair_preview, issues)

    if doctor:
        summary = doctor.get("summary", {})
        status = str(summary.get("status", ""))
        if status in {"warn", "fail"}:
            add_issue(
                issues,
                repair_preview,
                kind="doctor_summary",
                severity=status,
                summary=f"Doctor reports overall status: {status}",
                suggested_action="Review doctor output before attempting restarts or updates",
                safe=True,
                command=READ_ONLY_COMMAND,
            )
        for check in doctor.get("checks", []):
            name = str(check.get("name", ""))
            details = str(check.get("details", ""))
            if name.startswith("JWT secret:") and ("missing" in name.lower() or "not found" in details.lower()):
                add_issue(
                    issues,
                    repair_preview,
                    kind="jwt_missing",
                    severity="fail",
                    summary="JWT secret is missing",
                    suggested_action="Restore or recreate the JWT secret before starting execution/consensus services",
                    safe=True,
                    command=READ_ONLY_COMMAND,
                )
                break

    if repo and isinstance(repo.get("behind"), int) and repo["behind"] > 0:
        add_issue(
            issues,
            repair_preview,
            kind="repo_updates_available",
            severity="info",
            summary=f"Local checkout is behind {repo['upstream']} by {repo['behind']} commit(s)",
            suggested_action="Review and apply the latest repo updates",
            safe=False,
            command="./scripts/eth2qs.sh update-all --git-only --backup",
        )

    return issues, repair_preview


def overall_status(issues: list[dict[str, object]]) -> str:
    severities = {issue["severity"] for issue in issues}
    if "fail" in severities:
        return "fail"
    if "warn" in severities:
        return "warn"
    return "pass"


def main() -> None:
    service_states = {service: service_status(service) for service in SERVICES}
    errors = [item for item in (recent_errors(service) for service in SERVICES) if item]
    versions = get_versions()
    doctor = parse_json_command(["bash", str(ROOT_DIR / "install/utils/doctor.sh"), "--json"])
    plan = parse_json_command(["bash", str(ROOT_DIR / "install/utils/plan.sh"), "--json"])
    repo = repo_status()
    issues, repair_preview = classify_issues(service_states, errors, doctor, plan, repo)

    summary = {
        "status": overall_status(issues),
        "services_total": len(service_states),
        "services_running": sum(1 for state in service_states.values() if state == "running"),
        "services_failed": sum(1 for state in service_states.values() if state == "failed"),
        "services_stopped": sum(1 for state in service_states.values() if state == "stopped"),
        "services_disabled": sum(1 for state in service_states.values() if state == "disabled"),
        "services_not_installed": sum(1 for state in service_states.values() if state == "not_installed"),
        "issues_detected": len(issues),
    }

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "summary": summary,
        "service_states": service_states,
        "versions": versions,
        "recent_errors": errors,
        "recent_time_till_duty": duty_lines(),
        "issues": issues,
        "repair_preview": repair_preview,
        "doctor_summary": doctor.get("summary") if doctor else None,
        "plan": plan,
        "repo_status": repo,
    }
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
