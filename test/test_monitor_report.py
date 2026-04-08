#!/usr/bin/env python3
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT_DIR = Path(__file__).resolve().parent.parent
MODULE_PATH = ROOT_DIR / "install" / "utils" / "monitor_report.py"
SPEC = importlib.util.spec_from_file_location("monitor_report", MODULE_PATH)
monitor_report = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(monitor_report)


class MonitorReportTest(unittest.TestCase):
    def test_export_payload_combines_stats_and_update(self):
        payload = monitor_report.build_export_payload(
            stats_payload={
                "summary": {
                    "status": "warn",
                    "services_failed": 1,
                    "issues_detected": 3,
                },
                "issues": [
                    {"kind": "planner_state", "severity": "warn", "summary": "needs phase1"},
                    {"kind": "jwt_missing", "severity": "fail", "summary": "missing jwt"},
                ],
                "doctor_summary": {"status": "warn"},
                "repair_preview": [],
            },
            update_payload={
                "summary": {
                    "status": "warn",
                    "outdated_components": 2,
                    "repo_behind_commits": 4,
                },
                "checks": [
                    {"component": "repo", "status": "warn", "summary": "behind"},
                    {"component": "geth", "status": "warn", "summary": "outdated"},
                ],
            },
        )

        self.assertEqual(payload["summary"]["status"], "warn")
        self.assertEqual(payload["summary"]["services_failed"], 1)
        self.assertEqual(payload["summary"]["outdated_components"], 2)
        self.assertEqual(len(payload["top_issues"]), 2)
        self.assertEqual(len(payload["update_findings"]), 2)

    def test_snapshot_and_history_round_trip(self):
        fake_stats = json.dumps(
            {
                "summary": {"status": "pass", "services_failed": 0, "issues_detected": 0},
                "issues": [],
                "doctor_summary": {"status": "pass"},
                "repair_preview": [],
            }
        )
        fake_update = json.dumps(
            {
                "summary": {"status": "pass", "outdated_components": 0, "repo_behind_commits": 0},
                "checks": [],
            }
        )
        with tempfile.TemporaryDirectory() as tmpdir, patch.dict(
            os.environ,
            {
                monitor_report.MONITOR_DIR_ENV: tmpdir,
                monitor_report.MONITOR_STATS_FIXTURE_ENV: fake_stats,
                monitor_report.MONITOR_UPDATE_FIXTURE_ENV: fake_update,
            },
            clear=False,
        ):
            snapshot = monitor_report.write_snapshot()
            history = monitor_report.build_history_payload(limit=5)
            snapshot_exists = Path(snapshot["path"]).exists()

        self.assertTrue(snapshot_exists)
        self.assertEqual(history["summary"]["entries"], 1)
        self.assertEqual(history["entries"][0]["summary"]["status"], "pass")


if __name__ == "__main__":
    unittest.main()
