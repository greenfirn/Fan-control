#!/bin/bash
set -euo pipefail

DISPLAY=":0"

FANS=$(DISPLAY=$DISPLAY nvidia-settings -q fans 2>/dev/null | grep -o '\[fan:[0-9]\+\]' || true)
[[ -z "$FANS" ]] && exit 0

for FAN in $FANS; do
    DISPLAY=$DISPLAY nvidia-settings -a "${FAN}/GPUTargetFanSpeed=0" >/dev/null 2>&1 || true
done
