#!/usr/bin/env bash
# scripts/lib/python.sh — Python version check and virtualenv management.

MIN_PYTHON_MINOR=11
VENV_DIR=".venv"

# Verifies python3 exists and meets MIN_PYTHON_MINOR. Fatal on failure.
check_python() {
    command -v python3 &>/dev/null || die "python3 not found"

    local minor major
    minor=$(python3 -c "import sys; print(sys.version_info.minor)")
    major=$(python3 -c "import sys; print(sys.version_info.major)")

    [[ "$major" -gt 3 || ( "$major" -eq 3 && "$minor" -ge "$MIN_PYTHON_MINOR" ) ]] \
        || die "Python 3.${MIN_PYTHON_MINOR}+ required, found ${major}.${minor}"

    ok "Python ${major}.${minor}"
}

# Creates .venv if missing, then activates it. Fatal on failure.
setup_venv() {
    if [[ -d "$VENV_DIR" ]]; then
        info "$VENV_DIR already exists — reusing"
    else
        python3 -m venv "$VENV_DIR" && ok "$VENV_DIR created" || die "Failed to create $VENV_DIR"
    fi

    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate" || die "Failed to activate $VENV_DIR"

    ok "venv activated"
}

# Activates .venv only if it exists and isn't already active. Non-fatal —
# intended for scripts (like run.sh) that can proceed without one.
activate_venv_if_present() {
    if [[ -d "$VENV_DIR" && -z "${VIRTUAL_ENV:-}" ]]; then
        # shellcheck disable=SC1091
        source "$VENV_DIR/bin/activate" && ok "venv activated" || true
    fi
}
