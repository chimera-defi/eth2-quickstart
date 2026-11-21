# Server-setup CVE audit — 2026-11-21

Scope: Phase 1 hardening, nginx/Caddy installers and configs, SSL helpers, bootstrap.
Primary source for nginx: <https://nginx.org/en/security_advisories.html> (read 2026-11-21;
stable 1.30.7 dated 18 Nov 2026, mainline 1.31.9). Other rows come from secondary
search results and are marked **unverified** until checked against the vendor page.

## nginx (primary source)

Before this change the setup installed the **distro `nginx` package** (Phase 1 package list, then
`install_nginx` said "already installed"), so the running version was whatever the distro shipped.
nginx 1.28 reached end of life in 2026 (last 1.28.3), so nginx.org lists fixes only in 1.30.x/1.31.x.

| Advisory (nginx.org) | Needs | Our config | Exposed (unpatched) |
|---|---|---|---|
| CVE-2026-123007 HTTP/2 flow-control memory corruption (major), fixed 1.30.7 / 1.31.9 | HTTP/2 | SSL site uses `listen 443 ssl http2` | **yes** |
| CVE-2026-123633 HTTP/2 use-after-free, fixed 1.30.7 | HTTP/2 | same | **yes** |
| CVE-2026-118899 infinite loop reading request body over TLS 1.3 (major), fixed 1.30.7 | TLS 1.3 | `ssl_protocols TLSv1.2 TLSv1.3` | **yes** |
| CVE-2026-42533 buffer overflow with `map` + regex (major), fixed 1.30.4 | `map` regex | `map $request_body ~*...` in edge policy | **yes** |
| CVE-2026-123634 resolver use-after-free, fixed 1.30.7 | `resolver` | only if `EDGE_DNS_RESOLVER` set | conditional |
| CVE-2026-9256 / 42945 rewrite buffer overflow | rewrite captures | no `rewrite` generated | no |
| CVE-2026-125283 / 15176 alias + try_files/rewrite | `alias` | none generated | no |
| CVE-2026-97629 TLS session tickets | tickets | `ssl_session_tickets off` | no |
| CVE-2026-42926 HTTP/2 backend injection | `proxy_set_body`, h2 upstream | no | no |
| HTTP/3 (121810, 95101, 90439, 42530, 40460), mail, stream, mp4, dav, ssi, slice, OCSP, charset | module not configured | no | no |

Fix: `install_nginx` now uses the signed nginx.org stable repo (key fingerprint verified against
`573BFD6B…BF62`, apt pin 900), replaces a distro nginx, keeps our `sites-enabled` layout, and fails if
the installed version is below `NGINX_MIN_VERSION` (1.30.7). Set `NGINX_SOURCE=distro` to opt out
(the installer then warns that distro versions are backported and must be checked in the distro tracker).
Phase 1 no longer installs nginx, so no web server is exposed unless one is chosen.

## Caddy (unverified, secondary sources)

2.11.1 fixed GHSA-4xrr-hq4w-6vf4 (file matcher), GHSA-5r3v-vc8m-m96g, GHSA-g7pc-pc7g-h8jh;
2.11.4 fixed forward_auth header spoofing, stripHTML and a placeholder bundle (GHSA-j8px-rmrx-76h9).
We install from the official Cloudsmith apt repo (latest) and optionally a custom binary from
caddyserver.com (latest). Gap: an already-installed Caddy was never upgraded. Fix: `--only-upgrade`
plus a `CADDY_MIN_VERSION=2.11.4` gate. Residual: the custom-module binary is fetched without a
checksum (HTTPS only).

## Others (unverified, secondary sources)

- OpenSSH: 10.3 fixed CVE-2026-35414 (authorized_keys principals) and scp/proxy issues; we use the
  distro `openssh-server` and do not use `AuthorizedPrincipalsFile`/certificates. Distro backports
  apply; unattended upgrades now enabled.
- fail2ban: CVE-2026-109786 (sshd filter log injection can ban arbitrary IPs), fix upstream commit
  ddd879d, distro status unconfirmed. Mitigation: keep `ignoreip` for operator addresses and update fail2ban when the distro ships it.
- sudo: CVE-2026-35535 (privilege drop before mailer, fixed after 1.9.17p2) and CVE-2025-32463
  (chroot, fixed 1.9.17p1). We never use `sudo -R`/chroot; sudo comes from distro security updates.
- certbot/acme.sh: no advisory found. Gap: `install_acme_ssl.sh` clones acme.sh `master` unpinned.

## Hardening review

Good: SSH key-only, modern KEX/ciphers/MACs, root `prohibit-password`, TLS 1.2/1.3 AEAD ciphers,
`server_tokens off`, 10m body limit, 30s timeouts, HSTS, RPC upstreams on 127.0.0.1.
Added: `unattended-upgrades` (security pocket, daily).
Not changed (recommend): pin acme.sh to a release tag; checksum for the Caddy custom binary.

## Docker verification (ubuntu:24.04 image built from test/Dockerfile)

- Distro nginx 1.24.0 replaced by nginx.org 1.30.7 via `install_nginx`; `nginx -t` passes with the
  generated edge policy and HTTP and HTTPS site configs; HTTP 301 and HTTP/2 responses served; `Server: nginx` (tokens off).
- Found and fixed on the way: nginx.org's stock `nginx.conf` sets `keepalive_timeout` (duplicate
  with our policy), and the generated SSL site config contained a literal `\n` after `ssl_ciphers`
  (already on master; `nginx -t` failed for every HTTPS setup). Regression check added to
  `test/validate_proxy_policy_sync.sh`.
- Caddy in the test image: v2.11.9 (above the 2.11.4 floor).
- `ci_test_run_1.sh` (as root) and `run_tests.sh --lint-only`: pass.
- Not covered: `listen ... http2` is deprecated on nginx >= 1.25.1 (warning only; works).
