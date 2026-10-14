#!/usr/bin/env bash
# shellcheck disable=2154
# manualanalyser.sh - manual log analyser (v1), answers 4 questions.
# Text processing lives in manualanalyser.awk; keywords come from la.sh.
#
# v1 assumptions:
#   - startup  = non-severity line matching STARTUP_KEYWORDS within the first HEAD_N lines
#   - shutdown = non-severity line matching STOP_KEYWORDS within the last TAIL_N lines
#   - recovered = after the last FATAL, a startup message appears and no
#     ERROR/FATAL follows it
#   - severity is read from the level token (FATAL/ERROR/WARN_KEYWORDS)

readonly HEAD_N=5
readonly TAIL_N=5

analyse_log() {
    local log_file="$1"

    validate_file "$log_file" || {
        error "unable to open file at analyses phase"
        return 3
    }

    awk -v STARTUP_KEYWORDS="$STARTUP_KEYWORDS" -v STOP_KEYWORDS="$STOP_KEYWORDS" \
        -v FATAL_KEYWORDS="$FATAL_KEYWORDS" -v ERROR_KEYWORDS="$ERROR_KEYWORDS" \
        -v WARN_KEYWORDS="$WARN_KEYWORDS" -v CRITICAL_KEYWORDS="$CRITICAL_KEYWORDS"\
        -v head_n="$HEAD_N" -v tail_n="$TAIL_N" \
        -f "$feat_path/manualanalyser.awk" "$log_file"
}