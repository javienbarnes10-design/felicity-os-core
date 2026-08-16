#!/bin/zsh
# ─────────────────────────────────────────────
# FELICITY ERROR SENSE — wristband.sh
# Usage: ./wristband.sh <exit_code> <command> <output>
# NEVER SILENT. NEVER TRUSTS EXIT_CODE ALONE.
# Scans OUTPUT for error signatures regardless of exit code,
# and proactively looks up the correct answer where possible.
# ─────────────────────────────────────────────

EXIT_CODE="$1"
COMMAND="$2"
OUTPUT="$3"

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
LOG_FILE="error_sense.log"
PATTERN_FILE="error_patterns.log"

# ── SUBSTRATE SNAPSHOT ────────────────────────
HARDWARE="MacBook Air M4"
OS=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple M4")
MEMORY=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0fGB", $1/1073741824}' || echo "unknown")
THERMAL=$(df -h / 2>/dev/null | awk 'NR==2 {print "used " $3", " $5" full"}' || echo "unknown")
UPTIME=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' | xargs)
PATH_ROOT="/Users/javienbarnes/felicity_forge"
DB_PATH="${PATH_ROOT}/sovereign.db"

STATUS="UNKNOWN"
REASON="UNCLASSIFIED"
WHERE="unspecified"
PIVOT=""
THEORY_OF_MIND=""
REPEAT_COUNT=0

# ─────────────────────────────────────────────
# ── STEP 1: DOES THE OUTPUT DESCRIBE AN ERROR? ──
# Don't trust EXIT_CODE alone — many tools (sqlite3,
# python, osascript) print "Error: ..." but still
# return 0 from a shell's perspective.
# ─────────────────────────────────────────────

ERROR_SIGNATURE=0
if echo "$OUTPUT" | grep -qiE "\berror\b|\bexception\b|traceback|no such (file|table)|command not found|permission denied|syntaxerror|fatal:|panic|cannot |\bfailed\b|not found|\bdenied\b|\brefused\b|timed out|\bkilled\b|unable to"; then
    ERROR_SIGNATURE=1
fi

if [[ "$EXIT_CODE" != "0" || $ERROR_SIGNATURE -eq 1 ]]; then
    STATUS="FAILURE"
else
    STATUS="SUCCESS"
fi

# ─────────────────────────────────────────────
# ── PATH 1: TRUE SUCCESS ──────────────────────
# ─────────────────────────────────────────────

if [[ "$STATUS" == "SUCCESS" ]]; then
    if [[ -z "$OUTPUT" || "$OUTPUT" == "STRIKE_EXECUTED_SILENTLY" ]]; then
        REASON="SILENT_SUCCESS"
        WHERE="no stdout or stderr produced"
        PIVOT="No output is expected for many commands (mkdir, cp, mv, osascript sends, file writes). If you need confirmation, use a read-only check (ls, cat, sqlite3 select) rather than re-running this command."
        THEORY_OF_MIND="[THEORY_OF_MIND]: Clean, silent success. Proceed to your next step. Do not re-run this to 'check' it."
    else
        REASON="SUCCESS_WITH_OUTPUT"
        WHERE="stdout/stderr captured below in RAW"
        PIVOT="Command completed successfully and returned data. Read RAW carefully — it may contain the answer to your task."
        THEORY_OF_MIND="[THEORY_OF_MIND]: Clean exit with output. Proceed using the RAW data. No retry needed."
    fi

# ─────────────────────────────────────────────
# ── PATH 2: FAILURE — DIAGNOSE + PROACTIVELY FIX ──
# ─────────────────────────────────────────────

