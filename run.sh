#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/scripts/lib/common.sh"

# No file logging for this script — LOG_FILE left unset, log() becomes a no-op.

header() {
    banner "Pocket Knowledge Assistant" "Local AI assistant powered by Ollama"
}

# ── Status bar ────────────────────────────────────────────────────────────────

status_bar() {
    local model index_status doc_count

    model=$(cfg_llm_model)
    if ! ollama list 2>/dev/null | grep -q "^${model}"; then
        model="${model} (not pulled)"
    fi

    doc_count=$(find "$(cfg_docs_dir)" -type f 2>/dev/null | wc -l | tr -d ' ')

    if check_index; then
        index_status="ready"
    else
        index_status="not built"
    fi

    echo -e "  ${FG_GRAY}model${RESET} ${FG_CYAN}${model}${RESET}   ${FG_GRAY}docs${RESET} ${FG_CYAN}${doc_count}${RESET}   ${FG_GRAY}index${RESET} ${FG_CYAN}${index_status}${RESET}"
    divider
}

check_index() {
    local index_dir
    index_dir=$(cfg_index_dir)
    [[ -d "$index_dir" && -n "$(find "$index_dir" -type f -print -quit 2>/dev/null)" ]]
}

# ── Actions ───────────────────────────────────────────────────────────────────

action_build_index() {
    header
    echo -e "  ${BOLD}Build index${RESET}"
    divider
    echo

    local default_docs
    default_docs=$(cfg_docs_dir)
    echo -e "  ${FG_GRAY}Documents path:${RESET} ${FG_CYAN}${default_docs}${RESET}"
    read -rp "  Change path? (Enter = keep current, 'q' to cancel): " custom_docs
    echo

    if [[ "${custom_docs,,}" == "q" ]]; then
        echo
        pause_return
        return
    fi

    local docs_dir="${custom_docs:-$default_docs}"

    if [[ ! -d "$docs_dir" || -z "$(find "$docs_dir" -type f 2>/dev/null | head -1)" ]]; then
        fail "Directory '$docs_dir' is empty or does not exist"
        echo
        pause_return
        return
    fi

    ok "Using: $docs_dir"
    echo

    if check_index; then
        warn "Index already exists."
        confirm "Rebuild?" || { echo; return; }
        echo
        rm -rf "$(cfg_index_dir)"
    fi

    if python3 -m app.build_index --docs "$docs_dir"; then
        echo
        ok "Done"
    else
        echo
        fail "Index build failed"
    fi

    echo
    pause_return
}

action_start_chat() {
    header
    echo -e "  ${BOLD}Start chat${RESET}"
    divider
    echo

    if ! check_index; then
        fail "Index not built — select option 1 first"
        echo
        pause_return
        return
    fi

    python3 -m app.rag_chat
    echo
    pause_return
}

action_status() {
    header
    echo -e "  ${BOLD}Status${RESET}"
    divider
    python3 -m app.status
    pause_return
}

action_benchmark() {
    header
    echo -e "  ${BOLD}Benchmark / Parameter tuning${RESET}"
    divider
    echo

    if ! python3 -c "import optuna" &>/dev/null; then
        warn "optuna not installed"
        confirm "Install now?" || { echo; return; }
        echo
        if ! python3 -m pip install optuna --quiet; then
            fail "Install failed"
            return
        fi
        ok "optuna installed"
    fi

    local trials
    read -rp "  Number of trials [20]: " trials
    trials="${trials:-20}"
    echo

    warn "Each trial takes ~3 min on CPU. Do not close the terminal."
    confirm "Start?" || { echo; return; }
    echo

    python3 -m app.benchmark --trials "$trials"
    echo
    pause_return
}

action_setup() {
    header
    echo -e "  ${BOLD}Environment setup${RESET}"
    divider
    echo
    bash scripts/setup.sh
    echo
    pause_return
}

action_uninstall() {
    header
    bash scripts/uninstall.sh
    pause_return
}

# ── Main menu ─────────────────────────────────────────────────────────────────

menu() {
    while true; do
        header
        status_bar
        echo
        echo -e "  ${BOLD}What would you like to do?${RESET}"
        echo
        echo -e "  ${FG_CYAN}1${RESET}  ${FG_WHITE}Build index${RESET}            ${FG_GRAY}$(cfg_docs_dir) → $(cfg_index_dir)${RESET}"
        echo -e "  ${FG_CYAN}2${RESET}  ${FG_WHITE}Start chat${RESET}             ${FG_GRAY}ask questions about docs${RESET}"
        echo -e "  ${FG_CYAN}3${RESET}  ${FG_WHITE}Status${RESET}                 ${FG_GRAY}models, docs, index${RESET}"
        echo -e "  ${FG_CYAN}4${RESET}  ${FG_WHITE}Benchmark${RESET}              ${FG_GRAY}tune Ollama parameters${RESET}"
        echo -e "  ${FG_CYAN}5${RESET}  ${FG_WHITE}Environment setup${RESET}      ${FG_GRAY}setup.sh${RESET}"
        echo -e "  ${FG_CYAN}6${RESET}  ${FG_WHITE}Uninstall${RESET}              ${FG_GRAY}remove models, index, venv${RESET}"
        echo
        divider
        echo -e "  ${FG_GRAY}q  exit${RESET}"
        echo

        read -rp "  › " choice
        echo

        case "$choice" in
            1) action_build_index ;;
            2) action_start_chat ;;
            3) action_status ;;
            4) action_benchmark ;;
            5) action_setup ;;
            6) action_uninstall ;;
            q|Q|exit|quit) break ;;
            *) warn "Unknown command: $choice"; sleep 1 ;;
        esac
    done

    exit_app
}

# ── Entry ─────────────────────────────────────────────────────────────────────

main() {
    activate_venv_if_present

    if ! check_deps; then
        echo
        warn "Run ./setup.sh to install dependencies"
        echo
        exit 1
    fi

    menu
}

main
