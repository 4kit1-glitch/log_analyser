#!/usr/bin/env bash
#
# line compression algorithm and line merger
#

_current_sig=""      # level + signature (e.g., "WARN|cache: redis latency")
_current_start=""    # timestamp of first line in range
_current_end=""      # timestamp of last line in range
_current_logger=""   # logger of the range
_current_level=""    # WARN / ERROR / FATAL
_current_count=0     # how many lines in this range
_current_msg=""

declare -a _compressed_log=()

set_vars() {
    # sets the global vars at command so i dont lose track of where i am at
    local line_vars="$1"
    local d t lv lg msg # date, time , level , logger, message i ran out of names ^..^
    IFS="|" read -r d t lv lg msg <<< "$line_vars"

    # set the global vars
    _current_start="$d $t"
    _current_level="$lv"
    _current_logger="$lg"
    _current_msg="$msg"
    _current_sig="$_current_level|$_current_logger"
}

is_same_sig() {
    [[ "$1|$2" == "$_current_sig" ]]
}

compress_log() {
    local log_file="$1"
    local line_num=0
    validate_file "$log_file" || {
        error "failed to open $log_file"
        return 3
    }

    # loop though the lines
    while IFS="" read -r line; do
        (( line_num++ ))
        echo "flss $line"
    done < "$log_file"
    echo
    echo "$line_num"
}

