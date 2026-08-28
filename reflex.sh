#!/bin/bash
# reflex.sh - The Execution Conductor (Sanitized, Hardened, Retry-Limited, Multi-Block)

LOG_FILE="/Users/javienbarnes/felicity_forge/reflex_history.log"
RETRY_FILE="/Users/javienbarnes/felicity_forge/.reflex_retry_count"
MAX_RETRIES=10

# --- RETRY COUNTER GUARD ---
if [ -f "$RETRY_FILE" ]; then
    RETRY_COUNT=$(cat "$RETRY_FILE" | tr -d '[:space:]')
else
    RETRY_COUNT=0
fi

if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    echo "--- [STATUS: HARD STOP (Maximum Failures Exceeded)] ---"
    echo "  -> Stopped execution after $RETRY_COUNT consecutive failed attempts."
    echo "  -> Execution locked to prevent runaway loop."
    echo "  -> To unlock, run: echo 0 > '$RETRY_FILE'"
    exit 1
fi

CMD="$*"

record_failure() {
    local new_count=$((RETRY_COUNT + 1))
    echo "$new_count" > "$RETRY_FILE"
    echo "  -> Consecutive Failures: $new_count/$MAX_RETRIES"
}

record_success() {
    echo "0" > "$RETRY_FILE"
}

# --- Known API lookup table ---
API_TABLE=(
  "weather|OpenWeather: https://api.openweathermap.org/data/2.5/weather?q={city}&appid={KEY}"
  "github|GitHub REST: https://api.github.com/repos/{owner}/{repo} (add: -H \"Authorization: Bearer <token>\")"
  "reddit|Reddit: https://oauth.reddit.com/... requires OAuth token, not a plain GET"
  "twitter|X/Twitter API v2: https://api.twitter.com/2/... requires Bearer token"
  "stock|Alpha Vantage: https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol={SYM}&apikey={KEY}"
  "news|NewsAPI: https://newsapi.org/v2/everything?q={QUERY}&apiKey={KEY}"
  "translate|Google Translate API: https://translation.googleapis.com/language/translate/v2"
  "geocode|OpenStreetMap Nominatim: https://nominatim.openstreetmap.org/search?q={QUERY}&format=json"
)

suggest_api() {
    local cmd_lower
    cmd_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local found=0
    for entry in "${API_TABLE[@]}"; do
        key="${entry%%|*}"
        hint="${entry#*|}"
        if [[ "$cmd_lower" == *"$key"* ]]; then
            echo "  -> Looks like you're after '$key' data. Try: $hint"
            found=1
        fi
    done
    if [ "$found" -eq 0 ]; then
        echo "  -> No known API match for this query. Consider searching for the service's official REST docs before hand-writing the curl call."
    fi
}

diagnose_curl_failure() {
    local exit_code="$1"
    local output="$2"
    local cmd_text="$3"
    echo "--- [CURL DIAGNOSIS] ---"
    case "$exit_code" in
        6)  echo "  -> Couldn't resolve host. Check the domain for typos." ;;
        7)  echo "  -> Failed to connect. Check the host/port, or if a VPN/firewall is blocking it." ;;
        28) echo "  -> Request timed out. The server may be slow or unreachable." ;;
        35|60) echo "  -> SSL/TLS handshake issue. Try adding --insecure only for testing, or check the cert." ;;
    esac
    if echo "$output" | grep -qE '"?(401|Unauthorized)"?'; then
        echo "  -> 401 Unauthorized: missing/invalid API key or auth header."
    fi
    if echo "$output" | grep -qE '"?(403|Forbidden)"?'; then
        echo "  -> 403 Forbidden: key valid but lacks permission, or rate limited."
    fi
    if echo "$output" | grep -qE '"?(404|Not Found)"?'; then
        echo "  -> 404 Not Found: endpoint path is likely wrong."
    fi
    if echo "$output" | grep -qE '"?(429|Too Many Requests)"?'; then
        echo "  -> 429: rate limited."
    fi
    if echo "$output" | grep -qiE 'method not allowed|405'; then
        echo "  -> 405: wrong HTTP method."
    fi
    echo "  -> Keyword-based API suggestions:"
    suggest_api "$cmd_text"
}

