#!/bin/bash

# CVE-2026-98432 interim mitigation (Linux IPv4 TCP use-after-free on SYNs with IP options)
# Called by apply_network_security() (lib/common_functions.sh), which also writes
# net.mptcp.enabled = 0 into /etc/sysctl.d/99-eth2-hardening.conf. Safe to re-run.
# Opt out with ENABLE_CVE_2026_98432_MITIGATION=false. See docs/SECURITY_GUIDE.md.
#
# Usage: cve_2026_98432_mitigation.sh [--apply|--verify|--remove]
# Test hooks: CVE_MITIGATION_ROOT prefixes /etc paths; CVE_MITIGATION_SKIP_RUNTIME=true
# skips nft/systemctl calls.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

ROOT="${CVE_MITIGATION_ROOT:-}"
SKIP_RUNTIME="${CVE_MITIGATION_SKIP_RUNTIME:-false}"
NFT_TABLE="cve_2026_98432"
NFT_UNIT="cve-2026-98432-nft.service"
NFT_FILE="/etc/nftables-cve-2026-98432.nft"
UNIT_FILE="/etc/systemd/system/$NFT_UNIT"
GODEBUG_DROPINS=(/etc/systemd/system.conf.d/90-godebug-mptcp.conf /etc/systemd/user.conf.d/90-godebug-mptcp.conf)
SYSCTL_FILE="/etc/sysctl.d/99-eth2-hardening.conf"

write_file() {
    mkdir -p "$(dirname "$ROOT$1")"
    printf '%s\n' "$2" > "$ROOT$1"
    chmod 644 "$ROOT$1"
}

apply_mitigation() {
    # Drop TCP packets carrying IPv4 options, in a table of our own so ufw/Docker rules are
    # untouched. The leading "table; delete table" pair makes reloading idempotent.
    write_file "$NFT_FILE" "table ip $NFT_TABLE
delete table ip $NFT_TABLE
table ip $NFT_TABLE {
    chain pre {
        type filter hook prerouting priority -300;
        meta l4proto tcp ip hdrlength gt 5 counter drop
    }
}"
    # Loaded before any interface comes up. /etc/nftables.conf starts with "flush ruleset",
    # so run after nftables.service and follow its start/restart/reload to re-add the table.
    write_file "$UNIT_FILE" "[Unit]
Description=CVE-2026-98432 mitigation: drop TCP packets with IPv4 options
DefaultDependencies=no
Wants=network-pre.target
Before=network-pre.target network.target
After=nftables.service
PartOf=nftables.service
ReloadPropagatedFrom=nftables.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/nft -f $NFT_FILE
ExecReload=/usr/sbin/nft -f $NFT_FILE
ExecStop=/usr/sbin/nft delete table ip $NFT_TABLE

[Install]
WantedBy=multi-user.target nftables.service"
    # Go >=1.24 opens MPTCP listeners by default; systemd hands this to every service
    local dropin
    for dropin in "${GODEBUG_DROPINS[@]}"; do
        write_file "$dropin" "[Manager]
DefaultEnvironment=\"GODEBUG=multipathtcp=0\""
    done

    [[ "$SKIP_RUNTIME" == "true" ]] && return 0
    command_exists nft || install_dependencies nftables || log_warn "nftables not installed"  # Phase 1 installs it; harden_server may not
    systemctl daemon-reload || log_warn "systemctl daemon-reload failed"
    systemctl reenable "$NFT_UNIT" >/dev/null 2>&1 || log_warn "Could not enable $NFT_UNIT"
    systemctl restart "$NFT_UNIT" || log_warn "Could not start $NFT_UNIT"
    systemctl daemon-reexec || log_warn "systemctl daemon-reexec failed"
}

remove_mitigation() {
    if [[ "$SKIP_RUNTIME" != "true" ]]; then
        systemctl disable --now "$NFT_UNIT" 2>/dev/null || true
        nft delete table ip "$NFT_TABLE" 2>/dev/null || true
    fi
    rm -f "$ROOT$NFT_FILE" "$ROOT$UNIT_FILE" "${GODEBUG_DROPINS[@]/#/$ROOT}"
    [[ -f "$ROOT$SYSCTL_FILE" ]] && sed -i '/^net\.mptcp\.enabled/d' "$ROOT$SYSCTL_FILE"
    if [[ "$SKIP_RUNTIME" != "true" ]]; then
        systemctl daemon-reload || true
        systemctl daemon-reexec || true
    fi
    log_info "Removed. MPTCP stays off until reboot; generated units keep a harmless GODEBUG line."
}

# Prints state; returns 1 if any layer is missing
verify_mitigation() {
    local failed=0 mptcp godebug listeners ss_out
    mptcp=$(cat /proc/sys/net/mptcp/enabled 2>/dev/null || echo "n/a")
    log_info "CVE-2026-98432: kernel $(uname -r); real fix is a patched kernel + reboot (Ubuntu 24.04: 6.8.0-149+)"
    log_info "CVE-2026-98432: net.mptcp.enabled = $mptcp"
    [[ "$mptcp" == "1" ]] && failed=1

    if nft list table ip "$NFT_TABLE" >/dev/null 2>&1; then
        log_info "CVE-2026-98432: nft table ip $NFT_TABLE = loaded"
    elif [[ $EUID -ne 0 ]]; then
        log_info "CVE-2026-98432: nft table ip $NFT_TABLE = unknown (run as root)"
    else
        log_warn "CVE-2026-98432: nft table ip $NFT_TABLE = NOT loaded$(systemctl is-active --quiet "$NFT_UNIT" 2>/dev/null && echo " (unit active; table flushed? systemctl restart $NFT_UNIT)")"
        failed=1
    fi

    godebug=$(systemctl show-environment 2>/dev/null | grep '^GODEBUG=' || true)
    log_info "CVE-2026-98432: systemd GODEBUG = ${godebug#GODEBUG=}"
    [[ "$godebug" == *multipathtcp=0* ]] || failed=1

    if ! ss_out=$(ss -Mltnp 2>/dev/null); then
        log_warn "CVE-2026-98432: MPTCP listeners = unknown (ss -Mltnp failed)"
        return 1
    fi
    listeners=$(grep '^mptcp' <<< "$ss_out" || true)
    if [[ -n "$listeners" ]]; then
        log_warn "CVE-2026-98432: MPTCP listeners still open; restart these services:"
        printf '%s\n' "$listeners"
    else
        log_info "CVE-2026-98432: MPTCP listeners = none"
    fi
    return "$failed"
}

case "${1:---apply}" in
    --verify) verify_mitigation ;;
    --remove) [[ -n "$ROOT" ]] || require_root; remove_mitigation ;;
    --apply)
        if [[ "${ENABLE_CVE_2026_98432_MITIGATION:-true}" != "true" ]]; then
            log_info "CVE-2026-98432 mitigation disabled (ENABLE_CVE_2026_98432_MITIGATION=false)"
            exit 0
        fi
        [[ -n "$ROOT" ]] || require_root
        log_info "Applying CVE-2026-98432 mitigation (nft IPv4-options drop, GODEBUG=multipathtcp=0)..."
        apply_mitigation
        [[ "$SKIP_RUNTIME" == "true" ]] || verify_mitigation || log_warn "CVE-2026-98432 mitigation incomplete (see above)"
        ;;
    *) log_error "Unknown option: $1 (use --apply, --verify or --remove)"; exit 1 ;;
esac
