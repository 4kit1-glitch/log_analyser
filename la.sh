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

# form user
export AI_ENABLED=0    # 0 for false | * ~ 1 for pass
export LOG_PATH=""
export ALL_FILES=()


# error codes
export ERROR_WARNING=1
export ERROR_FATAL=2
export ERROR_OK=0
export ERROR_USAGE=3
export ERROR_NO_LOG=4


# log specific vars
export BAD_LOGS_COUNT=0         # logs that could not be read
export EMPTY_LOGS=0             # logs completely empty


# Severity keywords
readonly FATAL_KEYWORDS="fatal|emerg|panic"
readonly ERROR_KEYWORDS="error|fail|failed|failure"
readonly WARN_KEYWORDS="warn|warning|deprecated"
readonly HEALTHY_KEYWORDS="healthy|okay|pass|ok|done"



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
    parse_args "$@"
    validate_dir "$LOG_PATH" || {
        echo "Failed to open: $LOG_PATH, run with sudo or verify permision" >&2
        return "$ERROR_USAGE"
    }
}