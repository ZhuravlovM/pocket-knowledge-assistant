#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

init_logging "logs/uninstall.log"

# ── Actions ───────────────────────────────────────────────────────────────────

remove_index() {
    echo -e "\n  ${BOLD}Remove vector index${RESET}"
    divider

    local index_dir
    index_dir=$(cfg_index_dir)

    if [[ ! -d "$index_dir" || -z "$(ls -A "$index_dir" 2>/dev/null)" ]]; then
        warn "Index not found or already empty ($index_dir)"
        return
    fi

    local size
    size=$(du -sh "$index_dir" 2>/dev/null | cut -f1)
    notice "This will delete the index at $index_dir ($size)"
    confirm "Delete index?" || return

    rm -rf "$index_dir"
    ok "Index removed ($index_dir)"
    log "INDEX REMOVE OK: $index_dir"
}

remove_models() {
    echo -e "\n  ${BOLD}Remove Ollama models${RESET}"
    divider

    if ! command -v ollama &>/dev/null || ! ollama_running; then
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
                if ollama rm "$m" 2>/dev/null; then
                    ok "Removed: $m"
                    log "MODEL REMOVE OK: $m"
                else
                    fail "Failed: $m"
                    log "MODEL REMOVE FAILED: $m"
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
            if ollama rm "$target" 2>/dev/null; then
                ok "Removed: $target"
                log "MODEL REMOVE OK: $target"
            else
                fail "Failed: $target"
                log "MODEL REMOVE FAILED: $target"
            fi
            ;;
    esac
}

remove_venv() {
    echo -e "\n  ${BOLD}Remove virtual environment${RESET}"
    divider

    if [[ ! -d "$VENV_DIR" ]]; then
        warn "$VENV_DIR not found"
        return
    fi

    local size
    size=$(du -sh "$VENV_DIR" 2>/dev/null | cut -f1)
    confirm "Delete $VENV_DIR ($size)?" || return

    rm -rf "$VENV_DIR"
    ok "$VENV_DIR removed"
    log "VENV REMOVE OK: $VENV_DIR"
}

remove_data() {
    echo -e "\n  ${BOLD}Remove data & logs${RESET}"
    divider

    warn "This will delete: data/index, data/cache, logs/, benchmark DB"
    confirm "Proceed?" || return

    rm -rf data/index data/cache data/benchmark.db data/benchmark_results.json
    ok "Data removed"
    log "DATA REMOVE OK: Removed data/index, data/cache, data/benchmark.db, data/benchmark_results.json"
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
    echo "    • $VENV_DIR"
    echo "    • Cache, logs, benchmark DB"
    echo
    warn "Your documents in data/documents will NOT be deleted."
    echo
    confirm "Proceed with full uninstall?" || { echo; return; }

    log "=== Full uninstall started ==="

    while IFS= read -r m; do
        if ollama list 2>/dev/null | grep -q "^${m}"; then
            if ollama rm "$m" 2>/dev/null; then
                ok "Removed model: $m"
                log "MODEL REMOVE OK: $m"
            else
                fail "Failed to remove: $m"
                log "MODEL REMOVE FAILED: $m"
            fi
        fi
    done < <(cfg_models)

    rm -rf data/index data/cache "$VENV_DIR" data/benchmark.db data/benchmark_results.json
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
    q|Q|exit|quit) break ;;
    *) warn "Unknown option: $choice"; sleep 1 ;;
esac

echo