else
    if echo "$OUTPUT" | grep -qi "no such table:"; then
        REASON="SQLITE_MISSING_TABLE"
        MISSING_TABLE=$(echo "$OUTPUT" | grep -oi "no such table: [a-zA-Z_0-9]*" | awk '{print $NF}')
        REAL_TABLES=$(sqlite3 "${DB_PATH}" ".tables" 2>/dev/null)
        WHERE="database '${DB_PATH}' — table '${MISSING_TABLE}' does not exist"
        if [[ -n "$REAL_TABLES" ]]; then
            PIVOT="DIRECT FIX: Table '${MISSING_TABLE}' does not exist in ${DB_PATH}. Retry your query NOW using one of these exact names instead: ${REAL_TABLES}. All data lives in sovereign.db — do not reference any other .db file."
        else
            PIVOT="Table '${MISSING_TABLE}' does not exist. Run [EXECUTE]: sqlite3 ${DB_PATH} .tables to confirm schema."
        fi

    elif echo "$OUTPUT" | grep -q "No such file or directory"; then
        REASON="MISSING_FILE_OR_PATH"
        BADPATH=$(echo "$OUTPUT" | grep -o "'[^']*'" | head -1 | tr -d "'")
        if [[ -z "$BADPATH" ]]; then
            BADPATH=$(echo "$OUTPUT" | grep -oE "/[^ :]+" | head -1)
        fi
        PARENT=$(dirname "$BADPATH" 2>/dev/null)
        WHERE="path '${BADPATH}' does not exist"
        if [[ -n "$PARENT" && -d "$PARENT" ]]; then
            ACTUAL_FILES=$(ls -F "$PARENT" 2>/dev/null | tr '\n' ' ')
            PIVOT="DIRECT FIX: '${BADPATH}' does not exist. The directory '${PARENT}' actually contains: ${ACTUAL_FILES}. Retry NOW using one of these real names, or create the file first with [EXECUTE]: cat > ${BADPATH} <<EOF ... EOF if it genuinely needs to be new."
        else
            PIVOT="The path '${BADPATH}' does not exist and its parent directory '${PARENT}' also doesn't exist. Run [EXECUTE]: ls -F ${PATH_ROOT} to see the real directory structure before retrying."
        fi

    elif echo "$OUTPUT" | grep -q "command not found"; then
        REASON="COMMAND_NOT_FOUND"
        WHERE=$(echo "$OUTPUT" | grep "command not found" | awk '{print $1}')
        WHERE="command '${WHERE}'"
        PIVOT="This binary is not installed on ${HARDWARE}. Do not retry the same command. Either install it with brew first, or find an alternative already available."

    elif echo "$OUTPUT" | grep -q "Permission denied"; then
        REASON="PERMISSION_DENIED"
        WHERE=$(echo "$OUTPUT" | grep "Permission denied" | awk '{print $NF}')
        WHERE="file/path '${WHERE}'"
        PIVOT="This substrate does not allow access to that path. Do not retry with the same target. Check ownership with [EXECUTE]: ls -la or use a path inside ${PATH_ROOT} instead."

    elif echo "$OUTPUT" | grep -q "Operation not permitted"; then
        REASON="MACOS_PERMISSION_BLOCK"
        WHERE="macOS privacy/security layer (TCC)"
        PIVOT="macOS is blocking this action (Automation, Accessibility, or Full Disk Access). Do not retry the same command — it will fail identically until permission is granted in System Settings > Privacy & Security. Acknowledge this and move to a different task."

    elif echo "$OUTPUT" | grep -q "zsh:.*no matches found"; then
        REASON="SHELL_GLOB_NO_MATCH"
        WHERE=$(echo "$OUTPUT" | grep "no matches found" | head -1)
        PIVOT="A wildcard pattern matched nothing. Run [EXECUTE]: ls -F first to see what actually exists, then use exact names."

    elif echo "$OUTPUT" | grep -q "SyntaxError"; then
        REASON="PYTHON_SYNTAX_ERROR"
        WHERE=$(echo "$OUTPUT" | grep -B1 "SyntaxError" | head -1)
        WHERE="python source: '${WHERE}'"
        PIVOT="DIRECT FIX: python3 -c does not support shell redirection (>) inside the string. Write the file using python's open() builtin instead, or write a .py file with [EXECUTE]: cat > script.py <<EOF ... EOF then run [EXECUTE]: python3 script.py"

    elif echo "$OUTPUT" | grep -q "syntax error"; then
        REASON="SHELL_SYNTAX_ERROR"
        WHERE=$(echo "$OUTPUT" | grep "syntax error" | head -1)
        WHERE="near: '${WHERE}'"
        PIVOT="The shell command was malformed. Rewrite the command from scratch with correct zsh syntax before retrying."

    elif echo "$OUTPUT" | grep -q "Traceback (most recent call last)"; then
        REASON="PYTHON_RUNTIME_ERROR"
        WHERE=$(echo "$OUTPUT" | tail -1)
        WHERE="python exception: '${WHERE}'"
        PIVOT="The Python script ran but raised an exception. Read the traceback, identify the failing line and exception type, and fix the logic before retrying."

    elif echo "$OUTPUT" | grep -q "ModuleNotFoundError\|ImportError"; then
        REASON="PYTHON_MODULE_MISSING"
        WHERE=$(echo "$OUTPUT" | grep -o "No module named '[^']*'" | head -1)
        WHERE="${WHERE:-unknown module}"
        PIVOT="DIRECT FIX: install the missing package first with [EXECUTE]: pip3 install <package> --break-system-packages, then retry the script."

    elif echo "$OUTPUT" | grep -q "no bin target named"; then
        REASON="CARGO_BIN_NOT_FOUND"
        WHERE="cargo manifest — bin does not exist in ${PATH_ROOT}/Cargo.toml"
        PIVOT=".sh and .py files cannot be run as cargo bins. Use [EXECUTE]: zsh <script>.sh or [EXECUTE]: python3 <script>.py instead."

    elif echo "$OUTPUT" | grep -q "error\[E"; then
        REASON="RUST_COMPILE_ERROR"
        WHERE=$(echo "$OUTPUT" | grep "error\[E" | head -1)
        WHERE="rust source: '${WHERE}'"
        PIVOT="There is a compile error in the Rust source. Read the full error, identify the file and line, and correct the code before building again."

    elif echo "$OUTPUT" | grep -q "fatal:"; then
        REASON="GIT_ERROR"
        WHERE=$(echo "$OUTPUT" | grep "fatal:" | head -1)
        PIVOT="Git reported a fatal error. Check repo state first with [EXECUTE]: git status before attempting again."

    elif echo "$OUTPUT" | grep -q "connection refused\|Connection refused"; then
        REASON="NETWORK_CONNECTION_REFUSED"
        WHERE=$(echo "$OUTPUT" | grep -oiE "http[s]?://[^ ]+" | head -1)
        WHERE="endpoint '${WHERE:-unknown}'"
        PIVOT="Nothing is listening at that address. Check if the service is running before retrying."

    elif echo "$OUTPUT" | grep -q "Name or service not known\|Could not resolve\|nodename nor servname"; then
        REASON="DNS_RESOLUTION_FAILED"
        WHERE=$(echo "$OUTPUT" | grep -oiE "(http[s]?://[^ ]+|[a-zA-Z0-9_.-]+@[a-zA-Z0-9_.-]+)" | head -1)
        WHERE="host '${WHERE:-unknown}'"
        PIVOT="DNS cannot resolve this hostname. The host is likely a placeholder, not a real machine. Do not retry the same hostname — if this requires a real remote machine, ask Javien for its real address."

    elif echo "$OUTPUT" | grep -q "Address already in use"; then
        REASON="PORT_IN_USE"
        WHERE=$(echo "$OUTPUT" | grep -oi "port [0-9]*" | head -1)
        PIVOT="Check what's using the port with [EXECUTE]: lsof -i :<port> or pick a different port."

    elif echo "$OUTPUT" | grep -q "Read-only file system"; then
        REASON="READONLY_FILESYSTEM"
        WHERE="filesystem — check [EXECUTE]: mount | grep read-only"
        PIVOT="The target is on a read-only mount. Use a path inside ${PATH_ROOT} which should be writable."

    elif echo "$OUTPUT" | grep -q "Killed\|killed"; then
        REASON="PROCESS_KILLED_OOM"
        WHERE="memory — ${HARDWARE}, ${MEMORY}"
        PIVOT="Break the task into smaller operations or free memory first with [EXECUTE]: top -l 1 | head -20"

    elif echo "$OUTPUT" | grep -q "FILE_READ_ERROR\|NO_FRAME"; then
        REASON="VISION_CAPTURE_FAILED"
        WHERE="ffmpeg frame capture — check phone stream at 100.99.242.53:4747"
        PIVOT="Verify the stream is live with [EXECUTE]: curl -I http://100.99.242.53:4747/video before retrying LOOK."

    elif echo "$OUTPUT" | grep -qi "JSON_PARSE_ERROR\|NETWORK_ERROR\|EMPTY_RESPONSE_FROM_MODEL"; then
        REASON="OLLAMA_RESPONSE_FAILURE"
        WHERE="Ollama at 127.0.0.1:11434"
        PIVOT="HARDSTOP: The network bus is down. Do NOT generate another execution plan right now. Output a status warning stating 'NET_BUS_TIMEOUT' and wait for connection to stabilize."

    else
        REASON="REPORTED_ERROR_IN_OUTPUT"
        WHERE="exit code ${EXIT_CODE} — output describes a problem"
        PIVOT="The output contains language indicating failure even though it may not match a known pattern. Treat this strike as FAILED. Read the message, form your own hypothesis about the cause, and pivot — do not repeat the exact same command."
    fi

