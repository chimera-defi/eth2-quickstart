#!/bin/bash

# CVE-2026-98432 interim mitigation (Linux IPv4 TCP use-after-free on SYNs with IP options)
# Used by run_1.sh (Phase 1) and harden_server.sh; safe to run more than once.
# Disable with ENABLE_CVE_2026_98432_MITIGATION=false. See docs/SECURITY_GUIDE.md.
#
# Usage:
#   ./cve_2026_98432_mitigation.sh            # apply (default) + verify
#   ./cve_2026_98432_mitigation.sh --verify   # print current state only (read-only)
#   ./cve_2026_98432_mitigation.sh --remove   # undo, once a patched kernel is installed
#
# Test hooks: CVE_MITIGATION_ROOT prefixes every /etc path, and
# CVE_MITIGATION_SKIP_RUNTIME=true skips sysctl/nft/systemctl/ss calls.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

ROOT="${CVE_MITIGATION_ROOT:-}"
SKIP_RUNTIME="${CVE_MITIGATION_SKIP_RUNTIME:-false}"

NFT_TABLE="cve_2026_98432"
NFT_UNIT="cve-2026-98432-nft.service"
SYSCTL_FILE="$ROOT/etc/sysctl.d/90-disable-mptcp.conf"
NFT_FILE_REAL="/etc/nftables-cve-2026-98432.nft"
NFT_FILE="$ROOT$NFT_FILE_REAL"
UNIT_FILE="$ROOT/etc/systemd/system/$NFT_UNIT"
SYSTEM_DROPIN="$ROOT/etc/systemd/system.conf.d/90-godebug-mptcp.conf"
USER_DROPIN="$ROOT/etc/systemd/user.conf.d/90-godebug-mptcp.conf"
ENV_FILE="$ROOT/etc/environment"
GODEBUG_TOKEN="multipathtcp=0"

runtime_enabled() {
    [[ "$SKIP_RUNTIME" != "true" ]]
}

# Write a file only when its content differs (idempotent, no mtime churn for AIDE)
write_if_changed() {
    local path="$1" content="$2" mode="${3:-644}"
    mkdir -p "$(dirname "$path")"
    if [[ -f "$path" ]] && [[ "$(cat "$path")" == "$content" ]]; then
        log_info "Unchanged: $path"
        return 0
    fi
    printf '%s\n' "$content" > "$path"
    chmod "$mode" "$path"
    log_info "Wrote: $path"
}

# --- Part 1: kernel MPTCP off -------------------------------------------------
apply_sysctl() {
    write_if_changed "$SYSCTL_FILE" "# CVE-2026-98432 interim mitigation (eth2-quickstart). Remove once the kernel is patched.
net.mptcp.enabled = 0"
    runtime_enabled || return 0
    if [[ -e /proc/sys/net/mptcp/enabled ]]; then
        sysctl -w net.mptcp.enabled=0 >/dev/null || log_warn "sysctl -w net.mptcp.enabled=0 failed (container?)"
    else
        log_info "Kernel has no MPTCP support; sysctl file kept for future kernels"
    fi
}

# --- Part 2: drop TCP packets carrying IPv4 options ---------------------------
# Separate table at prerouting priority -300 so ufw/Docker rules are untouched.
# Ordered before network-pre.target (like nftables.service) so no interface is up unfiltered.
apply_nft() {
    write_if_changed "$NFT_FILE" "# CVE-2026-98432 interim mitigation (eth2-quickstart): drop TCP with IPv4 options
table ip $NFT_TABLE
delete table ip $NFT_TABLE
table ip $NFT_TABLE {
    chain pre {
        type filter hook prerouting priority -300;
        meta l4proto tcp ip hdrlength gt 5 counter drop
    }
}"
    write_if_changed "$UNIT_FILE" "[Unit]
Description=CVE-2026-98432 mitigation: drop TCP packets with IPv4 options
DefaultDependencies=no
Wants=network-pre.target
Before=network-pre.target network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/nft -f $NFT_FILE_REAL
ExecStop=/usr/sbin/nft delete table ip $NFT_TABLE

[Install]
WantedBy=multi-user.target"
    runtime_enabled || return 0
    if ! command -v nft >/dev/null 2>&1; then
        install_dependencies nftables || log_warn "Could not install nftables; nft rule not loaded"
    fi
    systemctl daemon-reload || log_warn "systemctl daemon-reload failed"
    systemctl enable "$NFT_UNIT" >/dev/null 2>&1 || log_warn "Could not enable $NFT_UNIT"
    # restart (not start) so an edited rule file is reloaded on re-runs
    systemctl restart "$NFT_UNIT" || log_warn "Could not start $NFT_UNIT (container without NET_ADMIN?)"
}

