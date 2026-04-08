#!/usr/bin/env python3
import importlib.util
import unittest
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent
MODULE_PATH = ROOT_DIR / "install" / "utils" / "stats_json.py"
SPEC = importlib.util.spec_from_file_location("stats_json", MODULE_PATH)
stats_json = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(stats_json)


class StatsJsonClassificationTest(unittest.TestCase):
    def classify(self, *, service_states=None, error_summary=None, doctor=None, plan=None, repo=None):
        return stats_json.classify_issues(
            service_states or {},
            error_summary or [],
            doctor,
            plan,
            repo,
        )

    def test_validator_wallet_missing_is_flagged(self):
        issues, preview = self.classify(
            error_summary=[
                {
                    "service": "validator",
                    "count": 5,
                    "sample": "error=\"Wallet is not ready: no wallet found\"",
                }
            ]
        )
        self.assertTrue(any(issue["kind"] == "validator_wallet_missing" for issue in issues))
        self.assertTrue(any(item["service"] == "validator" for item in preview))

    def test_config_argument_and_parse_errors_are_flagged(self):
        issues, _ = self.classify(
            error_summary=[
                {
                    "service": "commit-boost-pbs",
                    "count": 7,
                    "sample": "error: unexpected argument '--config' found",
                },
                {
                    "service": "ethgas",
                    "count": 4,
                    "sample": "TOML parse error at line 4, column 1",
                },
            ]
        )
        kinds = {issue["kind"] for issue in issues}
        self.assertIn("service_flag_mismatch", kinds)
        self.assertIn("config_parse_error", kinds)

    def test_peer_and_mev_issues_get_targeted_restart_candidates(self):
        issues, preview = self.classify(
            service_states={"cl": "running", "commit-boost-pbs": "running"},
            error_summary=[
                {
                    "service": "cl",
                    "count": 3,
                    "sample": "Failed to find and dial peers",
                },
                {
                    "service": "cl",
                    "count": 2,
                    "sample": "connect: connection refused 127.0.0.1:18550",
                },
            ],
        )
        kinds = {issue["kind"] for issue in issues}
        commands = {item["command"] for item in preview}
        self.assertIn("peer_connectivity_degraded", kinds)
        self.assertIn("mev_endpoint_unreachable", kinds)
        self.assertIn("sudo systemctl restart cl", commands)
        self.assertIn("sudo systemctl restart commit-boost-pbs", commands)

    def test_planner_and_doctor_context_become_issues(self):
        issues, preview = self.classify(
            service_states={"eth1": "not_installed"},
            doctor={"summary": {"status": "warn"}},
            plan={"state": "needs_phase1", "next_action": "phase1"},
        )
        kinds = {issue["kind"] for issue in issues}
        self.assertIn("planner_state", kinds)
        self.assertIn("doctor_summary", kinds)
        self.assertIn("core_service_missing", kinds)
        self.assertTrue(any(item["command"] == "./scripts/eth2qs.sh phase1" for item in preview))

    def test_planner_warning_prevents_false_pass(self):
        issues, _ = self.classify(plan={"state": "needs_phase2", "next_action": "phase2"})
        self.assertTrue(any(issue["kind"] == "planner_state" and issue["severity"] == "warn" for issue in issues))
        self.assertEqual(stats_json.overall_status(issues), "warn")

    def test_overall_status_respects_fail_and_warn(self):
        self.assertEqual(stats_json.overall_status([{"severity": "info"}]), "pass")
        self.assertEqual(stats_json.overall_status([{"severity": "warn"}]), "warn")
        self.assertEqual(stats_json.overall_status([{"severity": "fail"}]), "fail")


if __name__ == "__main__":
    unittest.main()
