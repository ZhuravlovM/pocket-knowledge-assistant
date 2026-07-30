#!/usr/bin/env bash
# scripts/check_system.sh — verifies all runtime dependencies

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# No file logging for this script — LOG_FILE left unset, log() becomes a no-op.

errors=0

echo -e "\n  ${BOLD}System check${RESET}"
divider

# Python
if command -v python3 &>/dev/null; then
    pyver=$(python3 --version 2>&1)
    major=$(python3 -c "import sys; print(sys.version_info.major)")
    minor=$(python3 -c "import sys; print(sys.version_info.minor)")
    if [[ "$major" -gt 3 || ( "$major" -eq 3 && "$minor" -ge "$MIN_PYTHON_MINOR" ) ]]; then
        ok "$pyver"
    else
        fail "$pyver — Python 3.${MIN_PYTHON_MINOR}+ required"
        errors=$((errors + 1))
    fi
else
    fail "python3 not found"
    errors=$((errors + 1))
fi

# Ollama binary
if command -v ollama &>/dev/null; then
    ok "ollama found"
else
    fail "ollama not found — install from https://ollama.com"
    errors=$((errors + 1))
fi

# Ollama running
if ollama_running; then
    ok "Ollama is running"
else
    warn "Ollama is not running"
fi

# Required Python packages
check_python_packages llama_index yaml || errors=$((errors + $?))

# Config files
check_files_exist config/config.yaml config/prompts.yaml || errors=$((errors + $?))

# Directories
check_dirs_exist data/documents data/index logs

divider

if [[ $errors -eq 0 ]]; then
    echo -e "  ${FG_GREEN}All checks passed.${RESET}"
else
    echo -e "  ${FG_RED}${errors} check(s) failed. Run ./setup.sh to fix.${RESET}"
fi

echo
exit $errors
