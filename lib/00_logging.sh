#!/usr/bin/env bash
#
#
# script 

current_log_file="$PROG_LOGS_DIR"_$DATE".log"
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