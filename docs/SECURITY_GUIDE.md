# Security Guide

## Overview
This guide provides comprehensive security information for the Ethereum node setup scripts. The security implementation focuses on network security, file protection, input validation, and monitoring.

## Security Features

### Network Security
- **Localhost Binding**: All services bind to `127.0.0.1` only
- **Firewall Protection**: UFW firewall with comprehensive rules
- **Fail2ban Integration**: Protection against brute force attacks
- **Snort IDS**: Host-level packet inspection profile (enabled by default, configurable)
- **Private Network Blocking**: Prevents network scan abuse

### File Security
- **Secure Permissions**: Configuration files (600), directories (700)
- **Automatic Management**: Scripts set appropriate permissions
- **Secrets Protection**: JWT secrets and keys properly secured

### Input Validation
- **User Input Validation**: Comprehensive validation functions
- **Path Traversal Prevention**: Prevents directory traversal attacks
- **Command Injection Prevention**: Safe command execution
- **URL Validation**: Validates download URLs before use

### Error Handling
- **Sanitized Messages**: Error messages don't leak sensitive information
- **Secure Execution**: Safe command execution patterns
- **No Information Disclosure**: Errors don't expose system details

### Monitoring
- **Security Monitoring**: Real-time monitoring script
- **Process Monitoring**: Detects suspicious activities
- **Resource Monitoring**: Monitors disk, memory, and network usage
- **Log Management**: Automated log rotation and analysis

## Security Scripts

### Core Security Scripts
- **`install/security/consolidated_security.sh`** - Main security setup (firewall, fail2ban, Snort, AIDE)
- **`install/security/nginx_harden.sh`** - Nginx proxy abuse protection
- **`install/security/cve_2026_98432_mitigation.sh`** - CVE-2026-98432 interim mitigation (see below)
- **`install/security/test_security_fixes.sh`** - Security testing suite

### Testing Scripts
- **`docs/verify_security.sh`** - Production security verification
- **`docs/validate_security_safe.sh`** - Safe validation without root

### Usage
```bash
# Security setup is called automatically from run_1.sh
# Test security implementations
./install/security/test_security_fixes.sh

# Comprehensive security verification
./docs/verify_security.sh

# Safe validation (no root required)
./docs/validate_security_safe.sh
```

## CVE-2026-98432 Interim Mitigation

**What it is.** CVE-2026-98432 is a remote, unauthenticated use-after-free in the Linux IPv4
TCP stack. It fires during the handshake when the SYN carries the IPv4 Record Route or Timestamp
options, and affects kernels from 4.4 on that lack the fix. As of 2026-11-01 Ubuntu lists noble
(24.04) `linux` as vulnerable, with the fix in progress for 6.8.0-149, and no USN yet.

**Why it matters for Go clients.** The only known working exploit needs a public multipath TCP
(MPTCP) listener. Since Go 1.24, Go programs open MPTCP listeners by default, so a geth (or prysm,
mev-boost, commit-boost...) built with a recent Go likely listens with MPTCP on its public p2p port
(30303 for geth). A newer geth is therefore more exposed than an old one. The Go team says the bug
is not MPTCP-specific, so all three layers below are applied together.

**What Phase 1 does** (`run_1.sh`, also `harden_server.sh` network module), idempotently and
persisting across reboots:

| Layer | Files | Effect |
|-------|-------|--------|
| Kernel MPTCP off | `/etc/sysctl.d/90-disable-mptcp.conf` + `sysctl -w net.mptcp.enabled=0` | No new MPTCP sockets; Go falls back to plain TCP |
| Drop TCP with IPv4 options | `/etc/nftables-cve-2026-98432.nft`, loaded by `cve-2026-98432-nft.service` | Separate `ip cve_2026_98432` table at prerouting priority -300 drops TCP packets whose IP header is longer than 20 bytes (`ip hdrlength gt 5`). ufw and Docker rules are untouched |
| No MPTCP listeners from Go | `/etc/systemd/{system,user}.conf.d/90-godebug-mptcp.conf`, `/etc/environment`, and `Environment="GODEBUG=multipathtcp=0"` in every unit eth2-quickstart generates | Go programs open plain TCP listeners. An existing `GODEBUG` in `/etc/environment` gets `,multipathtcp=0` appended; a conflicting `multipathtcp=` value is left alone with a warning |

At the end the step prints the MPTCP sysctl value, whether the nft table is loaded, the systemd
manager `GODEBUG`, and any MPTCP listeners still open. Restart the services it lists (or reboot)
so they reopen their sockets as plain TCP. Check at any time, read-only:

