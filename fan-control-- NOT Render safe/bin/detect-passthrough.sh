#!/bin/bash
set -euo pipefail

DISPLAY=":0"

detect_passthrough_mode() {
    local GPU=$1

    local FANS
    FANS=$(DISPLAY=$DISPLAY nvidia-settings -q fans 2>/dev/null | grep -o '\[fan:[0-9]\+\]')
    local NVCONTROL_OK=1
    [[ -z "$FANS" ]] && NVCONTROL_OK=0

    local TEMP
    TEMP=$(nvidia-smi --query-gpu=temperature.gpu \
        --format=csv,noheader,nounits -i "$GPU" 2>/dev/null | tr -d '[:space:]')
    local NVML_OK=1
    [[ -z "$TEMP" || ! "$TEMP" =~ ^[0-9]+$ ]] && NVML_OK=0

    local UTIL
    UTIL=$(nvidia-smi --query-gpu=utilization.gpu \
        --format=csv,noheader,nounits -i "$GPU" 2>/dev/null | tr -d '[:space:]')
    local HEAVY_LOAD=0
    [[ "$UTIL" =~ ^[0-9]+$ && "$UTIL" -gt 40 ]] && HEAVY_LOAD=1

    (( NVCONTROL_OK == 0 && NVML_OK == 1 && HEAVY_LOAD == 1 ))
}

# Allow manual test
if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    if detect_passthrough_mode "$1"; then
        echo "PASSTHROUGH / COMPUTE MODE"
        exit 0
    else
        echo "NORMAL MODE"
        exit 1
    fi
fi
