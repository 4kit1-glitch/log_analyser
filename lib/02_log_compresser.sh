#!/usr/bin/env bash
#
#
# caries functions the reads the files and comes out with a specialized log file
# follows 3 ways 
# 1. read through all the logs if a log failed to read or is empty, just continue and increment failed logs and empty logs var


# Severity keywords
readonly FATAL_KEYWORDS="fatal|emerg|panic"
readonly ERROR_KEYWORDS="error|fail|failed|failure"
readonly WARN_KEYWORDS="warn|warning|deprecated"
readonly HEALTHY_KEYWORDS="healthy|okay|pass|ok|done"


readonly log_file="$1"

get_first_two_lines() {
    log_file="$1"
    head -n 2 "$log_file"
}

get_last_two_lines() {
    log_file="$1"
    tail -n 2 "$log_file"
}