```bash
sudo ./install/security/cve_2026_98432_mitigation.sh --verify
ss -Mltnp | grep ^mptcp     # should print nothing
```

**Limits.**
- Docker containers do not inherit the host's `GODEBUG`; set it in the container's environment
  yourself. Kernel MPTCP off still applies to them.
- The nft rule reduces exposure but does not fully prevent it; it only covers IPv4 options on TCP.
  It also drops the rare legitimate TCP traffic that uses IP options.
- **The real fix is the distro's patched kernel plus a reboot** (Ubuntu 24.04: expected in
  `6.8.0-149` or later). Check with `uname -r` after `apt full-upgrade` and a reboot.

**Opt out / undo.** To skip it on install, set in `config/user_config.env` (or the environment):

```bash
export ENABLE_CVE_2026_98432_MITIGATION='false'
```

Once a patched kernel is booted, remove it:

```bash
sudo ./install/security/cve_2026_98432_mitigation.sh --remove
```

This deletes the sysctl, nft and systemd drop-in files, disables the unit, drops the nft table and
removes `multipathtcp=0` from `/etc/environment`. MPTCP stays off until the next reboot. Units
already generated keep their harmless `GODEBUG=multipathtcp=0` line until they are regenerated
with the opt-out set.

## Security Workflow

### Installation Security
1. **Initial Setup** (`run_1.sh`):
   - Network security configuration
   - File permission securing
   - Security monitoring setup

2. **Client Installation** (`run_2.sh`):
   - Post-installation hardening
   - Configuration file securing
   - Security validation

### Verification
1. **Test Security**: Run `./test_security_fixes.sh`
2. **Verify Security**: Run `./docs/verify_security.sh`
3. **Monitor Logs**: Check `/var/log/security_monitor.log`

## Security Best Practices

### Configuration
- No hardcoded sensitive values
- JWT secrets referenced by file path
- External IPs determined at runtime

### Scripts
- Follow shell scripting best practices
- Proper error handling and logging
- Input validation and sanitization
- Secure file operations

### System
- Services bind to localhost only
- Firewall rules prevent unauthorized access
- File permissions restrict access
- Security monitoring detects issues

## Monitoring

### Log Files
- **Security Monitoring**: `/var/log/security_monitor.log`
- **AIDE Integrity**: `/var/log/aide_check.log`
- **System Logs**: `/var/log/syslog`
- **Fail2ban Logs**: `/var/log/fail2ban.log`

### AIDE File Integrity Monitoring
AIDE (Advanced Intrusion Detection Environment) creates a baseline of critical system files and detects tampering. Config: `config/aide.conf` (single source). It monitors:
- **`/etc`** – System configuration (SSH, firewall, etc.)
- **`/bin`, `/usr/bin`, `/usr/sbin`** – Executables

The config uses SHA-256 checksums for content integrity (per [AIDE best practices](https://github.com/aide/aide/blob/master/doc/aide.conf.5)). Daily checks run at 2 AM via cron. Review `/var/log/aide_check.log` for changes.

### Snort IDS Profile
Snort support is enabled by default during Phase 1 hardening.

Disable via `config/user_config.env`:

```bash
export ENABLE_SNORT='false'
export SNORT_INTERFACE='auto'
export SNORT_HOME_NET=''
export SNORT_STARTUP='boot'
export SNORT_DISABLE_PROMISCUOUS='true'
```

### Monitoring Schedule
- **Security Monitoring**: Every 15 minutes
- **AIDE Integrity Check**: Daily at 2 AM
- **Log Rotation**: Automated via logrotate

### Alert Conditions
- Suspicious processes detected
- Failed SSH attempts
- High resource usage
- Unusual network connections
- File integrity violations

## Troubleshooting

### Common Issues
1. **Scripts not executable**: `chmod +x *.sh`
2. **Permission denied**: Check file ownership
3. **Missing dependencies**: Install required packages
4. **Services not starting**: Check service status and logs

### Getting Help
1. Check logs for error messages
2. Run validation scripts to identify issues
3. Review security documentation
4. Check system requirements

## Security Maintenance

### Regular Tasks
- Monitor security logs for alerts
- Review security test results
- Update system and dependencies
- Verify firewall rules are active

### Quarterly Tasks
- Comprehensive security assessment
- Review and update security policies
- Test security incident response procedures
- Update security documentation

## Conclusion

The security implementation provides enterprise-grade security features that are fully integrated into the installation process. All critical vulnerabilities have been addressed with comprehensive fixes that follow security best practices.

**Status**: PRODUCTION READY with HIGH security level.
