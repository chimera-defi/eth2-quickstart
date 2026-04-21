# Caddy Web Server Installation Guide

This guide covers the installation and configuration of Caddy web server as an alternative to Nginx for the Ethereum node setup.

## Overview

Caddy is a modern web server with automatic HTTPS, strong security defaults, and easy configuration. In this project, Caddy and Nginx share one generated edge policy, and install-time module bootstrap enables a batteries-included baseline for rate limiting.

## Features

- **Automatic HTTPS**: Built-in Let's Encrypt integration
- **HTTP/2 and HTTP/3 Support**: Modern protocol support
- **Security Headers**: Comprehensive security headers by default
- **Rate Limiting**: Enabled by default via installer module bootstrap
- **Easy Configuration**: Simple Caddyfile syntax
- **Reverse Proxy**: Excellent reverse proxy capabilities
- **Logging**: Structured JSON logging

## Project Architecture Compliance

The Caddy implementation follows the project's established patterns:

- **Local Helper Functions**: Uses `caddy_helpers.sh` instead of cluttering common functions
- **Self-Contained Scripts**: Each installation script is independent
- **Strict Mode**: All scripts use `set -Eeuo pipefail` and `IFS=$'\n\t'`
- **Consistent Logging**: Uses project's logging functions
- **Error Handling**: Follows project's error handling patterns
- **Configuration Management**: Uses centralized variables from `exports.sh`
- **Shared Edge Policy**: Route/method/security policy is rendered from `install/web/proxy_config_renderer.sh` for both Nginx and Caddy
- **Shared Edge Tuning**: `EDGE_*` and `CADDY_*` env vars tune retries, keepalive, compression, metrics, trusted proxies, and upstream fanout for both web stacks
- **Shellcheck Compliance**: All scripts pass shellcheck validation

## Installation Scripts

### 1. Basic Installation (`install_caddy.sh`)

Installs Caddy with automatic HTTPS support:

```bash
cd install/web
sudo ./install_caddy.sh
```

**Features:**
- Installs Caddy from official repository
- Configures automatic HTTPS (uses Cloudflare DNS challenge when `dns.providers.cloudflare` and `CLOUDFLARE_API_TOKEN` are available)
- Sets up reverse proxy for Ethereum RPC and WebSocket APIs
- Applies security hardening
- Configures firewall rules
- Sets up logging
- Uses local helper functions (`caddy_helpers.sh`)

### 2. SSL Installation (`install_caddy_ssl.sh`)

Installs Caddy with manual SSL certificate configuration:

```bash
cd install/web
sudo ./install_caddy_ssl.sh
```

**Prerequisites:**
- SSL certificates must be installed first (run `install_ssl_certbot.sh` or `install_acme_ssl.sh`)

**Features:**
- Uses existing SSL certificates
- Same reverse proxy configuration
- Manual SSL certificate management
- Uses local helper functions (`caddy_helpers.sh`)

### 3. Security Hardening (`caddy_harden.sh`)

Applies comprehensive security hardening:

```bash
cd install/security
sudo ./caddy_harden.sh
```

**Security Features:**
- Enhanced SSL/TLS configuration
- Comprehensive security headers
- Rate limiting on all endpoints (when `http.handlers.rate_limit` is available)
- Attack pattern blocking
- Request size limits
- Timeout configurations
- Security monitoring

## Configuration

### Caddyfile Location
- **Main config**: `/etc/caddy/Caddyfile`
- **Backup**: `/etc/caddy/Caddyfile.backup.*`

### Configuration Templates
- **Basic**: `install/examples/caddy_conf`
- **SSL**: `install/examples/caddy_conf_ssl`

### Key Configuration Features

1. **Automatic HTTPS**: Uses ACME/TLS automation; Cloudflare DNS challenge is enabled when module+token are available
2. **Reverse Proxy**: Routes traffic to Ethereum clients
3. **Security Headers**: Comprehensive security headers
4. **Rate Limiting**: Per-endpoint rate limiting enabled by default via installer module bootstrap
5. **Logging**: Structured JSON logging with rotation

## Endpoints

After installation, the following endpoints are available:

- **WebSocket API**: `https://your-domain.com/ws`
- **RPC API**: `https://your-domain.com/rpc`
- **Prysm Checkpoint Sync**: `https://your-domain.com/prysm/checkpt_sync`
- **Prysm Web Interface**: `https://your-domain.com/prysm/web`

## Service Management

### Systemd Commands
```bash
# Check status
sudo systemctl status caddy

# Start service
sudo systemctl start caddy

# Stop service
sudo systemctl stop caddy

# Restart service
sudo systemctl restart caddy

# Reload configuration
sudo systemctl reload caddy

# Enable auto-start
sudo systemctl enable caddy
```

### Configuration Management
```bash
# Validate configuration
sudo caddy validate --config /etc/caddy/Caddyfile

# Format configuration
sudo caddy fmt /etc/caddy/Caddyfile

# Test configuration
sudo caddy run --config /etc/caddy/Caddyfile --dry-run
```

## Logging

### Log Locations
- **Access logs**: `/var/log/caddy/access.log`
- **Error logs**: `/var/log/caddy/error.log`
- **Security logs**: `/var/log/caddy_security.log`

### Log Management
- **Rotation**: Automatic log rotation (100MB files, 10 files, 30 days)
- **Format**: JSON structured logging
- **Monitoring**: Security monitoring script runs every 5 minutes

## Security Features

### Built-in Security
- **HSTS**: HTTP Strict Transport Security
- **CSP**: Content Security Policy
- **XSS Protection**: Cross-site scripting protection
- **Clickjacking Protection**: X-Frame-Options
- **MIME Sniffing Protection**: X-Content-Type-Options

