#!/usr/bin/env bash
# scripts/lib/common.sh — single entry point for shared shell libraries.
#
# Usage from any script in scripts/ or the project root:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib/common.sh"      # if script lives in scripts/
#   source "${SCRIPT_DIR}/scripts/lib/common.sh"  # if script lives at root
#
# Then call init_logging "logs/whatever.log" before using ok/fail/info/warn/log.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/ui.sh
source "${LIB_DIR}/ui.sh"
# shellcheck source=scripts/lib/config.sh
source "${LIB_DIR}/config.sh"
# shellcheck source=scripts/lib/python.sh
source "${LIB_DIR}/python.sh"
# shellcheck source=scripts/lib/system.sh
source "${LIB_DIR}/system.sh"
