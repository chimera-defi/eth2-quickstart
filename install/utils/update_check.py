#!/usr/bin/env python3
"""Machine-readable update freshness checks for repo and installed components."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any
from urllib.error import URLError
from urllib.request import Request, urlopen


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from monitor_common import (  # noqa: E402
    COMPONENT_REPOS,
    compare_versions,
    current_geth_version,
    current_mev_boost_version,
    current_prysm_version,
    extract_version,
    now_iso,
    repo_status,
)


FIXTURE_ENV = "ETH2QS_UPDATE_CHECK_FIXTURE"
RELEASE_FIXTURES_ENV = "ETH2QS_RELEASE_FIXTURES"


def latest_release_tag(repo: str) -> str | None:
    fixtures = os.environ.get(RELEASE_FIXTURES_ENV)
    if fixtures:
        try:
            payload = json.loads(fixtures)
            tag = payload.get(repo)
            if isinstance(tag, str):
                return tag
        except json.JSONDecodeError:
            return None

    request = Request(
        f"https://api.github.com/repos/{repo}/releases/latest",
        headers={"Accept": "application/vnd.github+json"},
    )
    try:
        with urlopen(request, timeout=8) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (OSError, URLError, TimeoutError, json.JSONDecodeError):
        return None
    tag = payload.get("tag_name")
    return tag if isinstance(tag, str) else None


def component_checks() -> list[dict[str, Any]]:
    getters = {
        "geth": current_geth_version,
        "mev_boost": current_mev_boost_version,
        "prysm": current_prysm_version,
    }
    checks: list[dict[str, Any]] = []
    for name, getter in getters.items():
        raw_current, current_version = getter()
        latest_tag = latest_release_tag(COMPONENT_REPOS[name])
        latest_version = extract_version(latest_tag or "")
        relation = compare_versions(current_version, latest_version)
        if raw_current == "not_installed":
            status = "info"
            summary = f"{name} is not installed"
        elif relation == "outdated":
            status = "warn"
            summary = f"{name} is behind the latest known release"
        elif relation == "current":
            status = "pass"
            summary = f"{name} matches the latest known release"
        elif relation == "ahead":
            status = "info"
            summary = f"{name} appears newer than the latest fetched release tag"
        else:
            status = "info"
            summary = f"{name} version could not be compared to an upstream release"

        checks.append(
            {
                "component": name,
                "repo": COMPONENT_REPOS[name],
                "current_raw": raw_current,
                "current_version": current_version,
                "latest_tag": latest_tag,
                "latest_version": latest_version,
                "relation": relation,
                "status": status,
                "summary": summary,
            }
        )
    return checks


def build_payload() -> dict[str, Any]:
    fixture = os.environ.get(FIXTURE_ENV)
    if fixture:
        return json.loads(fixture)

    repo = repo_status()
    checks = component_checks()
    if repo and isinstance(repo.get("behind"), int) and repo["behind"] > 0:
        checks.insert(
            0,
            {
                "component": "repo",
                "repo": str(repo["upstream"]),
                "current_raw": None,
                "current_version": None,
                "latest_tag": None,
                "latest_version": None,
                "relation": "behind",
                "status": "warn",
                "summary": f"Local checkout is behind {repo['upstream']} by {repo['behind']} commit(s)",
            },
        )

    statuses = {check["status"] for check in checks}
    if "warn" in statuses:
        status = "warn"
    elif "pass" in statuses:
        status = "pass"
    else:
        status = "info"

    return {
        "generated_at": now_iso(),
        "summary": {
            "status": status,
            "checks_total": len(checks),
            "outdated_components": sum(1 for check in checks if check["relation"] == "outdated"),
            "repo_behind_commits": repo.get("behind") if repo else None,
        },
        "repo_status": repo,
        "checks": checks,
    }


def print_human(payload: dict[str, Any]) -> None:
    print(f"Status: {payload['summary']['status']}")
    print(
        "Summary: "
        f"checks={payload['summary']['checks_total']} "
        f"outdated={payload['summary']['outdated_components']} "
        f"repo_behind={payload['summary']['repo_behind_commits']}"
    )
    for check in payload["checks"]:
        current = check["current_version"] or check["current_raw"] or "n/a"
        latest = check["latest_version"] or check["latest_tag"] or "n/a"
        print(f"- {check['component']}: {check['summary']} (current={current}, latest={latest})")


def main() -> None:
    if any(arg in {"-h", "--help"} for arg in sys.argv[1:]):
        print("Usage: ./install/utils/update_check.sh [--json]")
        print("  --json    Output machine-readable update freshness data")
        return
    payload = build_payload()
    if "--json" in sys.argv[1:]:
        print(json.dumps(payload, indent=2))
        return
    print_human(payload)


if __name__ == "__main__":
    main()
