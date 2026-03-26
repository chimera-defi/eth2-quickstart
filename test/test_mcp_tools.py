#!/usr/bin/env python3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from mcp_server import eth2qs_mcp_tools as tools


class McpToolsTest(unittest.TestCase):
    def test_tool_names_contain_expected_contract(self):
        self.assertIn("eth2qs_doctor_json", tools.TOOL_NAMES)
        self.assertIn("eth2qs_ensure_apply", tools.TOOL_NAMES)
        self.assertIn("eth2qs_phase1", tools.TOOL_NAMES)
        self.assertIn("eth2qs_phase2", tools.TOOL_NAMES)
        self.assertIn("eth2qs_cleanup_host_dry_run", tools.TOOL_NAMES)

    def test_confirm_gate_blocks_mutations(self):
        with self.assertRaises(ValueError):
            tools.ensure_apply(confirm=False, confirmation_token="")
        with self.assertRaises(ValueError):
            tools.phase1(confirm=False, confirmation_token="")
        with self.assertRaises(ValueError):
            tools.phase2(confirm=False, confirmation_token="")
        with self.assertRaises(ValueError):
            tools.stop(confirm=True, confirmation_token="wrong")

    def test_logs_rejects_out_of_range_lines(self):
        with self.assertRaises(ValueError):
            tools.logs(lines=0)
        with self.assertRaises(ValueError):
            tools.logs(lines=501)

    def test_phase2_rejects_unknown_client_values(self):
        with self.assertRaises(ValueError):
            tools.phase2(execution="unknown", confirm=True, confirmation_token="apply")
        with self.assertRaises(ValueError):
            tools.phase2(consensus="unknown", confirm=True, confirmation_token="apply")
        with self.assertRaises(ValueError):
            tools.phase2(mev="unknown", confirm=True, confirmation_token="apply")

    def test_call_tool_rejects_unknown_tool(self):
        with self.assertRaises(ValueError):
            tools.call_tool("missing_tool")

    def test_call_tool_dispatches_to_wrapper(self):
        fake = {
            "command": ["/repo/scripts/eth2qs.sh", "doctor", "--json"],
            "cwd": "/repo",
            "exit_code": 0,
            "stdout": "{}",
            "stderr": "",
            "ok": True,
        }
        with patch("mcp_server.eth2qs_mcp_tools._run", return_value=fake) as run_mock:
            result = tools.call_tool("eth2qs_doctor_json")
        self.assertEqual(result["stdout"], "{}")
        run_mock.assert_called_once()

    def test_phase2_maps_client_flags(self):
        fake = {
            "command": [],
            "cwd": "/repo",
            "exit_code": 0,
            "stdout": "",
            "stderr": "",
            "ok": True,
        }
        with patch("mcp_server.eth2qs_mcp_tools._run", return_value=fake) as run_mock:
            tools.phase2(
                execution="geth",
                consensus="prysm",
                mev="mev-boost",
                ethgas=False,
                confirm=True,
                confirmation_token="apply",
            )
        called = run_mock.call_args[0][0]
        self.assertIn("phase2", called)
        self.assertIn("--execution=geth", called)
        self.assertIn("--consensus=prysm", called)
        self.assertIn("--mev=mev-boost", called)

    def test_repo_root_env_override_is_honored(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            repo = Path(tmpdir)
            with patch.dict("os.environ", {"REPO_ROOT": str(repo)}, clear=False):
                self.assertEqual(tools.resolve_repo_root(), repo.resolve())


if __name__ == "__main__":
    unittest.main()
