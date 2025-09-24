# Shell Scripting Best Practices & Linting Guide

## Table of Contents
1. [Critical Requirements](#critical-requirements)
2. [Syntax and Structure](#syntax-and-structure)
3. [Error Handling](#error-handling)
4. [Variable Handling](#variable-handling)
5. [Command Execution](#command-execution)
6. [File Operations](#file-operations)
7. [User Input](#user-input)
8. [Sourcing and Dependencies](#sourcing-and-dependencies)
9. [Linting Workflow](#linting-workflow)
10. [Common Pitfalls and Fixes](#common-pitfalls-and-fixes)
11. [Production Readiness Checklist](#production-readiness-checklist)

---

## Critical Requirements

### 1. **Shebang Line (MANDATORY)**
```bash
#!/bin/bash
# NEVER: #!bin/bash (missing /)
# NEVER: #!/usr/bin/env bash (less portable for system scripts)
```
**ShellCheck Rule**: SC2239 - Ensure shebang uses absolute path

### 2. **Strict Mode (HIGHLY RECOMMENDED)**
```bash
#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'
```
- `set -e`: Exit on any command failure
- `set -u`: Exit on undefined variables
- `set -o pipefail`: Fail on pipe command failures
- `set -E`: Inherit error traps in functions
- `IFS`: Prevent word splitting issues

### 3. **Root/Non-Root Detection (WHEN NEEDED)**
```bash
# For scripts requiring root
require_root() {
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        echo "[ERROR] This script must be run as root." >&2
        exit 1
    fi
}

# For scripts requiring non-root
require_non_root() {
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        echo "[ERROR] Do not run this script as root." >&2
        exit 1
    fi
}
```

---

## Syntax and Structure

### 1. **Function Definitions**
```bash
# GOOD: Consistent function definition
function_name() {
    local param1="$1"
    local param2="$2"
    
    # Function body
    echo "Processing $param1"
}

# AVOID: Inconsistent styles
function function_name { ... }  # Mixed style
```

### 2. **Conditional Statements**
```bash
# GOOD: Consistent spacing and quoting
if [[ -f "$file" ]]; then
    echo "File exists"
elif [[ -d "$file" ]]; then
    echo "Directory exists"
else
    echo "Does not exist"
fi

# GOOD: Use [[ ]] for bash, [ ] for POSIX
if [[ "$var" == "value" ]]; then  # Bash-specific
if [ "$var" = "value" ]; then    # POSIX-compatible
```

### 3. **Loops**
```bash
# GOOD: Proper quoting in loops
for file in "$directory"/*.txt; do
    [[ -f "$file" ]] || continue  # Handle no matches
    echo "Processing: $file"
done

# GOOD: While loops with proper IFS handling
while IFS= read -r line; do
    echo "Line: $line"
done < "$input_file"
```

---

## Error Handling

### 1. **Directory Changes (CRITICAL)**
```bash
# ALWAYS: Add error handling to cd commands
cd "$directory" || exit 1
cd "$directory" || return 1  # In functions

# NEVER: Unhandled cd
cd "$directory"  # ShellCheck SC2164
```

### 2. **Command Error Checking**
```bash
# GOOD: Check command success
if ! command -v git >/dev/null 2>&1; then
    echo "Error: git not found" >&2
    exit 1
fi

# GOOD: Use error handling with critical commands
if ! curl -o file.tar.gz "$url"; then
    echo "Download failed" >&2
    exit 1
fi

# ALTERNATIVE: Use || for simple error handling
curl -o file.tar.gz "$url" || { echo "Download failed" >&2; exit 1; }
```

### 3. **Trap Handling (ADVANCED)**
```bash
# GOOD: Cleanup on script exit
cleanup() {
    rm -f "$temp_file"
    echo "Cleanup completed"
}
trap cleanup EXIT

# GOOD: Error reporting
error_handler() {
    echo "Error on line $1" >&2
    exit 1
}
trap 'error_handler $LINENO' ERR
```

---

## Variable Handling

### 1. **Variable Quoting (CRITICAL)**
```bash
# ALWAYS: Quote variables to prevent word splitting
mkdir "$HOME/directory"           # GOOD
cp "$source" "$destination"       # GOOD
echo "Value: $variable"          # GOOD

# NEVER: Unquoted variables
mkdir $HOME/directory            # BAD - SC2086
cp $source $destination          # BAD - SC2086
echo $variable                   # BAD - SC2086
```

### 2. **Variable Assignment**
```bash
# GOOD: Separate declaration and assignment
local version
version=$(get_latest_version)

export PATH
PATH="$PATH:/new/path"

# AVOID: Combined declaration and assignment (masks return values)
local version=$(get_latest_version)  # SC2155
export PATH="$PATH:/new/path"        # Can mask errors
```

### 3. **Default Values and Parameter Expansion**
```bash
# GOOD: Use parameter expansion for defaults
config_file="${CONFIG_FILE:-/etc/default.conf}"
username="${1:-$(whoami)}"

# GOOD: Check for required variables
: "${REQUIRED_VAR:?Error: REQUIRED_VAR must be set}"

# GOOD: Array handling
declare -a files=("file1.txt" "file2.txt")
for file in "${files[@]}"; do
    echo "$file"
done
```

---

## Command Execution

### 1. **Command Substitution**
```bash
# GOOD: Use $() instead of backticks
current_date=$(date +%Y-%m-%d)
file_count=$(find . -type f | wc -l)

# AVOID: Legacy backticks
current_date=`date +%Y-%m-%d`     # SC2006
```

### 2. **Pipeline Handling**
```bash
# GOOD: Handle pipeline failures with set -o pipefail
set -o pipefail
if ! curl -s "$url" | jq '.version' > version.txt; then
    echo "Pipeline failed" >&2
    exit 1
fi

# GOOD: Check intermediate results when needed
data=$(curl -s "$url")
if [[ -z "$data" ]]; then
    echo "No data received" >&2
    exit 1
fi
version=$(echo "$data" | jq -r '.version')
```

### 3. **Process Substitution (ADVANCED)**
```bash
# GOOD: Compare command outputs
if diff <(sort file1) <(sort file2) >/dev/null; then
    echo "Files have same content when sorted"
fi
```

---

## File Operations

### 1. **File Testing**
```bash
# GOOD: Proper file tests
if [[ -f "$file" ]]; then          # Regular file
if [[ -d "$directory" ]]; then     # Directory
if [[ -r "$file" ]]; then          # Readable
if [[ -w "$file" ]]; then          # Writable
if [[ -x "$file" ]]; then          # Executable

# GOOD: Test before operations
if [[ -f "$config_file" ]]; then
    source "$config_file"
else
    echo "Config file not found: $config_file" >&2
    exit 1
fi
```

### 2. **File Creation and Permissions**
```bash
# GOOD: Create files with proper permissions
umask 077  # Restrictive permissions for sensitive files
cat > "$config_file" << 'EOF'
# Configuration content
EOF
chmod 600 "$config_file"

# GOOD: Create directories with error checking
mkdir -p "$directory" || {
    echo "Failed to create directory: $directory" >&2
    exit 1
}
```

### 3. **Temporary Files**
```bash
# GOOD: Use mktemp for temporary files
temp_file=$(mktemp) || {
    echo "Failed to create temp file" >&2
    exit 1
}
trap 'rm -f "$temp_file"' EXIT

# GOOD: Temporary directories
temp_dir=$(mktemp -d) || {
    echo "Failed to create temp directory" >&2
    exit 1
}
trap 'rm -rf "$temp_dir"' EXIT
```

---

## User Input

### 1. **Read Commands**
```bash
# GOOD: Always use -r flag to prevent backslash interpretation
read -r -p "Enter your name: " username
read -r -s -p "Enter password: " password  # -s for silent input

# GOOD: Read with timeout
if ! read -r -t 30 -p "Continue? (y/n): " response; then
    echo "Timeout reached" >&2
    exit 1
fi

# NEVER: Read without -r flag
read -p "Enter name: " username  # SC2162
```

### 2. **Input Validation**
```bash
# GOOD: Validate user input
validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

read -r -p "Enter email: " email
if ! validate_email "$email"; then
    echo "Invalid email format" >&2
    exit 1
fi
```

### 3. **Menu Systems**
```bash
# GOOD: Robust menu with input validation
show_menu() {
    echo "1. Option One"
    echo "2. Option Two"
    echo "3. Exit"
}

while true; do
    show_menu
    read -r -p "Select option (1-3): " choice
    case "$choice" in
        1) echo "Option One selected"; break ;;
        2) echo "Option Two selected"; break ;;
        3) echo "Exiting"; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
done
```

---

## Sourcing and Dependencies

### 1. **Sourcing Files**
```bash
# GOOD: Check before sourcing
if [[ -f "./config.sh" ]]; then
    source "./config.sh"
else
    echo "Config file not found" >&2
    exit 1
fi

# GOOD: Use absolute paths when possible
config_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$config_dir/config.sh"
```

### 2. **Dependency Checking**
```bash
# GOOD: Check for required commands
require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: Required command '$1' not found" >&2
        exit 1
    fi
}

require_command "curl"
require_command "jq"
require_command "git"
```

### 3. **Library Functions**
```bash
# GOOD: Create reusable functions
log_info()  { printf "[INFO] %s\n" "$*"; }
log_warn()  { printf "[WARN] %s\n" "$*" >&2; }
log_error() { printf "[ERROR] %s\n" "$*" >&2; }

# GOOD: Export functions for sourcing
export -f log_info log_warn log_error
```

---

## Linting Workflow

### 1. **Essential Tools**
```bash
# Install shellcheck
sudo apt-get install shellcheck
# or
brew install shellcheck

# Basic syntax check
bash -n script.sh

# Comprehensive linting
shellcheck script.sh
```

### 2. **Shellcheck Configuration**
```bash
# Add to script header to disable specific warnings
# shellcheck disable=SC1091  # Not following sourced files
# shellcheck disable=SC2154  # Variable referenced but not assigned

# Create .shellcheckrc for project-wide settings
echo "disable=SC1091,SC2154" > .shellcheckrc
```

### 3. **Automated Linting**
```bash
# Lint all scripts in project
find . -name "*.sh" -type f -exec shellcheck {} \;

# Lint with specific format
shellcheck -f gcc *.sh  # GCC format for IDE integration
```

---

## Common Pitfalls and Fixes

### 1. **Most Common Issues Found**

| Issue | ShellCheck Code | Fix |
|-------|----------------|-----|
| Unquoted variables | SC2086 | Add quotes: `"$var"` |
| Missing cd error handling | SC2164 | Add: `cd "$dir" \|\| exit` |
| Read without -r | SC2162 | Add: `read -r` |
| Variable assignment masking | SC2155 | Separate declaration/assignment |
| Legacy backticks | SC2006 | Use: `$(command)` |
| Missing shebang | SC2148 | Add: `#!/bin/bash` |
| Wrong shebang | SC2239 | Fix: `#!/bin/bash` |

### 2. **Security Issues**
```bash
# AVOID: Command injection vulnerabilities
eval "rm $user_input"           # DANGEROUS
rm $(echo $user_input)          # DANGEROUS

# GOOD: Proper input sanitization
if [[ "$user_input" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    rm "$user_input"
else
    echo "Invalid filename" >&2
    exit 1
fi
```

### 3. **Performance Issues**
```bash
# AVOID: Inefficient loops
for file in $(ls); do           # Breaks on spaces
    echo "$file"
done

# GOOD: Proper file iteration
for file in *; do
    [[ -f "$file" ]] || continue
    echo "$file"
done

# AVOID: Repeated command calls in loops
for i in {1..100}; do
    date                        # Called 100 times
done

# GOOD: Call once, store result
current_date=$(date)
for i in {1..100}; do
    echo "$current_date"
done
```

---

## Production Readiness Checklist

### 1. **Pre-Deployment Checks**
- [ ] All scripts pass `bash -n` syntax check
- [ ] All scripts pass `shellcheck` with only acceptable warnings
- [ ] All variables are properly quoted
- [ ] All `cd` commands have error handling
- [ ] All `read` commands use `-r` flag
- [ ] All temporary files are cleaned up
- [ ] All functions have proper error handling
- [ ] All dependencies are checked before use

### 2. **Security Checklist**
- [ ] No hardcoded credentials
- [ ] Proper input validation
- [ ] No command injection vulnerabilities
- [ ] Appropriate file permissions
- [ ] Proper privilege escalation handling
- [ ] Safe temporary file creation

### 3. **Maintainability Checklist**
- [ ] Clear, descriptive function names
- [ ] Consistent code style
- [ ] Adequate comments for complex logic
- [ ] Modular design with reusable functions
- [ ] Proper logging and error messages
- [ ] Version information and documentation

### 4. **Testing Checklist**
- [ ] Unit tests for critical functions
- [ ] Integration testing with dependencies
- [ ] Error condition testing
- [ ] Performance testing for large datasets
- [ ] Cross-platform compatibility (if needed)

---

## Quick Reference Commands

### Immediate Fixes for Common Issues
```bash
# Fix all unquoted variables in a script
sed -i 's/\$\([A-Z_][A-Z0-9_]*\)/"\$\1"/g' script.sh

# Add error handling to all cd commands
sed -i 's/^[[:space:]]*cd \(.*\)$/cd \1 || exit/' script.sh

# Add -r to all read commands
sed -i 's/read -p/read -r -p/g' script.sh

# Fix shebang line
sed -i '1s|^#!.*|#!/bin/bash|' script.sh
```

### Mass Script Checking
```bash
# Check syntax of all scripts
find . -name "*.sh" -exec bash -n {} \; 2>&1 | grep -v "^$"

# Get shellcheck summary for all scripts
find . -name "*.sh" -exec shellcheck -f gcc {} \; 2>&1 | \
    awk -F: '{print $4}' | sort | uniq -c | sort -nr
```

---

## Conclusion

Following these best practices ensures:
- **Security**: Proper input validation and error handling
- **Reliability**: Robust error checking and recovery
- **Maintainability**: Clean, consistent, well-documented code
- **Portability**: POSIX compliance where possible
- **Performance**: Efficient command usage and resource management

Always remember: **A script that works is good, but a script that works reliably under all conditions is production-ready.**