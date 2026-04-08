#!/usr/bin/env python3
import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT_DIR = Path(__file__).resolve().parent.parent
MODULE_PATH = ROOT_DIR / "install" / "utils" / "update_check.py"
SPEC = importlib.util.spec_from_file_location("update_check", MODULE_PATH)
update_check = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(update_check)


class UpdateCheckTest(unittest.TestCase):
    def test_component_checks_flag_outdated_versions(self):
        with (
            patch.object(update_check, "current_geth_version", return_value=("Version: 1.13.0", "1.13.0")),
            patch.object(update_check, "current_mev_boost_version", return_value=("mev-boost 1.8.0", "1.8.0")),
            patch.object(update_check, "current_prysm_version", return_value=("Prysm 5.0.0", "5.0.0")),
            patch.object(
                update_check,
                "latest_release_tag",
                side_effect=lambda repo: {
                    "ethereum/go-ethereum": "v1.13.2",
                    "flashbots/mev-boost": "v1.8.0",
                    "prysmaticlabs/prysm": "v5.0.1",
                }.get(repo),
            ),
        ):
            checks = update_check.component_checks()

        relations = {item["component"]: item["relation"] for item in checks}
        self.assertEqual(relations["geth"], "outdated")
        self.assertEqual(relations["mev_boost"], "current")
        self.assertEqual(relations["prysm"], "outdated")

    def test_build_payload_includes_repo_behind_warning(self):
        fake_checks = [
            {
                "component": "geth",
                "repo": "ethereum/go-ethereum",
                "current_raw": "Version: 1.13.0",
                "current_version": "1.13.0",
                "latest_tag": "v1.13.2",
                "latest_version": "1.13.2",
                "relation": "outdated",
                "status": "warn",
                "summary": "geth is behind the latest known release",
            }
        ]
        with (
            patch.object(update_check, "component_checks", return_value=fake_checks),
            patch.object(update_check, "repo_status", return_value={"upstream": "origin/master", "ahead": 0, "behind": 3}),
        ):
            payload = update_check.build_payload()

        self.assertEqual(payload["summary"]["status"], "warn")
        self.assertEqual(payload["summary"]["outdated_components"], 1)
        self.assertEqual(payload["summary"]["repo_behind_commits"], 3)
        self.assertEqual(payload["checks"][0]["component"], "repo")


if __name__ == "__main__":
    unittest.main()