verify_execution() {
    local cmd="$1"
    local exit_code="$2"
    local target_file=""

    if [ "$exit_code" -ne 0 ]; then
        return 0
    fi

    if [[ "$cmd" =~ [[:space:]]\>[[:space:]]*([^[:space:]\&]+) ]]; then
        target_file="${BASH_REMATCH[1]}"
    fi

    if [ -z "$target_file" ] && [[ "$cmd" == *python3* ]] && [[ "$cmd" =~ open\([[:space:]]*[\'\"]([^\'\"]+)[\'\"] ]]; then
        target_file="${BASH_REMATCH[1]}"
    fi

    target_file=$(echo "$target_file" | tr -d "'" | tr -d '"')

    if [ -n "$target_file" ] && [ "$target_file" != "/dev/null" ]; then
        if [ ! -f "$target_file" ]; then
            echo "--- [GATEKEEPER FALSIFICATION CAUGHT] ---"
            echo "  -> Exit code was 0, but target file '$target_file' does NOT exist on disk."
            return 1
        elif [ ! -s "$target_file" ]; then
            echo "--- [GATEKEEPER FALSIFICATION CAUGHT] ---"
            echo "  -> Exit code was 0, but target file '$target_file' is completely empty (0 bytes)."
            return 1
        else
            echo "  -> [Gatekeeper Verified]: File '$target_file' confirmed on disk with data."
        fi
    fi
    return 0
}

run_read() {
    local text="$1"
    local target
    target=$(echo "$text" | sed -E 's/^(cat|less|more)[[:space:]]+//' | xargs)
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] READ: $target" >> "$LOG_FILE"
    if [ -f "$target" ]; then
        echo "--- [STATUS: SUCCESS] ---"
        cat "$target"
        return 0
    else
        echo "--- [STATUS: FAILURE (File not found)] ---"
        echo "  -> '$target' does not exist on disk."
        return 1
    fi
}

run_fetch() {
    local text="$1"
    local url outpath http_code exit_code curl_err
    url=$(echo "$text" | awk '{print $1}')
    if [[ "$url" == /* ]] || [ -f "$url" ]; then
        run_read "cat $url"
        return $?
    fi
    outpath=$(echo "$text" | sed -nE 's/.*->\s*(.+)$/\1/p')
    if [ -z "$outpath" ]; then
        outpath=$(basename "$url")
    fi
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] FETCH: $url -> $outpath" >> "$LOG_FILE"
    if ! [[ "$url" =~ ^https?:// ]]; then
        echo "--- [STATUS: REJECTED (FETCH requires a valid http/https URL)] ---"
        echo "Received: $url"
        return 1
    fi
    http_code=$(curl -fsSL -o "$outpath" -w '%{http_code}' "$url" 2>/tmp/reflex_curl_err)
    exit_code=$?
    curl_err=$(cat /tmp/reflex_curl_err 2>/dev/null)
    if [ $exit_code -eq 0 ] && [ -s "$outpath" ]; then
        echo "--- [STATUS: SUCCESS] ---"
        echo "  -> [Gatekeeper Verified]: Downloaded '$url' -> '$outpath' ($(wc -c < "$outpath") bytes, HTTP $http_code)."
        echo "  -> NOTE: content is UNREVIEWED. Inspect before executing it."
        return 0
    else
        echo "--- [STATUS: FAILURE (curl exit $exit_code, HTTP $http_code)] ---"
        echo "$curl_err"
        return 1
    fi
}

run_execute() {
    local text="$1"
    local lead_word output exit_code
    lead_word=$(echo "$text" | awk '{print $1}' | tr -d '"' | tr -d "'")
    if [[ "$lead_word" =~ ^https?:// ]] || [[ "$lead_word" =~ ^[a-z0-9_]+\.[a-z]+ ]]; then
        echo "--- [STATUS: REJECTED (Raw URL or non-executable prose detected)] ---"
        echo "Received: $text"
        return 1
    fi
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] COMMAND: $text" >> "$LOG_FILE"
    
    # Robust subshell PIPESTATUS capture via marker string
    local raw pipestatus_str
    raw=$(eval "$text" 2>&1; echo "___PS___${PIPESTATUS[*]}")
    output="${raw%___PS___*}"
    pipestatus_str="${raw##*___PS___}"
    read -ra pipestatus_arr <<< "$pipestatus_str"
    exit_code="${pipestatus_arr[-1]}"
    
    # Tighter guard: Only bypass exit 1 if grep is strictly the TERMINAL stage of the pipe,
    # grep exited with 1 (no match), and the upstream command succeeded.
    if [ "$exit_code" -eq 1 ] && [[ "$text" == *'|'* ]] && [[ "$text" =~ \|[[:space:]]*grep([[:space:]]|$) ]] && [ "${pipestatus_arr[0]}" -eq 0 ]; then
        exit_code=0
    fi

    if [ $exit_code -eq 0 ]; then
        verify_execution "$text" "$exit_code"
        if [ $? -ne 0 ]; then
            echo "--- [STATUS: FORCED FAILURE (Gatekeeper Check Failed)] ---"
            echo "$output"
            return 1
        else
            echo "--- [STATUS: SUCCESS] ---"
            echo "$output"
            return 0
        fi
    else
        echo "--- [STATUS: FAILURE (Exit Code: $exit_code)] ---"
        echo "$output"
        if [[ "$text" == curl* ]]; then
            diagnose_curl_failure "$exit_code" "$output" "$text"
        fi
        return 1
    fi
}

declare -a VERBS=()
declare -a BODIES=()
current_verb=""
current_body=""
block_open=0
in_heredoc=0
heredoc_marker=""

flush_block() {
    if [ -n "$current_verb" ]; then
        VERBS+=("$current_verb")
        BODIES+=("$current_body")
    fi
}

start_block() {
    local verb="$1" body="$2"
    flush_block
    current_verb="$verb"
    current_body="$body"
    in_heredoc=0
    heredoc_marker=""
    block_open=0
    if [[ "$body" =~ \<\<[-~]?[\'\"]?([A-Za-z_][A-Za-z0-9_]*)[\'\"]?[[:space:]]*$ ]]; then
        in_heredoc=1
        heredoc_marker="${BASH_REMATCH[1]}"
        block_open=1
    elif [[ "$body" == *\\ ]]; then
        block_open=1
    fi
}

while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*\[EXECUTE\]:[[:space:]]*(.*)$ ]]; then
        start_block "EXECUTE" "${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]*\[FETCH\]:[[:space:]]*(.*)$ ]]; then
        start_block "FETCH" "${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]*\[READ\]:[[:space:]]*(.*)$ ]]; then
        start_block "READ" "${BASH_REMATCH[1]}"
    elif [ "$in_heredoc" -eq 1 ]; then
        current_body="$current_body"$'\n'"$line"
        if [[ "$line" == "$heredoc_marker" ]]; then
            in_heredoc=0
            block_open=0
        fi
    elif [ -n "$current_verb" ] && [ "$block_open" -eq 1 ]; then
        current_body="$current_body"$'\n'"$line"
        if [[ "$line" == *\\ ]]; then
            block_open=1
        else
            block_open=0
        fi
    elif [ -z "$current_verb" ] && [ -n "$line" ]; then
        start_block "EXECUTE" "$line"
        block_open=0
    fi
done <<< "$CMD"
flush_block

BLOCK_COUNT="${#VERBS[@]}"
if [ "$BLOCK_COUNT" -eq 0 ]; then
    echo "--- [STATUS: REJECTED (No command received)] ---"
    record_failure
    exit 1
fi

OVERALL_FAILURE=0
for i in "${!VERBS[@]}"; do
    verb="${VERBS[$i]}"
    body="${BODIES[$i]}"
    case "$verb" in
        READ) run_read "$body" ;;
        FETCH) run_fetch "$body" ;;
        EXECUTE) run_execute "$body" ;;
    esac
    block_status=$?
    if [ $block_status -ne 0 ]; then
        OVERALL_FAILURE=1
        break
    fi
done

if [ "$OVERALL_FAILURE" -eq 0 ]; then
    record_success
else
    record_failure
fi
exit $OVERALL_FAILURE
EOF
chmod +x reflex.sh
echo 0 > .reflex_retry_count

