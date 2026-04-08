# Outputs

## Canonical Machine-Readable Check

Use:

```bash
./scripts/eth2qs.sh doctor --json
```

This is the canonical machine-readable health path for agents.

Other stable machine-readable surfaces:

```bash
./scripts/eth2qs.sh plan --json
./scripts/eth2qs.sh client-options --json
./scripts/eth2qs.sh phase2-preview --execution=geth --consensus=prysm --mev=mev-boost --json
```

## Expected Uses

- Confirm whether a host is ready for node install or is missing obvious prerequisites
- Validate installation status after bootstrap or phase execution
- Check service health before and after updates
- Inspect JWT-secret presence and general node readiness
- Detect service-unit drift when the running binary no longer matches the unit file on disk

## Human-Oriented Checks

- `./scripts/eth2qs.sh status`
- `./scripts/eth2qs.sh stats`
- `./scripts/eth2qs.sh logs --run1 -n 100`
- `./scripts/eth2qs.sh logs --run2 -n 200`

Use the JSON output when another agent step needs stable parsing. Use the human-readable output and logs when doing RCA. `stats` is still a human-oriented summary, not a stable JSON contract.

## `doctor --json` Output Shape

```json
{
  "summary": {
    "passed": 12,
    "warnings": 2,
    "failed": 0,
    "status": "warn"
  },
  "checks": [
    { "status": "pass", "name": "RAM: 32GB (recommended: 16GB+)", "details": "" },
    { "status": "warn", "name": "Execution client (eth1): Not installed", "details": "" },
    { "status": "fail", "name": "JWT secret: missing", "details": "/home/user/secrets/jwt.hex not found" }
  ]
}
```

`summary.status` values: `"pass"` (all checks pass), `"warn"` (at least one warning, no failures), `"fail"` (at least one failure).

Check `status` values per entry: `"pass"`, `"warn"`, `"fail"`.

Use `summary.status` for a quick gate check. Iterate `checks` to surface specific issues to the operator.
