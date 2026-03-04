# AGENTS.md

This file defines persistent workflow guidance for coding agents working in this repo.

## Default Start-Of-Work Routine
1. Fetch latest remote state: `git fetch origin --prune`.
2. Start from latest `origin/master` for new work:
   - `git checkout -B master origin/master`
   - create a new branch for the task.
3. If pre-existing local changes are valuable, preserve them before syncing:
   - use `git stash push -u -m "<context>"` or
   - commit to a dedicated branch.
4. Run relevant local validation before opening a PR.

## Branch and PR Policy
- Treat each new user task as new work: use a fresh branch.
- Open a new PR for each distinct work item.
- Do not stack unrelated changes into an existing PR.

## Session Memory Pattern
- Keep durable, human-readable context in repo files, not ephemeral chat memory.
- Update `docs/agent-handoff.md` at the end of substantial work with:
  - what changed,
  - why,
  - validation run,
  - follow-ups.

## Safety
- Do not discard user work without explicit instruction.
- Avoid destructive git operations unless explicitly requested.
