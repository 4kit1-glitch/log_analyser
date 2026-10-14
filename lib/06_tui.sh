#!/usr/bin/env bash
# shellcheck disable=2154
#
# 06_tui.sh -- display layer
#
# Public:
#   tui_init
#   tui_header
#   tui_compress_progress <cur> <tot> <file> <detail>   -- updates one line
#   tui_compress_end
#   tui_manual <text>
#   tui_ai <text> <rc>
#   tui_footer

TUI_R=""; TUI_B=""; TUI_DIM=""; TUI_EL=""
TUI_RED=""; TUI_GRN=""; TUI_YEL=""; TUI_CYN=""

tui_init() {
    if [[ -t 1 ]] && command -v tput &>/dev/null; then
        TUI_R=$(tput sgr0)
        TUI_B=$(tput bold)
        TUI_DIM=$(tput dim)
        TUI_EL=$(tput el)
        TUI_RED=$(tput setaf 1)
        TUI_GRN=$(tput setaf 2)
        TUI_YEL=$(tput setaf 3)
        TUI_CYN=$(tput setaf 6)
    fi
}

_tui_have_gum() { command -v gum &>/dev/null; }


tui_header() {
    if _tui_have_gum; then
        gum style \
            --border rounded --border-foreground 212 \
            --foreground 212 --bold \
            --padding "0 2" --margin "1 0" \
            "$PROG_NAME v$VERSION"
    else
        printf '%s=== %s v%s ===%s\n' "$TUI_B" "$PROG_NAME" "$VERSION" "$TUI_R"
    fi
}


tui_compress_progress() {
    local cur="$1" tot="$2" file="$3" detail="${4:-}"
    local width=20 filled=0
    (( tot > 0 )) && filled=$(( cur * width / tot ))

    local bar="" i
    for (( i=0; i<filled; i++ )); do bar+="█"; done
    for (( i=filled; i<width; i++ )); do bar+="░"; done

    file="${file:0:22}"
    detail="${detail:0:44}"

    printf '\r%s  %s[%s]%s  %2d/%-2d  %s%-22s%s  %s%s%s' \
        "$TUI_EL" \
        "$TUI_CYN" "$bar" "$TUI_R" \
        "$cur" "$tot" \
        "$TUI_B" "$file" "$TUI_R" \
        "$TUI_DIM" "$detail" "$TUI_R"
}


tui_compress_end() {
    printf '\n'
}


tui_manual() {
    local text="${1:-}"

    if _tui_have_gum; then
        printf '\n'
        gum style --foreground 212 --bold "Manual analysis"
    else
        printf '\n%sManual analysis%s\n' "$TUI_B" "$TUI_R"
    fi

    if [[ -z "$text" ]]; then
        printf '  %s! no manual analysis produced%s\n' "$TUI_YEL" "$TUI_R"
        return 0
    fi

    local line
    while IFS= read -r line; do
        [[ -n "$line" ]] && printf '  %s%s%s\n' "$TUI_DIM" "$line" "$TUI_R"
    done <<< "$text"
}


tui_ai() {
    local text="${1:-}" rc="${2:-0}"

    if _tui_have_gum; then
        printf '\n'
        gum style --foreground 212 --bold "AI verdict"
    else
        printf '\n%sAI verdict%s\n' "$TUI_B" "$TUI_R"
    fi

    if (( rc != 0 )); then
        printf '  %s✗ AI: %s%s\n' "$TUI_RED" "${text:-analysis failed}" "$TUI_R"
        return 0
    fi

    if [[ -z "$text" ]]; then
        printf '  %s! AI returned empty%s\n' "$TUI_YEL" "$TUI_R"
        return 0
    fi

    local line
    while IFS= read -r line; do
        [[ -n "$line" ]] && printf '  %s✓ %s%s\n' "$TUI_GRN" "$line" "$TUI_R"
    done <<< "$text"
}


tui_footer() {
    printf '\n'
    if _tui_have_gum; then
        gum style --foreground 240 "── complete ──"
    else
        printf '%s── complete ──%s\n' "$TUI_DIM" "$TUI_R"
    fi
}