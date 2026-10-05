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

lib_path="$SCRIPT_DIR/lib"
tests_path="$SCRIPT_DIR/tests"

export AI_ENABLED=0    # 0 for false | * ~ 1 for pass
export LOG_PATH=""

# source library scripts
for script in "$lib_path"/*; do
    echo "$script"
    source "$script"
done


main() {
    parse_args "$@"
}

main "$@"