#!/bin/bash
# Validate the repo's PR/commit attribution contract (issue #230 item 2, AGENTS.md L6-7):
#   - commit author = the agent identity, not the human
#   - every commit carries the exact trailer: Co-authored-by: Chimera <chimera_defi@protonmail.com>
#   - the PR body states **Agent:** <model> and **Co-authored-by:** Chimera <...>
#
# The real historical failure (PR #233, Codex P1): commit author was `Codex <codex@openai.com>`
# — not the human, so an author-only inversion guard would have missed it — and the required
# Chimera trailer was absent entirely. The trailer check is load-bearing; the author check is a
# second, narrower guard against the opposite failure (author=human, trailer=agent, inverted).
#
# KNOWN GAP, not solved here: issue #230 item 2 also asks for "the exact trailer on the final
# squash commit." No check for that exists in this file, and — verified against this repo's last
# 6 real merges (#247-#252) — it is NOT satisfied as a side effect of this check passing. Squash
# merges performed via `gh pr merge --squash` (a human token) do not carry the branch commit's
# "Co-authored-by: Chimera" trailer forward: GitHub's squash-commit author becomes whoever ran
# the merge (Chimera), and Chimera is then excluded from the generated co-author list (you can't
# co-author with yourself) — so the trailer that lands instead names the *agent* (promoted from
# the branch commit's author field), the opposite of what the issue asks for. This reproduced on
# 5 of 6 real single-commit-squash merges (#247, #248, #249, #250, #251); #252's 3-commit squash
# happened to read differently only because GitHub's multi-commit squash template concatenates
# every original commit body verbatim as inert text, which is a formatting artifact, not a rollup
# mechanism, and isn't representative of the single-commit case. A pre-merge `pull_request` check
# structurally cannot gate the squash commit anyway (it doesn't exist yet), and a post-merge
# `push`-to-master check couldn't distinguish "agent work missing its trailer" from a legitimately
# trailer-less human commit — so this isn't a check left un-written, it's an acceptance criterion
# that isn't achievable through CI at all under the current human-token squash-merge convention.
# Closing it for real would need the merge itself performed by a bot/agent-owned token instead.
#
# Usage: ci_test_pr_attribution.sh --commits FILE [--pr-body FILE]
#   --commits FILE   Required. NUL-delimited git-log records:
#                     `git log -z --format='%H%x1f%an%x1f%ae%x1f%B' <base>..<head>`
#   --pr-body FILE    Optional. Raw PR body text. Omitted for local pre-commit runs, where no
#                     PR exists yet — only the commit-side checks run.

set -euo pipefail

HUMAN_EMAIL="chimera_defi@protonmail.com"
FAILED=0

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
}

COMMITS_FILE=""
PR_BODY_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --commits)
            COMMITS_FILE="$2"
            shift 2
            ;;
        --pr-body)
            PR_BODY_FILE="$2"
            shift 2
            ;;
        *)
            echo "[ERROR] unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

if [[ -z "$COMMITS_FILE" ]]; then
    echo "[ERROR] --commits FILE is required" >&2
    exit 2
fi
if [[ ! -f "$COMMITS_FILE" ]]; then
    echo "[ERROR] --commits file not found: $COMMITS_FILE" >&2
    exit 2
fi

check_commit_attribution() {
    log_info "Checking commit-level attribution (author identity + Chimera co-author trailer)..."

    local record sha author_name author_email body rest short_sha

    while IFS= read -r -d '' record; do
        [[ -z "$record" ]] && continue

        sha="${record%%$'\x1f'*}"
        rest="${record#*$'\x1f'}"
        author_name="${rest%%$'\x1f'*}"
        rest="${rest#*$'\x1f'}"
        author_email="${rest%%$'\x1f'*}"
        body="${rest#*$'\x1f'}"

        # Skip GitHub's synthetic merge commits, matching the commit-conventions job's convention.
        if [[ "$body" =~ ^Merge[[:space:]] ]]; then
            continue
        fi

        short_sha="${sha:0:7}"

        if [[ "$author_email" == "$HUMAN_EMAIL" ]]; then
            log_error "commit $short_sha: author email is $HUMAN_EMAIL (the human credited as co-author) — the commit author must be the agent identity, not the human. See AGENTS.md L6-7."
            FAILED=1
        fi

        if ! grep -qiE '^co-authored-by:[[:space:]]*chimera[[:space:]]*<chimera_defi@protonmail\.com>[[:space:]]*$' <<< "$body"; then
            log_error "commit $short_sha ($author_name <$author_email>): missing required trailer 'Co-authored-by: Chimera <chimera_defi@protonmail.com>'. See AGENTS.md L6-7."
            FAILED=1
        fi
    done < "$COMMITS_FILE"
}

check_pr_body_attribution() {
    log_info "Checking PR body attribution fields..."

    if ! grep -qiE '\*\*Agent:\*\*[[:space:]]*[^[:space:]]' "$PR_BODY_FILE"; then
        log_error "PR body: missing required '**Agent:** <model name>' field. See AGENTS.md L6-7."
        FAILED=1
    else
        local agent_value
        # Match to end of line with `.*`, not a `[^\r\n]` bracket exclusion: grep implementations
        # disagree on whether \r/\n inside [...] mean control chars or the literal characters
        # '\', 'r', 'n' (the latter silently truncates at any literal 'n' or 'r' in the value).
        # tr -d strips a trailing CR unambiguously (no bracket-expression escaping involved).
        agent_value=$(grep -oiE '\*\*Agent:\*\*[[:space:]]*.*' "$PR_BODY_FILE" | head -1 | tr -d '\r' | sed -E 's/\*\*Agent:\*\*[[:space:]]*//I; s/[[:space:]]+$//')
        if echo "$agent_value" | grep -qiE '^(AI|AI Assistant|Assistant|Agent|Unknown|N/A|TBD|TODO|PLACEHOLDER|XXX|<model name>)$'; then
            log_error "PR body: '**Agent:**' field is a placeholder ('$agent_value'), not an actual model name. See AGENTS.md L6-7."
            FAILED=1
        fi
    fi

    if ! grep -qiE '\*\*Co-authored-by:\*\*[[:space:]]*Chimera[[:space:]]*<chimera_defi@protonmail\.com>' "$PR_BODY_FILE"; then
        log_error "PR body: missing required '**Co-authored-by:** Chimera <chimera_defi@protonmail.com>' field. See AGENTS.md L6-7."
        FAILED=1
    fi
}

check_commit_attribution

if [[ -n "$PR_BODY_FILE" ]]; then
    if [[ ! -f "$PR_BODY_FILE" ]]; then
        echo "[ERROR] --pr-body file not found: $PR_BODY_FILE" >&2
        exit 2
    fi
    check_pr_body_attribution
else
    log_info "No --pr-body given (local run, no PR yet) — skipping PR body checks."
fi

if [[ "$FAILED" -ne 0 ]]; then
    log_error "PR attribution checks failed"
    exit 1
fi

log_info "PR attribution checks passed"
