#!/usr/bin/env bash
#
#
# caries functions the reads the files and comes out with a specialized log file
# follows 3 ways 
# 1. read through all the logs if a log failed to read or is empty, just continue and increment failed logs and empty logs var
# umn mot all functions handle thier own errors only critical ones do 
# this is so that it returns its own exit code 

# Severity keywords
readonly FATAL_KEYWORDS="fatal|emerg|panic"
readonly ERROR_KEYWORDS="error|fail|failed|failure"
readonly WARN_KEYWORDS="warn|warning|deprecated"
readonly HEALTHY_KEYWORDS="healthy|okay|pass|ok|done"


validate_file() {
  local file="$1"

  [[ -n "$file" ]] || { error "No file given"; return 1; }
  [[ -e "$file" ]] || { error "Does not exist: $file"; return 1; }
  [[ -f "$file" ]] || { error "Not a regular file: $file"; return 1; }
  [[ -r "$file" ]] || { error "Not readable: $file"; return 1; }
  [[ -s "$file" ]] || { error "Empty file: $file"; return 1; }

  return 0
}

get_first_two_lines() {
    log_file="$1"
    head -n 2 "$log_file"
}

get_last_two_lines() {
    log_file="$1"
    tail -n 2 "$log_file"
}

get_message_from_line() {
    line="$1"
    awk -F":" '{print $2}' <<< "$line"
}

parse_line() {
    line="$1"
    awk '{printf "%s|%s|%s|%s",$1,$2,$3,$4}' <<< "$line"
}