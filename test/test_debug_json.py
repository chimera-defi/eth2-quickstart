#!/usr/bin/env python3
import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT_DIR = Path(__file__).resolve().parent.parent
MODULE_PATH = ROOT_DIR / "install" / "utils" / "debug_json.py"
SPEC = importlib.util.spec_from_file_location("debug_json", MODULE_PATH)
debug_json = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(debug_json)


class DebugJsonTest(unittest.TestCase):
    def test_build_payload_filters_requested_service(self):
        fake_stats = {
            "summary": {"status": "warn", "issues_detected": 2},
            "doctor_summary": {"status": "warn"},
            "repo_status": {"upstream": "origin/master", "ahead": 0, "behind": 1},
            "issues": [{"kind": "planner_state", "severity": "warn", "summary": "needs phase1"}],
            "service_states": {"cl": "running", "validator": "stopped"},
        }
        with (
            patch.object(debug_json.stats_json, "build_payload", return_value=fake_stats),
            patch.object(
                debug_json,
                "systemctl_show",
                return_value={
                    "LoadState": "loaded",
                    "UnitFileState": "enabled",
                    "ActiveState": "active",
                    "SubState": "running",
                    "FragmentPath": "/etc/systemd/system/cl.service",
                    "ExecStart": "/usr/bin/cl",
                    "ExecMainPID": "4242",
                },
            ),
            patch.object(debug_json, "recent_errors", return_value={"service": "cl", "count": 2, "sample": "sample error"}),
            patch.object(debug_json, "listening_ports", return_value=[{"local_address": "127.0.0.1:5052", "peer_address": "*", "raw": "raw"}]),
            patch.object(debug_json, "journal_lines", return_value=["line1", "line2"]),
        ):
            payload = debug_json.build_payload(requested_services=["cl"], log_lines=10)

        self.assertEqual(payload["summary"]["services_examined"], 1)
        self.assertEqual(payload["services"][0]["service"], "cl")
        self.assertEqual(payload["services"][0]["unit"]["main_pid"], 4242)
        self.assertEqual(payload["services"][0]["listen_sockets"][0]["local_address"], "127.0.0.1:5052")


if __name__ == "__main__":
    unittest.main()
