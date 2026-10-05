#!/usr/bin/env bash
#
#
# script 

current_log_file="$PROG_LOGS_DIR"_$DATE".log"

# error codes
readonly ERROR_WARNING=1
readonly ERROR_FATAL=2
readonly ERROR_OK=0
readonly ERROR_USAGE=3

error() {
    echo "[ERROR] -- [$DATE] $1" >> "$current_log_file"
}

inform() {
    echo "[INFO] -- [$DATE] $1" >> "$current_log_file"
}

see_log() {
    clear
    cat "$current_log_file" || {
        echo "failed to see logs $current_log_file" >&2
        error "failed to see logs $current_log_file"
    }
}