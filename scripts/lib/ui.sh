#!/usr/bin/env bash
# scripts/lib/ui.sh — colors, logging, and output helpers shared by all scripts.
#
# Requires: LOG_FILE to be set (see common.sh::init_logging) before ok/fail/
# info/warn/log are called. If unset, logging is silently skipped.

# ── Colors ────────────────────────────────────────────────────────────────────

RESET='\033[0m'; BOLD='\033[1m'
FG_WHITE='\033[97m'; FG_CYAN='\033[96m'; FG_GREEN='\033[92m'
FG_YELLOW='\033[93m'; FG_RED='\033[91m'; FG_GRAY='\033[90m'

# ── Logging ───────────────────────────────────────────────────────────────────

log() {
    [[ -n "${LOG_FILE:-}" ]] || return 0
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

LOG_MAX_BYTES=1000000

init_logging() {
    LOG_FILE="$1"
    mkdir -p "$(dirname "$LOG_FILE")"

    # Keep one previous log instead of appending forever.
    if [[ -f "$LOG_FILE" ]] && (( $(wc -c < "$LOG_FILE") > LOG_MAX_BYTES )); then
        mv -f "$LOG_FILE" "${LOG_FILE}.1"
    fi
}

# ── Output helpers ────────────────────────────────────────────────────────────

ok()      { echo -e "  ${FG_GREEN}✓${RESET} $*"; log "OK: $*"; }
fail()    { echo -e "  ${FG_RED}✗${RESET} $*"; log "FAIL: $*"; }
info()    { echo -e "  ${FG_CYAN}→${RESET} $*"; log "INFO: $*"; }
warn()    { echo -e "  ${FG_YELLOW}⚠${RESET} $*"; log "WARN: $*"; }
notice()  { echo -e "  ${FG_YELLOW}⚠${RESET} $*"; }
divider() { echo -e "  ${FG_GRAY}──────────────────────────────────────────────────${RESET}"; }

pause_return() {
    local msg="${1:-Press Enter to return...}"
    read -rp "  ${msg}" _
}

# Fatal variant: report + exit. Use in place of `fail` wherever the original
# script relied on fail() terminating execution (e.g. setup.sh).
die() {
    fail "$*"
    exit 1
}

# Section header (non-numbered), e.g. "── Python ──"
header() {
    echo -e "\n${BOLD}$*${RESET}"
    log "── $* ──"
}

# Numbered step header. Requires TOTAL_STEPS to be set by the caller;
# CURRENT_STEP is tracked internally.
CURRENT_STEP=0
step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    header "[$CURRENT_STEP/${TOTAL_STEPS:-?}] $*"
}

# App banner box, e.g. used by run.sh's main menu screen.
banner() {
    local title="$1" subtitle="$2"
    clear
    echo
    echo -e "  ${BOLD}${FG_WHITE}╭─────────────────────────────────────────────────╮${RESET}"
    printf "  ${BOLD}${FG_WHITE}│${RESET}  ${FG_CYAN}${BOLD}◆  %-44s${RESET}${BOLD}${FG_WHITE}│${RESET}\n" "$title"
    printf "  ${BOLD}${FG_WHITE}│${RESET}  ${FG_GRAY}%-47s${RESET}${BOLD}${FG_WHITE}│${RESET}\n" "$subtitle"
    echo -e "  ${BOLD}${FG_WHITE}╰─────────────────────────────────────────────────╯${RESET}"
    echo
}

# App exit screen.
exit_app() {
    clear
    echo -e "  ${FG_GRAY}Goodbye.${RESET}"
    echo
}

confirm() {
    local msg="${1:-Are you sure?}"
    read -rp "  ${msg} [y/N] " ans
    [[ "${ans,,}" == "y" ]]
}

# ── Spinner ───────────────────────────────────────────────────────────────────

spinner() {
    local pid=$1
    local msg=$2

    [[ -t 1 && -w /dev/tty ]] || return 0

    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  %s %s" "${frames[i]}" "$msg" > /dev/tty
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.1
    done

    printf "\r\033[K" > /dev/tty
}

# Runs a command in the background with a spinner, logging its output.
# Usage: run_spinner "Installing..." pip install -r requirements.txt
run_spinner() {
    local msg="$1"
    shift

    # Callers without file logging (run.sh) leave LOG_FILE unset — discard there.
    "$@" >> "${LOG_FILE:-/dev/null}" 2>&1 &
    local pid=$!

    spinner "$pid" "$msg"

    wait "$pid"
}