fi

# ─────────────────────────────────────────────
# ── THEORY OF MIND — PATTERN DETECTION ───────
# NOTE: Uses grep -c on the log file directly.
# No glob expansion. No filesystem walk.
# Prevents "Argument list too long" errors.
# ─────────────────────────────────────────────

if [[ "$STATUS" == "FAILURE" ]]; then
    PATTERN_KEY="${REASON}|${WHERE}"

    if [[ -f "$PATTERN_FILE" ]]; then
        EXISTING=$(grep -cF "$PATTERN_KEY" "$PATTERN_FILE" 2>/dev/null)
        EXISTING=$(( ${EXISTING:-0} + 0 ))
    else
        EXISTING=0
    fi

    REPEAT_COUNT=$(( EXISTING + 1 ))
    echo "${PATTERN_KEY}|TIME: ${TIMESTAMP}" >> "$PATTERN_FILE"

    if [[ $REPEAT_COUNT -eq 2 ]]; then
        THEORY_OF_MIND="[THEORY_OF_MIND]: LOOP DETECTED — Second identical failure. The PIVOT info did not get applied. Re-read it and apply it literally this time. Do NOT repeat the exact failing command again."
    elif [[ $REPEAT_COUNT -ge 3 ]]; then
        THEORY_OF_MIND="[THEORY_OF_MIND]: HARD LOOP — ${REPEAT_COUNT} identical failures. Abandon this approach entirely. Use the substrate map and the PIVOT info above to try something structurally different. Do not ask Javien — solve it yourself."
    fi
fi

# ── FORMAT FULL DIAGNOSIS ─────────────────────
DIAGNOSIS="[ERROR_SENSE] [${TIMESTAMP}]
SUBSTRATE : ${OS} | ${MEMORY} | Thermal ${THERMAL} | Uptime ${UPTIME}
ROOT      : ${PATH_ROOT}
DB        : ${DB_PATH}
COMMAND   : ${COMMAND}
EXIT_CODE : ${EXIT_CODE}
STATUS    : ${STATUS}
REASON    : ${REASON}
WHERE     : ${WHERE}
PIVOT     : ${PIVOT}
REPEAT    : ${REPEAT_COUNT}
${THEORY_OF_MIND}
RAW       : ${OUTPUT}"

# ── LOG IT ────────────────────────────────────
echo "$DIAGNOSIS" >> "$LOG_FILE"

# ── PRINT FOR FELICITY TO READ ────────────────
echo "$DIAGNOSIS"

exit 0

