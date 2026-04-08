#!/usr/bin/env python3
import json
import subprocess
import unittest
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent
WRAPPER = ROOT_DIR / "scripts" / "eth2qs.sh"
CONTRACTS_DIR = ROOT_DIR / "test" / "contracts"


def load_schema(name: str) -> dict:
    return json.loads((CONTRACTS_DIR / name).read_text(encoding="utf-8"))


def assert_matches_schema(case: unittest.TestCase, value, schema: dict, path: str = "$") -> None:
    expected_type = schema.get("type")
    if expected_type is not None:
        allowed = expected_type if isinstance(expected_type, list) else [expected_type]
        type_map = {
            "array": list,
            "boolean": bool,
            "integer": int,
            "null": type(None),
            "object": dict,
            "string": str,
        }
        if not any(isinstance(value, type_map[name]) for name in allowed):
            case.fail(f"{path} expected type {allowed}, got {type(value).__name__}")

    if "enum" in schema and value not in schema["enum"]:
        case.fail(f"{path} expected one of {schema['enum']}, got {value!r}")

    if "required" in schema:
        for key in schema["required"]:
            case.assertIn(key, value, msg=f"{path} missing required key {key!r}")

    if isinstance(value, dict):
        for key, subschema in schema.get("properties", {}).items():
            if key in value:
                assert_matches_schema(case, value[key], subschema, f"{path}.{key}")

    if isinstance(value, list):
        min_items = schema.get("minItems")
        if min_items is not None and len(value) < min_items:
            case.fail(f"{path} expected at least {min_items} items, got {len(value)}")
        item_schema = schema.get("items")
        if item_schema is not None:
            for index, item in enumerate(value):
                assert_matches_schema(case, item, item_schema, f"{path}[{index}]")


class WrapperContractTest(unittest.TestCase):
    def run_wrapper_json(self, *args: str, allow_nonzero: bool = False) -> dict:
        completed = subprocess.run(
            [str(WRAPPER), *args],
            cwd=str(ROOT_DIR),
            text=True,
            capture_output=True,
            check=False,
        )
        if not allow_nonzero:
            self.assertEqual(completed.returncode, 0, msg=completed.stderr)
        self.assertTrue(completed.stdout.strip(), msg=completed.stderr)
        return json.loads(completed.stdout)

    def assert_contract(self, schema_name: str, *args: str, allow_nonzero: bool = False) -> dict:
        payload = self.run_wrapper_json(*args, allow_nonzero=allow_nonzero)
        assert_matches_schema(self, payload, load_schema(schema_name))
        return payload

    def test_client_options_json_contract(self):
        payload = self.assert_contract("client_options.schema.json", "client-options", "--json")
        self.assertIn("mainnet", payload["networks"])

    def test_doctor_json_contract(self):
        payload = self.assert_contract("doctor.schema.json", "doctor", "--json", allow_nonzero=True)
        self.assertIn(payload["summary"]["status"], {"pass", "warn", "fail"})

    def test_plan_json_contract(self):
        payload = self.assert_contract("plan.schema.json", "plan", "--json")
        self.assertIn("service_states", payload)

    def test_phase2_preview_json_contract(self):
        payload = self.assert_contract(
            "phase2_preview.schema.json",
            "phase2-preview",
            "--network=holesky",
            "--execution=geth",
            "--consensus=prysm",
            "--mev=commit-boost",
            "--ethgas",
            "--skip-deps",
            "--json",
        )
        self.assertEqual(payload["config_updates"]["ETHGAS_NETWORK"], "holesky")
        self.assertIn("--skip-deps", payload["run_2_command"])


if __name__ == "__main__":
    unittest.main()
