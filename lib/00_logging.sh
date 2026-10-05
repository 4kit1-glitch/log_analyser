#!/usr/bin/env bash
#
#
# script 

current_log_file="$LOG_DIR_$DATE.log"
error() {
    echo "[ERROR] -- [$DATE] $1" >> "$current_log_file"
}

inform() {
    echo "[INFO] -- [$DATE] $1" >> "$current_log_file"
}
