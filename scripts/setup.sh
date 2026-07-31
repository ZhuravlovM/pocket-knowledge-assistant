#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

init_logging "logs/setup.log"

REQUIRED_DIRS=("data/documents" "data/index" "data/cache" "logs")
REQUIREMENTS_FILE="requirements.txt"
TOTAL_STEPS=6

# ── Steps ─────────────────────────────────────────────────────────────────────

do_check_python() {
    step "Python"
    check_python
}

do_setup_venv() {
    step "Virtual environment"
    setup_venv
}

do_check_ollama() {
    step "Ollama"
    check_ollama
}

install_dependencies() {
    step "Python dependencies"

    [[ -f "$REQUIREMENTS_FILE" ]] || die "$REQUIREMENTS_FILE not found"

    info "pip install -r $REQUIREMENTS_FILE"

    run_spinner \
        "Upgrading pip..." \
        pip install --quiet --upgrade pip || die "Failed to upgrade pip"

    run_spinner \
        "Installing dependencies..." \
        pip install --quiet -r "$REQUIREMENTS_FILE" || die "Failed to install dependencies"

    ok "Dependencies installed"
}

pull_model() {
    local model="$1"

    if ollama show "$model" &>/dev/null; then
        ok "$model already installed"
        log "MODEL SKIP: $model already installed"
        return
    fi

    log "MODEL DOWNLOAD START: $model"
    echo -e "  \033[34m→\033[0m Downloading model: $model"

    local start elapsed
    start=$(date +%s)

    # IMPORTANT: do NOT redirect stdout/stderr — keeps progress bar visible
    if ollama pull "$model"; then
        elapsed=$(( $(date +%s) - start ))
        ok "$model"
        log "MODEL DOWNLOAD OK: $model (${elapsed}s)"
    else
        log "MODEL DOWNLOAD FAIL: $model"
        die "Failed to download: $model"
    fi
}

pull_models() {
    step "Ollama models"

    local llm embed
    llm=$(cfg_llm_model)
    embed=$(cfg_embed_model)

    pull_model "$llm"
    pull_model "$embed"
}

create_dirs() {
    step "Directories"

    for dir in "${REQUIRED_DIRS[@]}"; do
        mkdir -p "$dir"
        ok "./$dir/"
    done
}

print_summary() {
    log "Setup completed successfully"

    echo -e "\n${BOLD}──────────────────────────────────────────────────${RESET}"
    echo -e "${FG_GREEN}  Setup completed.${RESET}  Log: ${LOG_FILE}"
    echo "  Next steps:"
    echo "    1. Put documents into $(cfg_docs_dir)/"
    echo "    2. ./run.sh  →  1 (Build index)"
    echo "    3. ./run.sh  →  2 (Start chat)"
    echo -e "${BOLD}──────────────────────────────────────────────────${RESET}\n"
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    echo -e "${BOLD}Pocket Knowledge Assistant${RESET}"
    log "=== Setup started ==="

    do_check_python
    do_setup_venv
    do_check_ollama
    install_dependencies
    pull_models
    create_dirs
    print_summary
}

main
