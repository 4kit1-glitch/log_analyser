#!/usr/bin/env bash
# shellcheck disable=2154
# line compression algorithm and line merger
#



emit_range() {
    # func fills the compressed array with the right log format
    local start="$1" end="$2" level="$3" logger="$4" msg="$5" count="$6"
    if (( count == 1 )); then
        _compressed_log+=("$start|$level|$logger|$msg")
    else
        _compressed_log+=("$start - $end|$level|$logger|$msg x$count")
    fi
}

compress_log() {
    local log_file="$1"
    local dt tm level logger msg sig    # dt and tm short for date and time
    local cur_sig="" cur_start="" cur_end=""
    local cur_level="" cur_logger="" cur_msg="" cur_count=0

    validate_file "$log_file" || {
        error "failed to open $log_file"
        return 3
    }

    while IFS="|" read -r dt tm level logger msg; do
        sig="$level|$logger|$msg"
       # echo $sig

        # same signature as the open range: extend it
        if (( cur_count > 0 )) && [[ "$sig" == "$cur_sig" ]]; then
            cur_end="$dt $tm"
            cur_count=$(( cur_count + 1 ))
            continue
        fi

        # different signature: save the old range first, then start a new one
        if (( cur_count > 0 )); then
            emit_range "$cur_start" "$cur_end" "$cur_level" "$cur_logger" "$cur_msg" "$cur_count"
        fi

        cur_sig="$sig"
        cur_start="$dt $tm"
        cur_end="$dt $tm"
        cur_level="$level"
        cur_logger="$logger"
        cur_msg="$msg"
        cur_count=1
    done < <(awk -f "$feat_path/lineparser.awk" "$log_file")

    # the loop ends with one range still open
    if (( cur_count > 0 )); then
        emit_range "$cur_start" "$cur_end" "$cur_level" "$cur_logger" "$cur_msg" "$cur_count"
    fi
}
