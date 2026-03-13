# Outputs

## Canonical Machine-Readable Check

Use:

```bash
./scripts/eth2qs.sh doctor --json
```

This is the canonical machine-readable health path for agents.

## Expected Uses

- Validate installation status after bootstrap or phase execution
- Check service health before and after updates
- Inspect JWT-secret presence and general node readiness

## Human-Oriented Checks

- `./scripts/eth2qs.sh status`
- `./scripts/eth2qs.sh logs --run1 -n 100`
- `./scripts/eth2qs.sh logs --run2 -n 200`

Use the JSON output when another agent step needs stable parsing. Use the human-readable output and logs when doing RCA.
