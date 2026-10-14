#!/usr/bin/env bash
# shellcheck disable=2034

usage() {
    cat <<EOF
    Usage: $0 <log-dir> [--ai]

    <log-dir>   Directory containing .log files
    --ai        Enable AI-assisted verdict (optional)

    If no arguments are given, the tool prompts interactively.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            --ai)      AI_ENABLED=1 ;;
            -v|--view) see_log || { echo "failed to view latest log"; } ;;
            -*)        error "Unknown option: $1"; usage; exit 1 ;;
            *)
                [[ -z "${LOG_PATH:-}" ]] || {
                    error "Multiple paths given"
                    exit 3
                }
                LOG_PATH="$1"
                ;;
        esac
        shift
    done
}