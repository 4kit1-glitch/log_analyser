#!/usr/bin/env bash
# shellcheck disable=2154
#
# 05_ai_analyser.sh -- AI-assisted verdict via Gemini Flash
#
# Public:
#   is_online         - 0 if reachable, 1 if not
#   get_ai_overview   - prints 4 lines (verdict/confidence/reason/suggestion)
#                       returns 0 on success, 3 on any failure
#
# Private:
#   _build_payload
#   _parse_ai_response
#

readonly GEMINI_DEFAULT_URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent"
readonly AI_MAX_ATTEMPTS=3
readonly AI_CONNECT_TIMEOUT=10
readonly AI_MAX_TIME=120
 
 
is_online() {
    # ping can be blocked, so fall back to a short HTTPS connect
    ping -c 1 -W 2 1.1.1.1 &>/dev/null || curl -s -o /dev/null --max-time 3 https://1.1.1.1
}


# handle logging and a failing ai request
_ai_fail() {
    error "AI: $1"
    echo "ERROR: $2" >&2
    return 3
}

# handles the format sent by the url 
_ai_format() {
    case "$1" in
        *:generateContent*) echo gemini ;;
        *)                  echo openai ;;
    esac
}

_ai_error_message() {
    printf '%s' "$1" |
        jq -r '.error.message? // .error? // .message? // empty' 2>/dev/null |
        head -c 200
}























_build_payload() {
    local prompt escaped
    prompt=$(cat <<PROMPT_EOF
You are analyzing a compressed log file. Determine the system state.

Return ONLY a JSON object. No prose. No markdown. No code fences.
{"verdict":"OK|WARNING|CRITICAL","confidence":"low|medium|high","reason":"one sentence","suggestion":"one action"}

Log content:
$(printf '%s\n' "${_compressed_log[@]}")
PROMPT_EOF
    )

    escaped=$(printf '%s' "$prompt" | awk '
        BEGIN { ORS="" }
        {
            gsub(/\\/, "\\\\")
            gsub(/"/,  "\\\"")
            gsub(/\t/, "\\t")
            gsub(/\r/, "")
            if (NR > 1) print "\\n"
            print
        }
    ')

    printf '{"contents":[{"parts":[{"text":"%s"}]}],"generationConfig":{"responseMimeType":"application/json"}}' "$escaped"
}


_parse_ai_response() {
    local raw="$1"
    local clean verdict confidence reason suggestion

    clean=$(printf '%s' "$raw" | sed -e 's/\\"/"/g' -e 's/\\n/\n/g')

    verdict=$(   grep -oP '"verdict":\s*"\K[^"]+'    <<< "$clean" | head -1)
    confidence=$(grep -oP '"confidence":\s*"\K[^"]+' <<< "$clean" | head -1)
    reason=$(    grep -oP '"reason":\s*"\K[^"]+'     <<< "$clean" | head -1)
    suggestion=$(grep -oP '"suggestion":\s*"\K[^"]+' <<< "$clean" | head -1)

    printf "verdict: %s\nconfidence: %s\nreason: %s\nsuggestion: %s\n" \
        "${verdict:-unknown}" "${confidence:-unknown}" \
        "${reason:-unknown}"  "${suggestion:-unknown}"
}


get_ai_overview() {
    if ! is_online; then
        error "AI: no internet connection"
        echo "ERROR: no internet connection" >&2
        return 3
    fi

    local api_url api_key
    read -rp "API URL [Enter for Gemini Flash default]: " api_url
    api_url="${api_url:-$GEMINI_DEFAULT_URL}"
    read -rp "API key: " api_key
    sleep 1
    clear
    if [[ -z "$api_key" ]]; then
        error "AI: no API key given"
        echo "ERROR: no API key given" >&2
        return 3
    fi

    local payload
    payload=$(_build_payload) || {
        unset api_key
        error "AI: failed to build payload"
        echo "ERROR: failed to build payload" >&2
        return 3
    }

    local raw http_code body
    raw=$(curl -s -w "\n%{http_code}" --max-time 120 \
        --config <(printf 'header = "x-goog-api-key: %s"\n' "$api_key") \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$payload" \
        "$api_url") || {
        unset api_key
        error "AI: curl request failed"
        echo "ERROR: request failed (network or timeout)" >&2
        return 3
    }
    unset api_key

    http_code=$(printf '%s' "$raw" | tail -n 1)
    body=$(printf '%s' "$raw" | sed '$d')

    case "$http_code" in
        200)     ;;
        400)     error "AI: bad request (400)";        echo "ERROR: bad request" >&2;        return 3 ;;
        401|403) error "AI: invalid api key ($http_code)"; echo "ERROR: invalid api key" >&2; return 3 ;;
        429)     error "AI: rate limited (429)";       echo "ERROR: rate limited" >&2;       return 3 ;;
        5*)      error "AI: server error ($http_code)"; echo "ERROR: server error" >&2;      return 3 ;;
        000)     error "AI: connection failed";        echo "ERROR: connection failed" >&2;  return 3 ;;
        *)       error "AI: http $http_code";          echo "ERROR: http $http_code" >&2;    return 3 ;;
    esac

    _parse_ai_response "$body"
}