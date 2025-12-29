#!/bin/bash
# Auto-generate a simple headless Xorg config for all NVIDIA GPUs.
# Safe to run even if compute workloads are active (Xorg may later fail to start, that's OK).

XORG_CONFIG="/etc/X11/xorg.conf"

echo "[XORG] Waiting briefly for NVIDIA modules..."
sleep 4

rm -f "$XORG_CONFIG"

echo "[XORG] Detecting NVIDIA GPUs via nvidia-smi..."
GPU_BUS_IDS=()

# Primary method: nvidia-smi PCI bus IDs
while IFS= read -r raw; do
    raw="${raw#00000000:}"   # strip leading 00000000: if present
    if [[ "$raw" =~ ^([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\.([0-9a-fA-F])$ ]]; then
        DOMAIN="${BASH_REMATCH[1]}"
        BUS="${BASH_REMATCH[2]}"
        SLOT="${BASH_REMATCH[3]}"
        XORG="PCI:$((16#$DOMAIN)):$((16#$BUS)):$SLOT"
        GPU_BUS_IDS+=("$XORG")
        echo "[XORG] Found GPU at $XORG"
    fi
done < <(nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader 2>/dev/null)

# Fallback: lspci if nvidia-smi is blocked
if [ ${#GPU_BUS_IDS[@]} -eq 0 ]; then
    echo "[XORG] nvidia-smi query failed, using lspci fallback..."
    while IFS= read -r dev; do
        if [[ "$dev" =~ ^([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\.([0-9a-fA-F])$ ]]; then
            DOMAIN="${BASH_REMATCH[1]}"
            BUS="${BASH_REMATCH[2]}"
            SLOT="${BASH_REMATCH[3]}"
            XORG="PCI:$((16#$DOMAIN)):$((16#$BUS)):$SLOT"
            GPU_BUS_IDS+=("$XORG")  
            echo "[XORG] Found GPU at $XORG (lspci)"
        fi
    done < <(lspci | grep -i nvidia | awk '{print $1}')
fi

if [ ${#GPU_BUS_IDS[@]} -eq 0 ]; then
    echo "[XORG] ERROR: No NVIDIA GPUs detected."
    exit 1
fi

echo "[XORG] Preparing config for ${#GPU_BUS_IDS[@]} GPU(s)."

cat > "$XORG_CONFIG" << 'CONFIG_EOF'
Section "ServerFlags"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
    Option "AutoAddDevices" "false"
    Option "AutoAddGPU" "false"
EndSection

Section "Module"
    Disable "glx"
EndSection

Section "ServerLayout"
    Identifier "Layout0"
CONFIG_EOF

# Layout screens
for i in "${!GPU_BUS_IDS[@]}"; do
    echo "    Screen $i \"Screen$i\" 0 0" >> "$XORG_CONFIG"
done

cat >> "$XORG_CONFIG" << 'CONFIG_EOF'
EndSection

Section "Monitor"
    Identifier "Monitor0"
    Option "DPMS" "false"
EndSection
CONFIG_EOF

# Per-GPU device/screen
for i in "${!GPU_BUS_IDS[@]}"; do
cat >> "$XORG_CONFIG" << EOF

Section "Device"
    Identifier "Device$i"
    Driver "nvidia"
    BusID "${GPU_BUS_IDS[$i]}"
    Option "Coolbits" "31"
    Option "AllowEmptyInitialConfiguration" "true"
    Option "UseDisplayDevice" "none"
EndSection

Section "Screen"
    Identifier "Screen$i"
    Device "Device$i"
    Monitor "Monitor0"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Virtual 1920 1080
    EndSubSection
EndSection
EOF
done

echo "[XORG] Generated config at $XORG_CONFIG"