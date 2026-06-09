#!/usr/bin/env python3
"""Filter a beacon-node validators payload by balance, withdrawal type, status.

Reads a JSON object {"data": [ <validator entry>, ... ]} from a file argument
(or stdin if "-"), applies the filters, and writes the same shape to stdout.

Withdrawal type matches the prefix of validator.withdrawal_credentials:
  0x00 = BLS, 0x01 = execution address, 0x02 = compounding (EIP-7251).
Balances are compared in ETH (entry "balance" is gwei).

Used by validator_list.sh and covered by install/test/test_validator_filter.sh.
"""
import argparse
import json
import sys


def keep(v, min_b, max_b, wtype, status):
    bal = int(v.get("balance", 0)) / 1e9
    if min_b is not None and bal < min_b:
        return False
    if max_b is not None and bal > max_b:
        return False
    if wtype:
        cred = (v.get("validator", {}).get("withdrawal_credentials", "") or "").lower()
        if not cred.startswith(wtype):
            return False
    if status and status not in (v.get("status", "") or "").lower():
        return False
    return True


def main():
    p = argparse.ArgumentParser()
    p.add_argument("path", help="input JSON file, or - for stdin")
    p.add_argument("--min-balance", type=float, default=None)
    p.add_argument("--max-balance", type=float, default=None)
    p.add_argument("--withdrawal-type", default=None)
    p.add_argument("--status", default=None)
    args = p.parse_args()

    wtype = args.withdrawal_type.lower() if args.withdrawal_type else None
    if wtype and wtype not in ("0x00", "0x01", "0x02"):
        print("withdrawal-type must be 0x00, 0x01, or 0x02", file=sys.stderr)
        return 2
    status = args.status.lower() if args.status else None

    src = sys.stdin if args.path == "-" else open(args.path)
    with src as f:
        raw = json.load(f)

    raw["data"] = [
        v for v in raw.get("data", [])
        if keep(v, args.min_balance, args.max_balance, wtype, status)
    ]
    json.dump(raw, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
