# --- write fan-curve.service ---

sudo tee /etc/systemd/system/fan-curve.service > /dev/null << 'EOF'
[Unit]
Description=NVIDIA Fan Curve Controller (NVML, no Xorg/Coolbits required)
After=multi-user.target nvidia-persistenced.service
Wants=nvidia-persistenced.service

StartLimitIntervalSec=0

[Service]
Type=simple
User=root

# Give persistence/driver a moment to settle at boot
ExecStartPre=/bin/bash -c 'sleep 3'

# Per-rig curve lives here — edit this line for each machine, then:
#   sudo systemctl daemon-reload && sudo systemctl restart fan-curve.service
ExecStart=/usr/bin/python3 /usr/local/bin/fan_curve.py \
    --interval 2 --hysteresis 2 \
    --cooldown-delta 10 --cooldown-seconds 15 \
    --curve "30:30,40:55,50:65,55:90,65:100"

# fan_curve.py resets fans to AUTO on SIGTERM before exiting, so no
# separate ExecStop/fan-reset.sh script is needed.
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#========================================================================================================
#========================================================================================================

# let systemd know about the new/changed service
sudo systemctl daemon-reload
sudo systemctl restart fan-curve.service

# show status
sleep 2
# sudo systemctl status fan-curve.service

# watch the live log
journalctl -u fan-curve.service -f

# stop / restart as needed
# sudo systemctl stop fan-curve.service
# sudo systemctl restart fan-curve.service
