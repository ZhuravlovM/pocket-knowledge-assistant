#!/usr/bin/env bash
set -uo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────

RESET='\033[0m'; BOLD='\033[1m'
FG_WHITE='\033[97m'; FG_CYAN='\033[96m'; FG_GREEN='\033[92m'
FG_YELLOW='\033[93m'; FG_RED='\033[91m'; FG_GRAY='\033[90m'

ok()      { echo -e "  ${FG_GREEN}✓${RESET} $*"; }
fail()    { echo -e "  ${FG_RED}✗${RESET} $*"; }
info()    { echo -e "  ${FG_CYAN}→${RESET} $*"; }
warn()    { echo -e "  ${FG_YELLOW}⚠${RESET} $*"; }
divider() { echo -e "  ${FG_GRAY}──────────────────────────────────────────────────${RESET}"; }

header() {
    clear
    echo
    echo -e "  ${BOLD}${FG_WHITE}╭─────────────────────────────────────────────────╮${RESET}"
    echo -e "  ${BOLD}${FG_WHITE}│${RESET}  ${FG_CYAN}${BOLD}◆ RAG Documentation Chat${RESET}                       ${BOLD}${FG_WHITE}│${RESET}"
    echo -e "  ${BOLD}${FG_WHITE}│${RESET}  ${FG_GRAY}Local AI assistant powered by Ollama${RESET}           ${BOLD}${FG_WHITE}│${RESET}"
    echo -e "  ${BOLD}${FG_WHITE}╰─────────────────────────────────────────────────╯${RESET}"
    echo
}

# ── Status bar ────────────────────────────────────────────────────────────────

status_bar() {
    local model index_status doc_count

    model=$(python3 -c "from app.config import cfg; print(cfg.models.llm)" 2>/dev/null || echo "unknown")

    if ! ollama list 2>/dev/null | grep -q "^${model}"; then
        model="${model} (not pulled)"
    fi

    doc_count=$(find data/documents -type f 2>/dev/null | wc -l | tr -d ' ')

    local index_dir
    index_dir=$(python3 -c "from app.config import cfg; print(cfg.paths.index)" 2>/dev/null || echo "data/index")

    if [[ -d "$index_dir" && -n "$(find "$index_dir" -type f -print -quit 2>/dev/null)" ]]; then
        index_status="ready"
    else
        index_status="not built"
    fi

    echo -e "  ${FG_GRAY}model${RESET} ${FG_CYAN}${model}${RESET}   ${FG_GRAY}docs${RESET} ${FG_CYAN}${doc_count}${RESET}   ${FG_GRAY}index${RESET} ${FG_CYAN}${index_status}${RESET}"
    divider
}

# ── Dependency checks ─────────────────────────────────────────────────────────

check_deps() {
    local missing=0

    command -v python3 &>/dev/null || { fail "python3 not found"; missing=1; }
    command -v ollama &>/dev/null  || { fail "ollama not found";  missing=1; }
    [[ -f "app/config.py" ]]       || { fail "app/config.py not found — run from project root"; missing=1; }

    if ! ollama list &>/dev/null 2>&1; then
        warn "Ollama not running — starting it..."
        ollama serve &>/dev/null &
        sleep 3
        if ollama list &>/dev/null 2>&1; then ok "Ollama started"; else
            fail "Ollama not responding"; missing=1
        fi
    fi

    return $missing
}

check_venv() {
    if [[ -d .venv && -z "${VIRTUAL_ENV:-}" ]]; then
        source .venv/bin/activate && ok "venv activated" || true
    fi
}

check_index() {
    local index_dir
    index_dir=$(python3 -c "from app.config import cfg; print(cfg.paths.index)" 2>/dev/null || echo "data/index")
    [[ -d "$index_dir" && -n "$(ls -A "$index_dir" 2>/dev/null)" ]]
}

# ── Actions ───────────────────────────────────────────────────────────────────

action_build_index() {
    header
    echo -e "  ${BOLD}Build index${RESET}"
    divider
    echo

    local default_docs
    default_docs=$(python3 -c "from app.config import cfg; print(cfg.paths.documents)" 2>/dev/null || echo "data/documents")
    echo -e "  ${FG_GRAY}Documents path:${RESET} ${FG_CYAN}${default_docs}${RESET}"
    read -rp "  Change path? (Enter = keep current): " custom_docs
    echo

    local docs_dir="${custom_docs:-$default_docs}"

    if [[ ! -d "$docs_dir" || -z "$(find "$docs_dir" -type f 2>/dev/null | head -1)" ]]; then
        fail "Directory '$docs_dir' is empty or does not exist"
        echo
        read -rp "  Press Enter to return..." _
        return
    fi

    ok "Using: $docs_dir"
    echo

    if check_index; then
        warn "Index already exists."
        read -rp "  Rebuild? [y/N] " confirm
        echo
        [[ "${confirm,,}" != "y" ]] && return
        local index_dir
        index_dir=$(python3 -c "from app.config import cfg; print(cfg.paths.index)" 2>/dev/null || echo "data/index")
        rm -rf "$index_dir"
    fi

    python3 -m app.build_index --docs "$docs_dir"
    echo
    ok "Done"
    echo
    read -rp "  Press Enter to return..." _
}

action_start_chat() {
    header
    echo -e "  ${BOLD}Start chat${RESET}"
    divider
    echo

    if ! check_index; then
        fail "Index not built — select option 1 first"
        echo
        read -rp "  Press Enter to return..." _
        return
    fi

    python3 -m app.rag_chat
    echo
    read -rp "  Press Enter to return..." _
}

action_status() {
    header
    echo -e "  ${BOLD}Status${RESET}"
    divider
    python3 -m app.status
    read -rp "  Press Enter to return..." _
}

action_benchmark() {
    header
    echo -e "  ${BOLD}Benchmark / Parameter tuning${RESET}"
    divider
    echo

    if ! python3 -c "import optuna" &>/dev/null; then
        warn "optuna not installed"
        read -rp "  Install now? [y/N] " confirm
        echo
        [[ "${confirm,,}" == "y" ]] || return
        pip install optuna --quiet && ok "optuna installed" || { fail "Install failed"; return; }
    fi

    local trials
    read -rp "  Number of trials [20]: " trials
    trials="${trials:-20}"
    echo

    warn "Each trial takes ~3 min on CPU. Do not close the terminal."
    read -rp "  Start? [y/N] " confirm
    echo
    [[ "${confirm,,}" != "y" ]] && return

    python3 -m app.benchmark --trials "$trials"
    echo
    read -rp "  Press Enter to return..." _
}

action_setup() {
    header
    echo -e "  ${BOLD}Environment setup${RESET}"
    divider
    echo
    bash scripts/setup.sh
    echo
    read -rp "  Press Enter to return..." _
}

action_uninstall() {
    header
    bash scripts/uninstall.sh
    read -rp "  Press Enter to return..." _
}

# ── Main menu ─────────────────────────────────────────────────────────────────

menu() {
    while true; do
        header
        status_bar
        echo
        echo -e "  ${BOLD}What do you want to do?${RESET}"
        echo
        echo -e "  ${FG_CYAN}1${RESET}  ${FG_WHITE}Build index${RESET}            ${FG_GRAY}data/documents → data/index${RESET}"
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

    clear
    echo -e "  ${FG_GRAY}Goodbye.${RESET}"
    echo
}

# ── Entry ─────────────────────────────────────────────────────────────────────

main() {
    check_venv

    if ! check_deps; then
        echo
        warn "Run ./setup.sh to install dependencies"
        echo
        exit 1
    fi

    menu
}

main
