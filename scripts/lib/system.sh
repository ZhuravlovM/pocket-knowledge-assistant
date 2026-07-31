#!/usr/bin/env bash
# scripts/lib/system.sh — Ollama and system dependency checks.

# Verifies the ollama binary is installed. Fatal on failure.
check_ollama() {
    command -v ollama &>/dev/null || die "Ollama not found — install from https://ollama.com"
    ok "Ollama found"
}

# True if the ollama daemon is up and responding.
ollama_running() {
    ollama list &>/dev/null 2>&1
}

# Ensures ollama is installed and running, starting the daemon if needed.
# Non-fatal — returns 1 (and prints failures) instead of exiting, so callers
# like run.sh can decide how to react.
ensure_ollama_running() {
    local missing=0

    if ! command -v ollama &>/dev/null; then
        fail "ollama not found"
        return 1
    fi

    if ! ollama_running; then
        warn "Ollama not running — starting it..."
        ollama serve &>/dev/null &
        sleep 3
        if ollama_running; then
            ok "Ollama started"
        else
            fail "Ollama not responding"
            missing=1
        fi
    fi

    return $missing
}

# Checks python3 + project files are in place. Non-fatal; returns count of
# missing prerequisites.
check_deps() {
    local missing=0

    command -v python3 &>/dev/null || { fail "python3 not found"; missing=1; }
    ensure_ollama_running || missing=1
    [[ -f "app/config.py" ]] || { fail "app/config.py not found — run from project root"; missing=1; }

    return $missing
}

# Checks a list of importable python packages, reporting each. Returns count
# of failures.
check_python_packages() {
    local errors=0
    for pkg in "$@"; do
        if python3 -c "import $pkg" &>/dev/null; then
            ok "python: $pkg"
        else
            fail "python: $pkg not installed"
            errors=$((errors + 1))
        fi
    done
    return $errors
}

# Checks a list of files exist, reporting each. Returns count of failures.
check_files_exist() {
    local errors=0
    for f in "$@"; do
        if [[ -f "$f" ]]; then
            ok "$f"
        else
            fail "$f not found"
            errors=$((errors + 1))
        fi
    done
    return $errors
}

# Checks a list of directories exist, warning (non-fatal) for each missing one.
check_dirs_exist() {
    for d in "$@"; do
        if [[ -d "$d" ]]; then
            ok "dir: $d"
        else
            warn "dir: $d (missing — will be created on first run)"
        fi
    done
}
