# Closed PR Follow-ups

Last updated: 2026-03-11

This file is the parking lot for closed PR context that may still matter later.
Use it to distinguish work that was already merged via a superseding PR from ideas
that remain optional follow-ups.

## Superseded and Finished

- `#146` docs-consistency enforcement: finished in `#150`.
- `#147` install.sh smoke harness: finished in `#149`.
- `#148` non-skip TUI shell-test guard: finished in `#149`.
- `#129` ergonomic entrypoints original branch: finished in `#130`.
- `#123` Nimbus-eth1 asset rename fix original branch: finished in `#124`.
- `#121` early E2E/Caddy stabilization branch: finished in `#122`.
- `#136`, `#139`, `#140`: their useful pieces were later absorbed into merged cleanup/test work on `master`; do not reopen the stale branches.
- `#93` tooling/help-flow intent: recovered and finished in `#144`.
- `#137` and `#138`: reduction work was absorbed by later consolidation/reduction merges (`#139`, `#143`, `#145`).
- `#131`, `#132`, `#133`, `#134`: later merged cleanup passes absorbed the remaining useful docs/audit/frontend consistency work; do not reopen the old branches.

## Still Optional to Revisit

- `#141` opt-in Prysm checkpoint smoke verification:
  - opt-in local/live smoke coverage already exists on `master` through `#142` and later follow-up fixes,
  - do not reopen the old branch; if we revisit this area, the remaining work is a fresh PR for a stable CI path that does not add flake or excessive runtime.

## Reopen Recommendation

- No currently tracked closed PR is recommended for reopening.
- If old work is revived, prefer a new PR that references the old PR number and scopes only the still-missing behavior.

## Guidance

- Do not reopen superseded PRs just for history. Their discussion and diffs are already preserved on GitHub.
- If a closed PR has unfinished value, prefer a fresh PR or issue that references the old PR number and states the remaining scope explicitly.