# --- Part 3: GODEBUG=multipathtcp=0 for Go programs ----------------------------
# Merge GODEBUG in /etc/environment without clobbering an existing value.
merge_environment_godebug() {
    touch "$ENV_FILE"
    local line value quoted=""
    line=$(grep -E '^GODEBUG=' "$ENV_FILE" | tail -n1 || true)
    if [[ -z "$line" ]]; then
        # Keep an unterminated last line from swallowing ours
        if [[ -s "$ENV_FILE" ]] && [[ -n "$(tail -c1 "$ENV_FILE")" ]]; then
            printf '\n' >> "$ENV_FILE"
        fi
        printf '%s\n' "GODEBUG=$GODEBUG_TOKEN" >> "$ENV_FILE"
        log_info "Added GODEBUG=$GODEBUG_TOKEN to $ENV_FILE"
        return 0
    fi
    value="${line#GODEBUG=}"
    # Only merge plain KEY=VAL lists; comments or odd quoting are left for a human
    if ! [[ "$value" =~ ^\"?[A-Za-z0-9_.=,-]*\"?$ ]]; then
        log_warn "$ENV_FILE has a GODEBUG line this script cannot merge safely ($line); add $GODEBUG_TOKEN by hand"
        return 0
    fi
    if [[ "$value" == \"*\" ]]; then
        quoted='"'
        value="${value#\"}"
        value="${value%\"}"
    fi
    case ",$value," in
        *",$GODEBUG_TOKEN,"*)
            log_info "$ENV_FILE already has $GODEBUG_TOKEN" ;;
        *",multipathtcp="*)
            log_warn "$ENV_FILE sets a different multipathtcp value ($line); left unchanged, review it" ;;
        *)
            local new="GODEBUG=${quoted}${value:+$value,}${GODEBUG_TOKEN}${quoted}"
            local tmp
            tmp=$(mktemp)
            awk -v old="$line" -v new="$new" '$0 == old { print new; next } { print }' "$ENV_FILE" > "$tmp"
            cat "$tmp" > "$ENV_FILE"
            rm -f "$tmp"
            log_info "Appended ,$GODEBUG_TOKEN to existing GODEBUG in $ENV_FILE" ;;
    esac
}

apply_godebug() {
    local dropin="# CVE-2026-98432 interim mitigation (eth2-quickstart): no MPTCP listeners from Go
[Manager]
DefaultEnvironment=\"GODEBUG=$GODEBUG_TOKEN\""
    write_if_changed "$SYSTEM_DROPIN" "$dropin"
    write_if_changed "$USER_DROPIN" "$dropin"
    merge_environment_godebug
    runtime_enabled || return 0
    systemctl daemon-reexec || log_warn "systemctl daemon-reexec failed"
}

# --- Removal (after a patched kernel is installed and booted) -----------------
remove_environment_godebug() {
    [[ -f "$ENV_FILE" ]] || return 0
    local tmp
    tmp=$(mktemp)
    awk -v tok="$GODEBUG_TOKEN" '
        /^GODEBUG=/ {
            v = substr($0, 9); q = ""
            if (v ~ /^".*"$/) { q = "\""; v = substr(v, 2, length(v) - 2) }
            n = split(v, parts, ","); out = ""
            for (i = 1; i <= n; i++) if (parts[i] != tok && parts[i] != "") out = out (out == "" ? "" : ",") parts[i]
            if (out != "") print "GODEBUG=" q out q
            next
        }
        { print }' "$ENV_FILE" > "$tmp"
    cat "$tmp" > "$ENV_FILE"
    rm -f "$tmp"
}

remove_mitigation() {
    log_info "Removing CVE-2026-98432 interim mitigation..."
    if runtime_enabled; then
        systemctl disable --now "$NFT_UNIT" 2>/dev/null || true
        nft delete table ip "$NFT_TABLE" 2>/dev/null || true
    fi
    rm -f "$SYSCTL_FILE" "$NFT_FILE" "$UNIT_FILE" "$SYSTEM_DROPIN" "$USER_DROPIN"
    remove_environment_godebug
    if runtime_enabled; then
        systemctl daemon-reload || true
        systemctl daemon-reexec || true
        log_info "MPTCP stays off until reboot (or: sysctl -w net.mptcp.enabled=1)"
    fi
    log_info "Removed. Service units generated by eth2-quickstart still carry GODEBUG=$GODEBUG_TOKEN (harmless)."
}

# --- Verification --------------------------------------------------------------
verify_mitigation() {
    log_info "=== CVE-2026-98432 mitigation status ==="
    log_info "Kernel: $(uname -r) (real fix: distro patched kernel + reboot; Ubuntu 24.04 expected 6.8.0-149+)"
    if ! runtime_enabled; then
        log_info "Runtime checks skipped (CVE_MITIGATION_SKIP_RUNTIME=true)"
        return 0
    fi
    log_info "net.mptcp.enabled = $(cat /proc/sys/net/mptcp/enabled 2>/dev/null || echo 'n/a (no MPTCP in kernel)')"
    if nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
        log_info "nft table ip $NFT_TABLE: loaded"
    elif [[ $EUID -ne 0 ]]; then
        log_info "nft table ip $NFT_TABLE: unknown (run as root to check)"
    else
        log_warn "nft table ip $NFT_TABLE: NOT loaded"
    fi
    log_info "systemd manager GODEBUG: $(systemctl show-environment 2>/dev/null | grep '^GODEBUG=' || echo 'unset')"
    local listeners ss_out
    if ! ss_out=$(ss -Mltnp 2>/dev/null); then
        log_warn "MPTCP listeners: unknown (ss -Mltnp failed or is unavailable)"
        return 0
    fi
    listeners=$(grep '^mptcp' <<< "$ss_out" || true)
    if [[ -n "$listeners" ]]; then
        log_warn "MPTCP listeners still open; restart these services to pick up GODEBUG:"
        printf '%s\n' "$listeners"
    else
        log_info "No MPTCP listeners open"
    fi
}

main() {
    local mode="apply"
    case "${1:-}" in
        --verify) mode="verify" ;;
        --remove) mode="remove" ;;
        ""|--apply) ;;
        *) log_error "Unknown option: $1 (use --apply, --verify or --remove)"; exit 1 ;;
    esac

    if [[ "$mode" == "verify" ]]; then
        verify_mitigation
        return 0
    fi
    [[ -n "$ROOT" ]] || require_root

    if [[ "$mode" == "remove" ]]; then
        remove_mitigation
        return 0
    fi
    if [[ "${ENABLE_CVE_2026_98432_MITIGATION:-true}" != "true" ]]; then
        log_info "CVE-2026-98432 mitigation disabled (ENABLE_CVE_2026_98432_MITIGATION=false)"
        return 0
    fi

    log_info "Applying CVE-2026-98432 interim mitigation (MPTCP off, IPv4-options TCP drop, GODEBUG)..."
    apply_sysctl
    apply_nft
    apply_godebug
    verify_mitigation
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
