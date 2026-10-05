#!/usr/bin/env bash
# shellcheck source=/dev/null
#
# la.sh -- entry point for log analyser scritpt
#
#

set -euo pipefail

VERSION="1.0.0"
PROG_NAME="$(basename "$0")" 

DATE="$(date +%Y_%m_%d)"
SCRIPT_DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)

export SCRIPT_DIR
export DATE
export PROG_NAME
export PROG_LOGS_DIR=${PROG_LOGS_DIR:-"$HOME/.local/state/$PROG_NAME/logs"}


export AI_ENABLED=0    # 0 for false | * ~ 1 for pass
export LOG_PATH=""
export ALL_FILES=()


# error codes
export ERROR_WARNING=1
export ERROR_FATAL=2
export ERROR_OK=0
export ERROR_USAGE=3

# file paths
readonly lib_path="$SCRIPT_DIR/lib"
readonly tests_path="$SCRIPT_DIR/tests"


launch_prompt() {
    read -rp "enter logs directory: " LOG_PATH || {
        error "read log path from prompt failed"
        exit $ERROR_USAGE
    }

    read -rp "enable AI-assisted verdict? (y/n): " ai_choice || {
        error "read AI choice from prompt failed"
        exit $ERROR_USAGE
    }

    [[ "$ai_choice" =~ ^[Yy]$ ]] && AI_ENABLED=1 || AI_ENABLED=0
}
# source library scripts
for script in "$lib_path"/*; do
    source "$script" || {
        error "failed to source $script"
        exit $ERROR_USAGE
    }
done

main() {
    parse_args "$@" || { error "flag parsing failed"; }
    validate_dir "$LOG_PATH" || { error "failed to validate $LOG_PATH"; }
}

main "$@"