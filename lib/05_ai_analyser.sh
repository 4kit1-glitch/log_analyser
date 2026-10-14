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
    local format="$1" model="$2" prompt
 
    prompt=$(cat <<PROMPT_EOF
You are analyzing a compressed log file. Determine the system state.
 
Return ONLY a JSON object. No prose. No markdown. No code fences.
{"verdict":"OK|WARNING|CRITICAL","confidence":"low|medium|high","reason":"one sentence","suggestion":"one action"}
 
Log content:
$(printf '%s\n' "${_compressed_log[@]}")
PROMPT_EOF
    )
    
    # this handles the check
    if [[ "$format" == gemini ]]; then
        printf '%s' "$prompt" | jq -Rs \
            '{contents:[{parts:[{text:.}]}],generationConfig:{responseMimeType:"application/json"}}'
    else
        printf '%s' "$prompt" | jq -Rs --arg m "$model" \
            '{model:$m,messages:[{role:"user",content:.}]}'
    fi
}


# $1 = format, $2 = body. Prints the model's text, or nothing.
_ai_extract_text() {
    if [[ "$1" == gemini ]]; then
        printf '%s' "$2" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null
    else
        printf '%s' "$2" | jq -r '.choices[0].message.content // empty' 2>/dev/null
    fi
}

_parse_ai_response() {
    local clean verdict confidence reason suggestion
 
    # some models ignore "no code fences": drop any fence lines
    clean=$(printf '%s\n' "$1" | grep -v '^[[:space:]]*```')
 
    verdict=$(   jq -r '.verdict    // empty' <<< "$clean" 2>/dev/null)
    confidence=$(jq -r '.confidence // empty' <<< "$clean" 2>/dev/null)
    reason=$(    jq -r '.reason     // empty' <<< "$clean" 2>/dev/null)
    suggestion=$(jq -r '.suggestion // empty' <<< "$clean" 2>/dev/null)
 
    case "${verdict^^}" in
        OK|WARNING|CRITICAL) ;;
        *) return 1 ;;
    esac
 
    printf "verdict: %s\nconfidence: %s\nreason: %s\nsuggestion: %s\n" \
        "${verdict^^}" "${confidence:-unknown}" \
        "${reason:-unknown}" "${suggestion:-unknown}"
}


