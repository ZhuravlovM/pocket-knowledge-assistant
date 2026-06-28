#!/usr/bin/env bash
set -uo pipefail

LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/uninstall.log"
mkdir -p "$LOG_DIR"

log()     { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

RESET='\033[0m'; BOLD='\033[1m'
FG_WHITE='\033[97m'; FG_CYAN='\033[96m'; FG_GREEN='\033[92m'
FG_YELLOW='\033[93m'; FG_RED='\033[91m'; FG_GRAY='\033[90m'

ok()      { echo -e "  ${FG_GREEN}✓${RESET} $*"; log "OK: $*"; }
fail()    { echo -e "  ${FG_RED}✗${RESET} $*"; log "FAIL: $*"; }
info()    { echo -e "  ${FG_CYAN}→${RESET} $*"; log "INFO: $*"; }
warn()    { echo -e "  ${FG_YELLOW}⚠${RESET} $*"; log "WARN: $*"; }
divider() { echo -e "  ${FG_GRAY}──────────────────────────────────────────────────${RESET}"; }

confirm() {
    local msg="${1:-Are you sure?}"
    read -rp "  ${msg} [y/N] " ans
    [[ "${ans,,}" == "y" ]]
}

config_models() {
    python3 -c "
from app.config import cfg
print(cfg.models.llm)
print(cfg.models.embed)
" 2>/dev/null || echo -e "qwen2.5:3b-instruct\nbge-m3"
}

# ── Actions ───────────────────────────────────────────────────────────────────

remove_index() {
    echo -e "\n  ${BOLD}Remove vector index${RESET}"
    divider

    local index_dir
    index_dir=$(python3 -c "from app.config import cfg; print(cfg.paths.index)" 2>/dev/null || echo "data/index")

    if [[ ! -d "$index_dir" || -z "$(ls -A "$index_dir" 2>/dev/null)" ]]; then
        warn "Index not found or already empty ($index_dir)"
        return
    fi

    local size
    size=$(du -sh "$index_dir" 2>/dev/null | cut -f1)
    warn "This will delete the index at $index_dir ($size)"
    confirm "Delete index?" || return

    rm -rf "$index_dir"
    ok "Index removed ($index_dir)"
    log "Removed index: $index_dir"
}

remove_models() {
    echo -e "\n  ${BOLD}Remove Ollama models${RESET}"
    divider

    if ! command -v ollama &>/dev/null || ! ollama list &>/dev/null 2>&1; then
        warn "Ollama not available"
        return
    fi

    local models=()
    while IFS= read -r line; do
        models+=("$(echo "$line" | awk '{print $1}')")
    done < <(ollama list 2>/dev/null | tail -n +2)

    if [[ ${#models[@]} -eq 0 ]]; then
        warn "No models installed"
        return
    fi

    echo
    for i in "${!models[@]}"; do
        echo -e "  ${FG_CYAN}$((i+1))${RESET}  ${models[$i]}"
    done
    echo -e "  ${FG_CYAN}a${RESET}  All models"
    echo -e "  ${FG_GRAY}q  Cancel${RESET}"
    echo

    read -rp "  › " choice

    case "$choice" in
        q|Q) return ;;
        a|A)
            confirm "Delete ALL models?" || return
            for m in "${models[@]}"; do
                if ollama rm "$m" >> "$LOG_FILE" 2>&1; then
                    ok "Removed: $m"
                else
                    fail "Failed: $m"
                fi
            done
            ;;
        *)
            local idx=$((choice - 1))
            if [[ $idx -lt 0 || $idx -ge ${#models[@]} ]]; then
                fail "Invalid selection"
                return
            fi
            local target="${models[$idx]}"
            confirm "Delete $target?" || return
            if ollama rm "$target" >> "$LOG_FILE" 2>&1; then
                ok "Removed: $target"
            else
                fail "Failed: $target"
            fi
            ;;
    esac
}

remove_venv() {
    echo -e "\n  ${BOLD}Remove virtual environment${RESET}"
    divider

    if [[ ! -d ".venv" ]]; then
        warn ".venv not found"
        return
    fi

    local size
    size=$(du -sh .venv 2>/dev/null | cut -f1)
    confirm "Delete .venv ($size)?" || return
    rm -rf .venv
    ok ".venv removed"
    log "Removed .venv"
}

remove_data() {
    echo -e "\n  ${BOLD}Remove data & logs${RESET}"
    divider

    warn "This will delete: data/index, data/cache, logs/, benchmark DB"
    confirm "Proceed?" || return

    rm -rf data/index data/cache data/benchmark.db data/benchmark_results.json
    ok "Data removed"
    log "Removed data/index, data/cache, benchmark files"
    warn "Logs cleared — this log entry is the last one"
    rm -rf logs
}

full_uninstall() {
    echo -e "\n  ${BOLD}${FG_RED}Full uninstall${RESET}"
    divider
    echo
    warn "This will remove:"
    echo "    • Ollama models referenced in config"
    echo "    • Vector index"
    echo "    • .venv"
    echo "    • Cache, logs, benchmark DB"
    echo
    warn "Your documents in data/documents will NOT be deleted."
    echo
    confirm "Proceed with full uninstall?" || { echo; return; }

    log "=== Full uninstall started ==="

    while IFS= read -r m; do
        if ollama list 2>/dev/null | grep -q "^${m}"; then
            if ollama rm "$m" >> "$LOG_FILE" 2>&1; then
                ok "Removed model: $m"
                log "Removed model: $m"
            else
                fail "Failed to remove: $m"
            fi
        fi
    done < <(config_models)

    rm -rf data/index data/cache .venv data/benchmark.db data/benchmark_results.json
    ok "Cleanup complete"
    log "Full uninstall complete"
    echo
    warn "Ollama itself was NOT uninstalled. To remove it:"
    echo "    https://ollama.com/docs/uninstall"
    warn "Logs cleared — removing log directory"
    rm -rf logs
}

# ── Menu ──────────────────────────────────────────────────────────────────────

log "=== Uninstall started ==="

echo
echo -e "  ${BOLD}${FG_WHITE}Uninstall / Cleanup${RESET}"
divider
echo

echo -e "  ${FG_CYAN}1${RESET}  Remove vector index"
echo -e "  ${FG_CYAN}2${RESET}  Remove Ollama model(s)"
echo -e "  ${FG_CYAN}3${RESET}  Remove virtual environment (.venv)"
echo -e "  ${FG_CYAN}4${RESET}  Remove data & logs"
echo -e "  ${FG_CYAN}5${RESET}  ${FG_RED}Full uninstall${RESET} (all of the above)"
echo -e "  ${FG_GRAY}q  Cancel${RESET}"
echo

read -rp "  › " choice
echo

case "$choice" in
    1) remove_index ;;
    2) remove_models ;;
    3) remove_venv ;;
    4) remove_data ;;
    5) full_uninstall ;;
    q|Q) log "Cancelled"; echo -e "  ${FG_GRAY}Cancelled.${RESET}" ;;
    *) warn "Unknown option" ;;
esac

echo
