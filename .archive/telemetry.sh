#!/bin/bash
# M4 SILICON THERMAL PROXY v1.0
THERMAL=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | cut -d% -f1 || echo "0")
BATT=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1 || echo "0")
RAM=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//' || echo "0")
echo "M4_LOAD_TEMP: ${THERMAL} | BATT: ${BATT}% | RAM_FREE: ${RAM}"
