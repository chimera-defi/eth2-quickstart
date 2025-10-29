# Security Improvements Roadmap

## For Next Agent to Complete

### Phase 1: Consolidation & Optimization (High Priority)

#### Task 1.1: Use Common Functions for Firewall Setup
**Current Issue**: `consolidated_security.sh` implements custom firewall rules instead of using `setup_firewall_rules()` from common_functions.sh

**Action Required**:
- Review `lib/common_functions.sh` line ~197 for `setup_firewall_rules()` function
- Refactor `setup_firewall()` in consolidated_security.sh to use the common function
- Test that all ports are still configured correctly

**Expected Outcome**: ~20-30 lines of code reduction, better consistency

#### Task 1.2: Clean Up Outdated Documentation
**Files to Remove or Update**:
- ❌ `SECURITY_CONSOLIDATION_SUMMARY.md` - States nginx was consolidated (it wasn't)
- ❌ `SECURITY_MULTIPASS_REVIEW.md` - Outdated review report
- ❌ `SECURITY_FILES_INVENTORY.md` - Incorrect file inventory
- ✅ `SECURITY_CONSOLIDATION_CURRENT_STATE.md` - Keep (just created)
- ⚠️ `SECURITY_GUIDE.md` - Update with current architecture

**Action Required**:
- Delete outdated docs or move to `docs/archive/`
- Update SECURITY_GUIDE.md with current file structure
- Ensure only accurate documentation remains

#### Task 1.3: Create Path Handling Template
**Current Issue**: New scripts need to handle relative paths correctly

**Action Required**:
- Document the standard pattern for path handling in cursor rules or new doc
- Pattern: Use `BASH_SOURCE[0]` to derive PROJECT_ROOT
- Add template to template/install_template.sh for reference

**Template to Document**:
```bash
# Get script directory and source required files from project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source required files from project root
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"
```

### Phase 2: Enhanced Security (Medium Priority)

#### Task 2.1: Add Automated Security Scanning
**Idea**: Add automated security scanning for config files

**Action Required**:
- Add function to scan config files for security issues
- Check for 0.0.0.0 bindings, weak ciphers, etc.
- Integrate into consolidated_security.sh or create separate validation

**Potential Issues to Scan**:
- 0.0.0.0 bindings in client configs (security risk)
- Weak encryption settings
- Exposed RPC endpoints
- Missing authentication

#### Task 2.2: Add Log Monitoring and Alerting
**Current**: Security monitoring exists but could be enhanced

**Action Required**:
- Enhance security monitoring script to detect:
  - Failed authentication attempts (SSH, RPC)
  - Suspicious network activity
  - Service outages
  - Resource exhaustion attacks
- Add alerting mechanism (email, webhook, etc.)

#### Task 2.3: Implement Rate Limiting for RPC Endpoints
**Current**: Some rate limiting exists but could be enhanced

**Action Required**:
- Add comprehensive rate limiting for all RPC endpoints
- Configure nginx rate limiting for HTTP/HTTPS endpoints
- Add rules for WebSocket connections
- Document configuration in security guide

### Phase 3: Advanced Security Features (Low Priority)

#### Task 3.1: Add Intrusion Detection Enhancement
**Current**: AIDE is installed but could have enhanced configuration

**Action Required**:
- Configure AIDE to monitor additional critical directories
- Add automated response to AIDE alerts
- Create baseline for expected changes
- Document monitoring strategy

#### Task 3.2: Implement Secrets Management
**Current**: Secrets are in config files (acceptable but could improve)

**Action Required**:
- Evaluate using environment variables for sensitive data
- Consider using systemd environment files
- Document best practices for secret management
- Add validation to ensure secrets aren't exposed

#### Task 3.3: Add Security Audit Logging
**Current**: Basic logging exists

**Action Required**:
- Implement centralized audit logging
- Log all security-relevant events
- Add log analysis tools
- Create alerts for suspicious patterns

### Phase 4: Documentation & Testing (Ongoing)

#### Task 4.1: Enhance Security Testing
**Current**: test_security_fixes.sh exists

**Action Required**:
- Add more test cases for edge cases
- Test service restart scenarios
- Test configuration change scenarios
- Add performance testing under attack scenarios

#### Task 4.2: Create Security Runbook
**Action Required**:
- Document incident response procedures
- Create checklist for security incidents
- Document recovery procedures
- Add contact information and escalation procedures

#### Task 4.3: Add Security Metrics Dashboard
**Action Required**:
- Document key security metrics to monitor
- Create script to generate security status report
- Add automated security health check
- Track security posture over time

## Quick Wins (Can be done immediately)

1. ✅ Add local shellcheck to CI (completed - now in workflow)
2. 📝 Update cursor rules with path handling pattern
3. 📝 Document standard for using common functions
4. 🗑️ Remove outdated documentation files
5. ✏️ Update SECURITY_GUIDE.md with current architecture

## Estimated Effort

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| Phase 1 | 3 tasks | 2-4 hours |
| Phase 2 | 3 tasks | 4-8 hours |
| Phase 3 | 3 tasks | 6-12 hours |
| Phase 4 | 3 tasks | 3-6 hours |

**Total**: 15-30 hours of focused work

## Success Criteria

### Phase 1 Success
- ✅ Common functions properly utilized
- ✅ Documentation is accurate and up-to-date
- ✅ No duplicate code remains
- ✅ Shellcheck passes on all scripts

### Phase 2 Success
- ✅ Automated security scanning active
- ✅ Enhanced monitoring and alerting working
- ✅ Rate limiting properly configured
- ✅ Security incidents detected and logged

### Phase 3 Success
- ✅ Advanced security features operational
- ✅ Secrets properly managed
- ✅ Audit logging comprehensive
- ✅ Security posture measurable

### Phase 4 Success
- ✅ Comprehensive test suite
- ✅ Runbook complete and tested
- ✅ Metrics dashboard operational
- ✅ Security health continuously monitored

## Notes for Next Agent

1. **Start with Phase 1** - Addresses critical architecture issues
2. **Test thoroughly** - Security changes need extensive testing
3. **Document as you go** - Keep documentation in sync with changes
4. **Consider impact** - Security changes can affect functionality
5. **Maintain compatibility** - Existing deployments must continue to work

## Resources

- Current architecture: See `SECURITY_CONSOLIDATION_CURRENT_STATE.md`
- Security guide: See `SECURITY_GUIDE.md`
- Common functions: See `lib/common_functions.sh`
- Script templates: See `install/templates/install_template.sh`
