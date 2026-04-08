# Outputs

## Canonical Machine-Readable Check

Use:

```bash
./scripts/eth2qs.sh doctor --json
./scripts/eth2qs.sh stats --json
```

These are the canonical machine-readable health and monitoring paths for agents.

## Expected Uses

- Confirm whether a host is ready for node install or is missing obvious prerequisites
- Validate installation status after bootstrap or phase execution
- Check service health before and after updates
- Inspect JWT-secret presence and general node readiness
- Detect service-unit drift when the running binary no longer matches the unit file on disk

## Human-Oriented Checks

- `./scripts/eth2qs.sh status`
- `./scripts/eth2qs.sh logs --run1 -n 100`
- `./scripts/eth2qs.sh logs --run2 -n 200`

Use `doctor --json` for health gates and `stats --json` for service states, issue detection, and repair previews. `./scripts/eth2qs.sh repair` consumes the same repair preview data but only auto-applies allowlisted safe restart actions. Use the human-readable output and logs when doing RCA.

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