### Rate Limiting
- Enabled by default via installer module bootstrap (`http.handlers.rate_limit`).
- Installer also bootstraps `dns.providers.cloudflare` by default for DNS challenge readiness.
- Disable bootstrap only if needed: `CADDY_ENSURE_MODULES=false`.
- Use `CADDY_REQUIRE_RATE_LIMIT=true` to force fail-fast if rate-limit cannot be active.
- **API endpoints**: 50 requests per minute per IP
- **WebSocket endpoints**: 20 requests per minute per IP
- **Window**: 1-minute sliding window

### Attack Prevention
- **Admin panel blocking**: Blocks common admin paths
- **Config file protection**: Blocks access to configuration files
- **Environment file protection**: Blocks access to .env files
- **Fail2ban jails**: Default Caddy jails ban repeated non-RPC probes and repeated 429-rate-limit offenders

## Testing

Validate generated edge configs with the built-in tools before deploy:

```bash
bash ./test/validate_review_guardrails.sh
bash ./test/validate_caddy_config.sh
bash ./test/validate_nginx_config.sh
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl status caddy
```

## Troubleshooting

### Common Issues

1. **Caddy won't start**
   ```bash
   # Check configuration
   sudo caddy validate --config /etc/caddy/Caddyfile
   
   # Check logs
   sudo journalctl -u caddy -f
   ```

2. **SSL certificate issues**
   ```bash
   # Check certificate files
   ls -la /etc/letsencrypt/live/your-domain.com/
   
   # Test SSL configuration
   sudo caddy run --config /etc/caddy/Caddyfile --dry-run
   ```

3. **Permission issues**
   ```bash
   # Fix ownership
   sudo chown -R caddy:caddy /etc/caddy
   sudo chown -R caddy:caddy /var/log/caddy
   ```

### Debug Mode
```bash
# Run Caddy in debug mode
sudo caddy run --config /etc/caddy/Caddyfile --debug
```

## Comparison with Nginx

| Feature | Caddy | Nginx |
|---------|-------|-------|
| Configuration | Simple Caddyfile | Complex nginx.conf |
| HTTPS | Automatic | Manual setup |
| Security | Built-in headers | Manual configuration |
| Rate Limiting | Enabled by default via installer-bundled `rate_limit` module | Built-in (`limit_req`/`limit_conn`) |
| HTTP/3 | Native support | Requires modules |
| Learning Curve | Easy | Steep |

## Environment Variables

The following environment variables are used:

- `SERVER_NAME`: Domain name for the server
- `CADDY_CONFIG_DIR`: Caddy configuration directory
- `CADDY_LOG_DIR`: Caddy log directory
- `CADDY_CERT_DIR`: SSL certificate directory
- `LH`: Local host address
- `NETHERMIND_HTTP_PORT`: Nethermind HTTP port
- `NETHERMIND_WS_PORT`: Nethermind WebSocket port
- `EDGE_RPC_RATE_LIMIT_RPM` / `EDGE_WS_RATE_LIMIT_RPM` / `EDGE_GENERAL_RATE_LIMIT_RPM`: shared rate-limit budgets rendered into both Nginx + Caddy policies
- `EDGE_RPC_BURST` / `EDGE_WS_BURST`: shared request burst ceilings for Nginx request limiting
- `EDGE_RPC_CONN_LIMIT_PER_IP` / `EDGE_WS_CONN_LIMIT_PER_IP`: shared per-IP connection ceilings for Nginx
- `CADDY_ENSURE_MODULES`: `true|false` (default `true`) bootstrap required Caddy modules during install
- `CADDY_REQUIRED_MODULES`: comma-separated modules to bootstrap (default `http.handlers.rate_limit,dns.providers.cloudflare`)
- `CADDY_REQUIRED_PACKAGES`: comma-separated plugin package imports for Caddy download API (default `github.com/mholt/caddy-ratelimit,github.com/caddy-dns/cloudflare`)
- `CADDY_INSTALL_ENFORCE_RATE_LIMIT`: `true|false` (default `true`) force `install_caddy.sh` to require active rate limiting
- `CADDY_ENABLE_RATE_LIMIT`: `auto|true|false` (module auto-detect by default)
- `CADDY_REQUIRE_RATE_LIMIT`: `true|false` fail-fast guard for rate limiting
- `CADDY_ENABLE_DNS_CHALLENGE`: `auto|true|false` (Cloudflare DNS challenge auto-detect by default)
- `CADDY_REQUIRE_DNS_CHALLENGE`: `true|false` fail-fast guard for DNS challenge

## Integration with Ethereum Clients

Caddy is configured to work with:
- **Nethermind**: HTTP and WebSocket APIs
- **Prysm**: Checkpoint sync and web interface
- **Other clients**: Easily configurable via Caddyfile

## Best Practices

1. **Regular Updates**: Keep Caddy updated for security patches
2. **Monitor Logs**: Regularly check security and access logs
3. **Backup Configuration**: Keep backups of working configurations
4. **Test Changes**: Always test configuration changes in a safe environment
5. **Security Monitoring**: Use the built-in security monitoring
6. **Rate Limiting**: Keep installer module bootstrap enabled (`CADDY_ENSURE_MODULES=true`) so Caddy rate limiting remains active by default
7. **SSL Certificates**: Monitor certificate expiration

## Support

For issues and questions:
1. Check the test script output
2. Review log files
3. Validate configuration
4. Check systemd service status
5. Verify firewall rules
6. Test SSL certificates

## Additional Resources

- [Caddy Documentation](https://caddyserver.com/docs/)
- [Caddyfile Syntax](https://caddyserver.com/docs/caddyfile)
- [Caddy Security](https://caddyserver.com/docs/security)
- [Caddy Plugins](https://caddyserver.com/download)
