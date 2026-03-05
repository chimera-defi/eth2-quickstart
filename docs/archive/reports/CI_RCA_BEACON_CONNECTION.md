# Root Cause Analysis: Beacon REST API Connection Refused (CI E2E)

**Date:** 2025-02  
**Symptom:** `Beacon REST API not responding on :5052 (curl exit=7, http_code=000)` when creating dummy validator keys in Docker CI (besu + lighthouse + commit-boost matrix).

**Logs preserved:** All diagnostic improvements in `test/lib/e2e_dummy_validator_keys.sh` remain in place (curl exit interpretation, port 5052 check, cl/eth1 status, ExecStart, journal tail).

---

## Failure Chain

1. **run_2.sh** installs Execution (Besu) → Consensus (Lighthouse) → dummy keys → Commit-Boost
2. **Besu install** calls `enable_and_start_systemd_service "eth1"` — waits up to 60s for `systemctl is-active eth1`
3. **Lighthouse install** calls `enable_and_start_systemd_service "cl"` — cl has `After=eth1.service`
4. **create_dummy_validator_keys** waits for `cl` active (60s), then polls beacon REST on :5052 for 90s
5. **Result:** curl exit=7 (connection refused) — nothing listening on 5052

---

## Root Cause

**We treat "eth1.service active" as "Engine API ready" — but they are not the same.**

| Check | Meaning | When it becomes true |
|-------|---------|----------------------|
| `systemctl is-active eth1` | Besu *process* has started | JVM process spawned (seconds) |
| Engine API port 8551 listening | Besu *accepts* Engine API connections | JVM initialized, classes loaded, HTTP server bound (30–90+ seconds for Java) |

**Lighthouse startup sequence** (from upstream docs):

1. Parse config, build `ExecutionLayer` from `--execution-endpoint`
2. Call Engine API (`engine_exchangeCapabilities`, `engine_forkchoiceUpdatedV1`)
3. Only after execution connection succeeds does the beacon proceed
4. HTTP REST server (port 5052) starts as part of service initialization — but the beacon may block on step 2 first

**Conclusion:** If the execution client (Besu) has not yet opened port 8551 when the beacon starts, the beacon blocks waiting for the Engine API connection. The HTTP server on 5052 may not start until that connection is established. Our 60s wait for eth1 "active" only ensures the process is running — not that 8551 is accepting connections. Besu (Java) can take 30–90+ seconds to open the Engine API after process start.

---

## Evidence Supporting This RCA

1. **curl exit=7** = connection refused → nothing listening on 5052
2. **Port 5052 check** (from our diagnostics): `ss -tlnp | grep 5052` → "none" when failing
3. **cl.service active** can still be true — systemd reports active when the process is running, even if it is blocked in a retry loop
4. **Earlier logs** showed "Error during execution engine upcheck" and "HTTP server is disabled" — we fixed the latter with `--http`, but the former indicates the beacon was waiting on eth1
5. **Execution-before-consensus order** is correct; the gap is that we never wait for *port readiness*, only for *process start*

---

## Potential Fixes (Not Implemented — RCA Only)

1. **Increase beacon REST poll**  
   Extend the 90s poll in `create_dummy_validator_keys` — mitigates symptom but does not fix the underlying race.

2. **Systemd socket activation**  
   Use a socket unit for 8551 so systemd only starts the beacon when the socket is ready — more invasive.

3. **Pre-flight in consensus scripts**  
   Before `enable_and_start_systemd_service "cl"`, poll for Engine API readiness (port 8551) — now done centrally in run_2.sh via `wait_for_engine_api`.

---

## Fixes Applied (2025-02)

1. **Removed --http grep verification**: The check was a false positive (ExecStart has --http; grep failed in CI). We control the template in lighthouse.sh — no runtime verification needed.
2. **run_install_script trap**: Use global `_run_install_log_file` so `trap 'rm -f "$_run_install_log_file"' RETURN` works with single quotes (SC2064 compliant). Local vars are out of scope when RETURN trap runs; global avoids unbound variable with `set -u`.
3. **Engine API readiness** (fix for erigon+teku cl failure): Added `wait_for_engine_api` in `lib/common_functions.sh`. `run_2.sh` now waits for port 8551 to be listening (up to 90s) before installing the consensus client. Fixes CI E2E failures where cl (Teku beacon) crashed because it couldn't connect to Erigon's Engine API — eth1.service active ≠ Engine API ready.
4. **Diagnostics on failure**: `_verify_service_active` now dumps `systemctl status` and `journalctl -n 80` when a service fails, so CI logs show the actual error for RCA.

---

## Diagnostic Logs (Kept)

On beacon REST failure, we now log:

- Curl exit code interpretation (7=refused, 28=timeout, 6=resolve)
- Port 5052 listening: `ss -tlnp | grep 5052`
- cl.service active, eth1.service active
- cl.service ExecStart line
- Last 25 lines of `journalctl -u cl`

These help confirm or refine this RCA from future CI runs.
