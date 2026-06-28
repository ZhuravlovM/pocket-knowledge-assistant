#!/usr/bin/env bash
# scripts/check_system.sh — verifies all runtime dependencies

set -uo pipefail

RESET='\033[0m'; BOLD='\033[1m'
FG_GREEN='\033[92m'; FG_RED='\033[91m'; FG_YELLOW='\033[93m'; FG_CYAN='\033[96m'; FG_GRAY='\033[90m'

ok()   { echo -e "  ${FG_GREEN}✓${RESET} $*"; }
fail() { echo -e "  ${FG_RED}✗${RESET} $*"; }
warn() { echo -e "  ${FG_YELLOW}⚠${RESET} $*"; }
info() { echo -e "  ${FG_CYAN}→${RESET} $*"; }

errors=0

echo -e "\n  ${BOLD}System check${RESET}"
echo -e "  ${FG_GRAY}──────────────────────────────────────────────────${RESET}"

# Python
if command -v python3 &>/dev/null; then
    pyver=$(python3 --version 2>&1)
    minor=$(python3 -c "import sys; print(sys.version_info.minor)")
    if [[ "$minor" -ge 11 ]]; then
        ok "$pyver"
    else
        fail "$pyver — Python 3.11+ required"
        ((errors++))
    fi
else
    fail "python3 not found"
    ((errors++))
fi

# Ollama binary
if command -v ollama &>/dev/null; then
    ok "ollama found"
else
    fail "ollama not found — install from https://ollama.com"
    ((errors++))
fi

# Ollama running
if ollama list &>/dev/null 2>&1; then
    ok "Ollama is running"
else
    warn "Ollama is not running"
fi

# Required Python packages
for pkg in llama_index yaml; do
    if python3 -c "import $pkg" &>/dev/null; then
        ok "python: $pkg"
    else
        fail "python: $pkg not installed"
        ((errors++))
    fi
done

# Config files
for f in config/config.yaml config/prompts.yaml; do
    if [[ -f "$f" ]]; then
        ok "$f"
    else
        fail "$f not found"
        ((errors++))
    fi
done

# Directories
for d in data/documents data/index logs; do
    if [[ -d "$d" ]]; then
        ok "dir: $d"
    else
        warn "dir: $d (missing — will be created on first run)"
    fi
done

echo -e "  ${FG_GRAY}──────────────────────────────────────────────────${RESET}"

if [[ $errors -eq 0 ]]; then
    echo -e "  ${FG_GREEN}All checks passed.${RESET}"
else
    echo -e "  ${FG_RED}${errors} check(s) failed. Run ./setup.sh to fix.${RESET}"
fi

echo
exit $errors
