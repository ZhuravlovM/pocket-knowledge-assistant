#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/setup.log"
mkdir -p "$LOG_DIR"

# ── Logging ───────────────────────────────────────────────────────────────────

log()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }
ok()     { echo -e "  \033[32m✓\033[0m $*"; log "OK: $*"; }
fail()   { echo -e "  \033[31m✗\033[0m $*"; log "FAIL: $*"; exit 1; }
info()   { echo -e "  \033[34m→\033[0m $*"; log "INFO: $*"; }
header() { echo -e "\n\033[1m$*\033[0m"; log "── $* ──"; }

# ── Config ────────────────────────────────────────────────────────────────────

REQUIRED_DIRS=("data/documents" "data/index" "data/cache" "logs")
REQUIREMENTS_FILE="requirements.txt"
MIN_PYTHON_MINOR=11
VENV_DIR=".venv"

# ── Steps ─────────────────────────────────────────────────────────────────────

check_python() {
    header "Python"
    command -v python3 &>/dev/null || fail "python3 not found"

    local minor major
    minor=$(python3 -c "import sys; print(sys.version_info.minor)")
    major=$(python3 -c "import sys; print(sys.version_info.major)")

    [[ "$major" -ge 3 && "$minor" -ge "$MIN_PYTHON_MINOR" ]] \
        || fail "Python 3.${MIN_PYTHON_MINOR}+ required, found ${major}.${minor}"

    ok "Python ${major}.${minor}"
}

setup_venv() {
    header "Virtual environment"

    if [[ -d "$VENV_DIR" ]]; then
        info "$VENV_DIR already exists — reusing"
    else
        python3 -m venv "$VENV_DIR" && ok "$VENV_DIR created"
    fi

    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"

    ok "venv activated"
}

check_ollama() {
    header "Ollama"
    command -v ollama &>/dev/null || fail "Ollama not found — install from https://ollama.com"
    ok "Ollama found"
}

install_dependencies() {
    header "Python dependencies"

    [[ -f "$REQUIREMENTS_FILE" ]] || fail "$REQUIREMENTS_FILE not found"

    info "pip install -r $REQUIREMENTS_FILE"

    pip install --quiet --upgrade pip >> "$LOG_FILE" 2>&1
    pip install --quiet -r "$REQUIREMENTS_FILE" >> "$LOG_FILE" 2>&1

    ok "Dependencies installed"
}

pull_model() {
    local model="$1"

    # avoid re-downloads (keeps log clean + faster setup)
    if ollama show "$model" &>/dev/null; then
        ok "$model already installed"
        log "MODEL SKIP: $model already installed"
        return
    fi

    info "ollama pull $model"
    log "MODEL DOWNLOAD START: $model"

    local start elapsed
    start=$(date +%s)

    # IMPORTANT: do NOT redirect stdout/stderr → keeps progress bar visible
    if ollama pull "$model"; then
        elapsed=$(( $(date +%s) - start ))
        ok "$model"
        log "MODEL DOWNLOAD OK: $model (${elapsed}s)"
    else
        log "MODEL DOWNLOAD FAIL: $model"
        fail "Failed to download: $model"
    fi
}

pull_models() {
    header "Ollama models"

    local llm embed
    llm=$(python3 -c "from app.config import cfg; print(cfg.models.llm)" 2>/dev/null || echo "qwen2.5:3b-instruct")
    embed=$(python3 -c "from app.config import cfg; print(cfg.models.embed)" 2>/dev/null || echo "bge-m3")

    pull_model "$llm"
    pull_model "$embed"
}

create_dirs() {
    header "Directories"

    for dir in "${REQUIRED_DIRS[@]}"; do
        mkdir -p "$dir"
        ok "./$dir/"
    done
}

print_summary() {
    log "Setup completed successfully"

    echo -e "\n\033[1m──────────────────────────────────────────────────\033[0m"
    echo -e "\033[32m  Setup completed.\033[0m  Log: ${LOG_FILE}"
    echo "  Next steps:"
    echo "    1. Put documents into ./data/documents/"
    echo "    2. ./run.sh  →  1 (Build index)"
    echo "    3. ./run.sh  →  2 (Start chat)"
    echo -e "\033[1m──────────────────────────────────────────────────\033[0m\n"
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    echo -e "\033[1mSetting up RAG project\033[0m"
    log "=== Setup started ==="

    check_python
    setup_venv
    check_ollama
    install_dependencies
    pull_models
    create_dirs
    print_summary
}

main
