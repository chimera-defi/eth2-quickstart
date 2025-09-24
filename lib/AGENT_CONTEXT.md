# Agent Context for Ethereum Node Setup

## Quick Reference for AI Agents

### Documentation Location
All project documentation is organized in the `docs/` folder. Key files include:

- **Configuration**: `docs/CONFIGURATION_GUIDE.md` - Architecture and conventions
- **Scripting Standards**: `docs/SHELL_SCRIPTING_BEST_PRACTICES_AND_LINTING_GUIDE.md` - Best practices
- **Testing**: `docs/COMPREHENSIVE_SCRIPT_TESTING_REPORT.md` - Test results and validation
- **Refactoring**: `docs/REFACTORING_SUMMARY.md` - Recent changes and improvements

### Code Architecture
- **Configuration**: Centralized in `exports.sh`, templates in `configs/`
- **Common Functions**: Shared utilities in `lib/common_functions.sh`
- **Client Support**: 5 execution clients + 6 consensus clients
- **Installation Scripts**: Individual scripts for each client

### Key Patterns
1. **Template + Custom**: Base configs merged with user variables
2. **Common Functions**: Reusable utilities to avoid code duplication
3. **Strict Shell Mode**: All scripts use `set -Eeuo pipefail`
4. **Standardized Logging**: Colored output with consistent messaging

### When Modifying Scripts
1. Follow shell scripting best practices from `docs/SHELL_SCRIPTING_BEST_PRACTICES_AND_LINTING_GUIDE.md`
2. Use functions from `lib/common_functions.sh` when possible
3. Maintain configuration consistency per `docs/CONFIGURATION_GUIDE.md`
4. Test changes and update documentation as needed

### Client Installation Flow
1. Check system requirements
2. Download and verify client binaries
3. Create configuration from templates + user variables
4. Set up systemd services
5. Start and verify services

For detailed information, refer to the appropriate documentation files in the `docs/` folder.