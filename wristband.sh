#!/bin/zsh
EXIT_CODE="$1"
COMMAND="$2"
OUTPUT="$3"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
LOG_FILE="error_sense.log"
PATTERN_FILE="error_patterns.log"

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

ERROR_SIGNATURE=0
DISPLAY_CMD_PATTERN='^(cat|head|tail|less|more|bat|xxd|hexdump)\b'

if [[ "$COMMAND" =~ $DISPLAY_CMD_PATTERN ]]; then
    if [[ "$EXIT_CODE" != "0" ]]; then
        ERROR_SIGNATURE=1
    fi
else
    if echo "$OUTPUT" | grep -qiE "\berror\b|\bexception\b|traceback|no such (file|table)|command not found|permission denied|syntaxerror|fatal:|panic|cannot |\bfailed\b|not found|\bdenied\b|\brefused\b|timed out|\bkilled\b|unable to"; then
        ERROR_SIGNATURE=1
    fi
fi

if [[ "$EXIT_CODE" != "0" || $ERROR_SIGNATURE -eq 1 ]]; then
    STATUS="FAILURE"
else
    STATUS="SUCCESS"
fi

if [[ "$STATUS" == "SUCCESS" ]]; then
    REASON="SUCCESS"
    WHERE="none"
    PIVOT="Proceed."
else
    if echo "$OUTPUT" | grep -qi "os error 13"; then
        REASON="OS_PERMISSION_ERROR"
        WHERE="system execution substrate (os error 13)"
        PIVOT="DIRECT FIX: The OS denied execution. Ensure the binary or script has execute permissions (chmod +x) or execute via zsh explicitly."
    elif echo "$OUTPUT" | grep -q "No such file or directory"; then
        BADPATH=$(echo "$OUTPUT" | grep -o "'[^']*'" | head -1 | tr -d "'")
        WHERE="path '${BADPATH:-unknown}'"
        PIVOT="Check path and retry inside ${PATH_ROOT}."
    else
        REASON="GENERAL_FAILURE"
        WHERE="exit code ${EXIT_CODE}"
        PIVOT="Review output and adjust approach."
    fi
fi

# Reset / pattern logging
PATTERN_KEY="${REASON}|${WHERE}"
EXISTING=0
if [[ -f "$PATTERN_FILE" ]]; then
    EXISTING=$(grep -cF "$PATTERN_KEY" "$PATTERN_FILE" 2>/dev/null || echo 0)
fi
REPEAT_COUNT=$(( EXISTING + 1 ))
echo "${PATTERN_KEY}|TIME: ${TIMESTAMP}" >> "$PATTERN_FILE"

DIAGNOSIS="[ERROR_SENSE] [${TIMESTAMP}]
SUBSTRATE : ${OS} | ${MEMORY} | Thermal ${THERMAL} | Uptime ${UPTIME}
COMMAND   : ${COMMAND}
EXIT_CODE : ${EXIT_CODE}
STATUS    : ${STATUS}
REASON    : ${REASON}
WHERE     : ${WHERE}
PIVOT     : ${PIVOT}
REPEAT    : ${REPEAT_COUNT}
RAW       : ${OUTPUT}"

echo "$DIAGNOSIS" >> "$LOG_FILE"
echo "$DIAGNOSIS"
exit 0

