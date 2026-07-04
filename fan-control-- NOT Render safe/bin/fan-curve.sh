#!/bin/bash
set -Eeuo pipefail

DISPLAY=":0"
LOOP_INTERVAL=2
MIN_FAN_PCT=30
BOUNCE_INTERVAL=30

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-passthrough.sh"

log() { echo "[FAN] $(date '+%F %T') $*"; }

GPU_LIST=$(nvidia-smi --query-gpu=index --format=csv,noheader)
[[ -z "$GPU_LIST" ]] && exit 1

get_fans() {
    DISPLAY=$DISPLAY nvidia-settings -q fans 2>/dev/null | grep -o '\[fan:[0-9]\+\]'
}

has_xorg() {
    DISPLAY=$DISPLAY nvidia-settings -q gpus >/dev/null 2>&1
}

temp_to_pct() {
    (( $1 <= 36 )) && echo 30 ||
    (( $1 <= 42 )) && echo 65 ||
    (( $1 <= 44 )) && echo 75 ||
    (( $1 <= 54 )) && echo 85 ||
    (( $1 <= 62 )) && echo 90 || echo 100
}

declare -A LAST_PCT
LAST_BOUNCE=0
MODE=""

while true; do
    if has_xorg; then
        MODE="xorg"
        for GPU in $GPU_LIST; do
            TEMP=$(nvidia-smi --query-gpu=temperature.gpu \
                --format=csv,noheader,nounits -i "$GPU")
            PCT=$(temp_to_pct "$TEMP")
            [[ "${LAST_PCT[$GPU]:-}" == "$PCT" ]] && continue
            DISPLAY=$DISPLAY nvidia-settings -a "[gpu:$GPU]/GPUFanControlState=1" >/dev/null 2>&1
            for FAN in $(get_fans); do
                DISPLAY=$DISPLAY nvidia-settings -a "${FAN}/GPUTargetFanSpeed=$PCT" >/dev/null 2>&1
            done
            LAST_PCT[$GPU]=$PCT
        done
    else
        MODE="firmware"
        NOW=$(date +%s)
        if (( NOW - LAST_BOUNCE >= BOUNCE_INTERVAL )); then
            for GPU in $GPU_LIST; do
                CLK=$(nvidia-smi --query-gpu=clocks.gr --format=csv,noheader,nounits -i "$GPU")
                nvidia-smi -i "$GPU" -lgc "$CLK","$CLK" >/dev/null 2>&1
                sleep 0.3
                nvidia-smi -i "$GPU" -rgc >/dev/null 2>&1
            done
            LAST_BOUNCE=$NOW
        fi
    fi
    sleep "$LOOP_INTERVAL"
done
