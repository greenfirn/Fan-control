NVIDIA Fan Control Stack (Headless / Passthrough-Safe)

This stack provides reliable NVIDIA fan control on headless Linux systems, including
systems that frequently enter compute / passthrough mode (e.g. mining, AI workloads).

It is designed to:
- Use manual fan curves when Xorg + NV-CONTROL are available
- Fall back to firmware fan control + safe clock “bounce” when Xorg is blocked
- Survive GPU resets, driver reloads, and heavy compute workloads
- Run cleanly under systemd

======================================================================

DIRECTORY LAYOUT

fan-control/
├── bin/
│   ├── detect-passthrough.sh
│   ├── generate-xorg-config.sh
│   ├── fan-reset.sh
│   └── fan-curve.sh
├── systemd/
│   ├── xorg-nvidia.service
│   └── fan-curve.service
└── README.txt

======================================================================

EXECUTABLE SCRIPTS

/usr/local/bin/detect-passthrough.sh
------------------------------------
Purpose:
- Detects whether a GPU is in compute / passthrough mode
- Used for both manual testing and internal fan-curve logic

Detection logic:
- NV-CONTROL unavailable
- NVML temperature available
- GPU utilization > 40%

Usage:
  detect-passthrough.sh <gpu_index>

Exit codes:
  0 = passthrough / compute mode
  1 = normal mode


/usr/local/bin/generate-xorg-config.sh
--------------------------------------
Purpose:
- Auto-generates a headless Xorg configuration at boot
- Enables Coolbits and NV-CONTROL fan access
- Safe even when GPUs are busy

Output:
  /etc/X11/xorg.conf

Used by:
- xorg-nvidia.service (ExecStartPre)


/usr/local/bin/fan-reset.sh
---------------------------
Purpose:
- Resets all detected GPU fans back to AUTO mode
- Safe when Xorg is down or unavailable
- Never resets GPUs or kills workloads

Used by:
- fan-curve.service (ExecStop)


/usr/local/bin/fan-curve.sh
---------------------------
Purpose:
- Main fan control loop
- Automatically switches between:
  * Xorg mode (manual fan curve)
  * Firmware mode (monitor + clock bounce)

Behavior:
- Never changes power limits or persistent clocks
- Uses safe clock re-lock/unlock to wake firmware fan control
- Continues operating even if Xorg crashes

Depends on:
- detect-passthrough.sh

======================================================================

SYSTEMD SERVICES

/etc/systemd/system/xorg-nvidia.service
---------------------------------------
Purpose:
- Runs a minimal headless Xorg server
- Enables NV-CONTROL and manual fan control
- Regenerates Xorg config on each start

Key properties:
- Restart-safe
- May fail temporarily if GPU is compute-locked
- Does not block fan-curve.service


/etc/systemd/system/fan-curve.service
-------------------------------------
Purpose:
- Runs fan-curve.sh continuously
- Operates with or without Xorg

Key behavior:
- Starts even if Xorg is unavailable
- Resets fans to AUTO on stop
- Automatically restarts on failure

======================================================================

INSTALLATION SUMMARY

sudo install -m 755 bin/*.sh /usr/local/bin/
sudo cp systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable xorg-nvidia.service
sudo systemctl enable fan-curve.service
sudo systemctl start xorg-nvidia.service
sudo systemctl start fan-curve.service

======================================================================

MONITORING & DEBUGGING

systemctl status xorg-nvidia.service
systemctl status fan-curve.service

journalctl -u xorg-nvidia.service -f
journalctl -u fan-curve.service -f

Manual passthrough test:
  detect-passthrough.sh 0

======================================================================

SAFETY GUARANTEES

This stack:
- Does NOT reset GPUs
- Does NOT kill workloads
- Does NOT alter power limits
- Does NOT require displays
- Survives compute-only workloads
- Survives GPU resets and driver reloads

======================================================================

INTENDED USE CASES

- Mining rigs
- AI / ML compute servers
- Headless GPU farms
- Systems using OctaSpace, Clore, Vast.ai, or bare-metal Docker workloads
