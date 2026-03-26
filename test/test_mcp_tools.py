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
        self.assertIn("eth2qs_client_options", tools.TOOL_NAMES)
        self.assertIn("eth2qs_phase1", tools.TOOL_NAMES)
        self.assertIn("eth2qs_phase2", tools.TOOL_NAMES)
        self.assertIn("eth2qs_cleanup_host_dry_run", tools.TOOL_NAMES)

    def test_server_info_includes_groups_and_examples(self):
        info = tools.server_info()
        self.assertIn("tool_groups", info)
        self.assertIn("call_examples", info)
        self.assertIn("eth2qs_phase2", info["tool_groups"]["mutating_confirm_required"])
        self.assertIn("eth2qs_client_options", info["tool_groups"]["read_only"])
        self.assertEqual(info["call_examples"]["eth2qs_phase1"]["confirmation_token"], "apply")

    def test_client_options_lists_valid_choices(self):
        options = tools.client_options()
        self.assertIn("geth", options["execution_clients"])
        self.assertIn("prysm", options["consensus_clients"])
        self.assertIn("mev-boost", options["mev_options"])
        self.assertEqual(options["ethgas_requires"]["mev"], "commit-boost")

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

    def test_doctor_json_dispatches_to_wrapper(self):
        fake = {
            "command": ["/repo/scripts/eth2qs.sh", "doctor", "--json"],
            "cwd": "/repo",
            "exit_code": 0,
            "stdout": "{}",
            "stderr": "",
            "ok": True,
        }
        with patch("mcp_server.eth2qs_mcp_tools._run", return_value=fake) as run_mock:
            result = tools.doctor_json()
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
