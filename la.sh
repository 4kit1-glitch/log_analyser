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
export LOGS_DIR=${LOGS_DIR:-"$HOME/.local/state/$PROG_NAME/logs"}

lib_path="$SCRIPT_DIR/lib"
tests_path="$SCRIPT_DIR/tests"



# source library scripts
for script in "$lib_path"/*; do
    source "$script"
done


main() {
    echo "hello"
}
