#!/usr/bin/env bash
#
# get directory implecation script,
# and works to get files
#

get_dir() { printf "%s" "$(readlink -f "$LOG_PATH")"; }

validate_dir() {
    local dir="$1"

    [[ -n "$dir" ]] || { error "No path given"; return 1; }
    [[ -e "$dir" ]] || { error "Does not exist: $dir"; return 1; }
    [[ -d "$dir" ]] || { error "Not a directory: $dir"; return 1; }
    [[ -r "$dir" ]] || { error "Not readable: $dir"; return 1; }
    [[ -x "$dir" ]] || { error "Not traversable: $dir"; return 1; }

    return 0
  }

get_log_files() {
    local directory="$1"
    local -n arr_name="$2"
    mapfile -t -d '' "$arr_name" < <(find "$directory" -mindepth 1 -type f  -name "*.log" -print0 2> /dev/null)
    [[ ${#arr_name[@]} -eq 0 ]] && { inform "No file found in $directory"; }
}

see_files() {
    local -n arr="$1"
    printf "*********************** FOUND LOG FILES ******************"
    for file in "${arr[@]}"; do 
        printf "%s" "$file"
    done
    printf "**********************************************************"
}