get_ai_overview() {
    local dep
    for dep in curl jq; do
        command -v "$dep" &>/dev/null ||
            { _ai_fail "missing dependency: $dep" "$dep is required for the AI step"; return 3; }
    done
 
    if (( ${#_compressed_log[@]} == 0 )); then
        _ai_fail "nothing to analyse (_compressed_log is empty)" "no log content to send"
        return 3
    fi
 
    if ! is_online; then
        _ai_fail "no internet connection" "no internet connection"
        return 3
    fi
 
    # ---- settings: environment first, otherwise ask ----
    local api_url="${AI_API_URL:-}" model="${AI_MODEL:-}" api_key="${AI_API_KEY:-}"
 
    if [[ -z "$api_url" ]]; then
        read -rp "API URL [Enter for Gemini Flash default]: " api_url
        api_url="${api_url:-$GEMINI_DEFAULT_URL}"
    fi
 
    local format
    format=$(_ai_format "$api_url")
 
    if [[ "$format" == openai && -z "$model" ]]; then
        read -rp "Model name: " model
        [[ -n "$model" ]] || { _ai_fail "no model name given" "no model name given"; return 3; }
    fi
 
    if [[ -z "$api_key" ]]; then
        read -rsp "API key: " api_key
        echo
    fi
    [[ -n "$api_key" ]] || { _ai_fail "no API key given" "no API key given"; return 3; }
 
    # the key goes into a curl config file, so these would break its syntax
    if [[ "$api_key" == *[\"\\]* ]]; then
        _ai_fail "api key contains a quote or backslash" "that API key looks wrong"
        return 3
    fi
 
    local auth
    if [[ "$format" == gemini ]]; then
        auth="x-goog-api-key: $api_key"
    else
        auth="Authorization: Bearer $api_key"
    fi
 
    local payload
    payload=$(_build_payload "$format" "$model") && [[ -n "$payload" ]] || {
        _ai_fail "failed to build payload" "failed to build the request"
        return 3
    }
 
    # ---- request, with retries for failures that can pass on their own ----
    local raw rc http_code body attempt retryable began=$SECONDS why
 
    for (( attempt = 1; attempt <= AI_MAX_ATTEMPTS; attempt++ )); do
        raw=$(curl -sS -w '\n%{http_code}' \
                --connect-timeout "$AI_CONNECT_TIMEOUT" --max-time "$AI_MAX_TIME" \
                --config <(printf 'header = "%s"\n' "$auth") \
                -H "Content-Type: application/json" \
                --data-binary @- \
                "$api_url" <<< "$payload")
        rc=$?
 
        http_code=000
        body=""
        if (( rc == 0 )); then
            http_code=${raw##*$'\n'}
            body=${raw%$'\n'*}
        fi
 
        (( rc == 0 && http_code == 200 )) && break
 
        # transient problems are worth another try, the rest never are
        retryable=0
        if (( rc != 0 )); then
            case $rc in 7|28|52|55|56) retryable=1 ;; esac
            why="curl exit $rc"
        else
            case $http_code in 408|429|500|502|503|504) retryable=1 ;; esac
            why="http $http_code"
        fi
 
        (( retryable && attempt < AI_MAX_ATTEMPTS )) || break
        error "AI: attempt $attempt/$AI_MAX_ATTEMPTS failed ($why), retrying in $(( attempt * 3 ))s"
        sleep $(( attempt * 3 ))
    done
 
    local took=$(( SECONDS - began ))
 
    # ---- curl itself failed (no HTTP answer at all) ----
    if (( rc != 0 )); then
        case $rc in
            3)     _ai_fail "curl exit 3 (malformed URL)" "the API URL is not valid" ;;
            6)     _ai_fail "curl exit 6 (cannot resolve host)" "cannot find the server (no internet, or wrong URL)" ;;
            7)     _ai_fail "curl exit 7 (connection refused)" "cannot connect to the server" ;;
            28)    _ai_fail "curl exit 28 (timeout after ${took}s)" "the request timed out" ;;
            35|60) _ai_fail "curl exit $rc (TLS problem)" "secure connection failed" ;;
            *)     _ai_fail "curl exit $rc after ${took}s" "request failed (curl exit $rc)" ;;
        esac
        return 3
    fi
 
    # ---- the server answered with an error ----
    if (( http_code != 200 )); then
        local detail
        detail=$(_ai_error_message "$body")
        [[ -n "$detail" ]] && echo "provider said: $detail" >&2
 
        case "$http_code" in
            400) _ai_fail "http 400 ($detail)" "bad request (prompt too large, or wrong model name)" ;;
            401|403) _ai_fail "http $http_code ($detail)" "API key rejected (or not allowed in your region)" ;;
            404) _ai_fail "http 404 ($detail)" "URL or model name not found" ;;
            413) _ai_fail "http 413 ($detail)" "prompt too large for this provider" ;;
            429) _ai_fail "http 429 ($detail), gave up after $attempt attempts" "rate limit or quota reached, try later" ;;
            5*)  _ai_fail "http $http_code ($detail), gave up after $attempt attempts" "the provider is overloaded or down, try later" ;;
            *)   _ai_fail "http $http_code ($detail)" "unexpected answer (http $http_code)" ;;
        esac
        return 3
    fi
 
    # ---- 200 OK: make sure there is a usable answer ----
    local text block
    text=$(_ai_extract_text "$format" "$body")
    if [[ -z "$text" ]]; then
        block=$(printf '%s' "$body" |
            jq -r '.promptFeedback.blockReason // .candidates[0].finishReason // empty' 2>/dev/null)
        _ai_fail "empty answer (${block:-no reason given})" "the model returned no answer${block:+ ($block)}"
        return 3
    fi
 
    _parse_ai_response "$text" || {
        _ai_fail "answer was not the expected JSON: ${text:0:120}" "the model did not return a valid verdict"
        return 3
    }
}












