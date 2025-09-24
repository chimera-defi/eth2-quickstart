# Documentation Index

This directory contains all documentation for the Ethereum Node Setup project.

## Core Documentation

### Setup and Workflow
- **[GLOSSARY.md](GLOSSARY.md)** - Key terminology and concepts
- **[SCRIPTS.md](SCRIPTS.md)** - Detailed script reference and usage
- **[WORKFLOW.md](WORKFLOW.md)** - End-to-end setup workflow guide

## Development & Project Management

### Best Practices
- **[best-practices/SHELL_SCRIPTING_BEST_PRACTICES_AND_LINTING_GUIDE.md](../docs/best-practices/SHELL_SCRIPTING_BEST_PRACTICES_AND_LINTING_GUIDE.md)** - Shell scripting standards, linting rules, and development guidelines

### Configuration Architecture
- **[configuration/CONFIGURATION_GUIDE.md](../docs/configuration/CONFIGURATION_GUIDE.md)** - How configuration management works across all clients

### Development Progress & Refactoring
- **[development/progress.md](../docs/development/progress.md)** - Current development status and roadmap
- **[development/REFACTORING_CONFIGS.md](../docs/development/REFACTORING_CONFIGS.md)** - Configuration refactoring details
- **[development/REFACTORING_SUMMARY.md](../docs/development/REFACTORING_SUMMARY.md)** - Summary of refactoring work completed

### Testing & Validation
- **[testing/COMPREHENSIVE_SCRIPT_TESTING_REPORT.md](../docs/testing/COMPREHENSIVE_SCRIPT_TESTING_REPORT.md)** - Comprehensive testing results and validation
- **[testing/SHELL_SCRIPT_TEST_RESULTS.md](../docs/testing/SHELL_SCRIPT_TEST_RESULTS.md)** - Shell script specific test results
- **[testing/FINAL_VERIFICATION.md](../docs/testing/FINAL_VERIFICATION.md)** - Final verification and quality assurance

### Project Management
- **[project-management/COMMIT_MESSAGES.md](../docs/project-management/COMMIT_MESSAGES.md)** - Commit message standards and history
- **[project-management/CONSOLIDATED_PR.md](../docs/project-management/CONSOLIDATED_PR.md)** - Pull request documentation and tracking

## Agent Guidance

When working on this project:

1. **Before making changes**: Review the best practices guide and existing configuration architecture
2. **During development**: Follow shell scripting standards and update progress documentation
3. **Before committing**: Run tests and update testing documentation
4. **For refactoring**: Update the refactoring summary and configuration guides
5. **For new features**: Add to the appropriate documentation category

## File Organization Standards

- **Core docs**: Essential user-facing documentation stays in `/docs/`
- **Generated docs**: Development artifacts moved to subdirectories by category
- **References**: All scripts include references to relevant documentation
- **Updates**: Keep this index current when adding new documentation