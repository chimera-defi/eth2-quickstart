# Example Requests

Use these examples when an agent or user needs a concrete starting prompt.

## Bootstrap A Fresh Host

```text
Use the eth2-quickstart skill to bootstrap this Ubuntu host for an Ethereum node. Choose a sensible default client stack, keep the flow non-interactive where possible, and stop before any destructive step that needs my confirmation.
```

## Resume After Reboot

```text
Use the eth2-quickstart skill to resume node installation after the Phase 1 reboot boundary. Prefer explicit client flags and verify health with doctor --json when done.
```

## Check Node Health

```text
Use the eth2-quickstart skill to inspect this node. Show me the doctor --json result, explain any failing checks, and use logs only if needed for RCA.
```

## Safe Cleanup

```text
Use the eth2-quickstart skill to show me what default node data cleanup would remove on this host. Start with a dry-run and do not remove secrets, wallets, or validator keys.
```

## Routine Operations

```text
Use the eth2-quickstart skill to stop this node cleanly, show me its current service status, and tell me what would be needed to start it again.
```
