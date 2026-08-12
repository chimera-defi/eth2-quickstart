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
# No post-merge squash-commit check here by design: the squash commit doesn't exist until after
# merge (can't gate anything), can't distinguish "agent work missing its trailer" from a
# legitimately trailer-less human commit, and is redundant when this check passes — GitHub
# auto-rolls every branch commit's Co-authored-by trailer into the squash commit body (verified
# on master commit 37404cd), so enforcing the trailer here structurally satisfies the issue's
# "exact trailer on the final squash commit" ask without a separate flaky post-hoc check.
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

    if ! grep -qE '\*\*Agent:\*\*[[:space:]]*[^[:space:]]' "$PR_BODY_FILE"; then
        log_error "PR body: missing required '**Agent:** <model name>' field. See AGENTS.md L6-7."
        FAILED=1
    else
        local agent_value
        # Match to end of line with `.*`, not a `[^\r\n]` bracket exclusion: grep implementations
        # disagree on whether \r/\n inside [...] mean control chars or the literal characters
        # '\', 'r', 'n' (the latter silently truncates at any literal 'n' or 'r' in the value).
        # tr -d strips a trailing CR unambiguously (no bracket-expression escaping involved).
        agent_value=$(grep -oE '\*\*Agent:\*\*[[:space:]]*.*' "$PR_BODY_FILE" | head -1 | tr -d '\r' | sed -E 's/\*\*Agent:\*\*[[:space:]]*//; s/[[:space:]]+$//')
        if echo "$agent_value" | grep -qiE '^(AI|AI Assistant|Assistant|Agent|Unknown|N/A|TBD)$'; then
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
