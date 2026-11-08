#!/bin/sh
# dgpu-guard: re-enable an ASUS laptop's NVIDIA dGPU that Windows switched off in firmware.
#
# Armoury Crate (Windows) in "Optimized"/"Eco" mode cuts power to the dGPU on battery by setting
# the firmware flag dgpu_disable=1. The flag survives reboots and OS switches, so the next Linux
# boot sees a dGPU that is half there: the driver hangs probing it and the login screen stays black.
#
# This runs early in boot, before the GPU tools and the display manager:
#   dGPU enabled                 -> do nothing
#   dGPU disabled in firmware    -> set dgpu_disable=0 and reboot once (clean POST with the dGPU on)
#   still disabled after reboot  -> give up and log it, so we never end up in a reboot loop
#
# Logs: journalctl -b -u dgpu-guard

# Newer kernels (asus-armoury) and older kernels (asus-nb-wmi) expose the flag in different places.
if [ -n "$DGPU_GUARD_ATTR" ]; then
  CANDIDATES=$DGPU_GUARD_ATTR
else
  CANDIDATES="/sys/class/firmware-attributes/asus-armoury/attributes/dgpu_disable/current_value
/sys/devices/platform/asus-nb-wmi/dgpu_disable"
fi
STATE=${DGPU_GUARD_STATE:-/var/lib/dgpu-guard}
WAIT=${DGPU_GUARD_WAIT:-30}                       # half-second steps (30 = 15 s)
REBOOT=${DGPU_GUARD_REBOOT:-systemctl --no-block reboot}

log() { echo "dgpu-guard: $*"; }

# Wait for the ASUS platform driver to show up.
ATTR=""
i=0
while [ "$i" -lt "$WAIT" ]; do
  for c in $CANDIDATES; do
    if [ -e "$c" ]; then ATTR=$c; break 2; fi
  done
  sleep 0.5
  i=$((i + 1))
done
if [ -z "$ATTR" ]; then
  log "no dgpu_disable attribute found (not an ASUS dGPU laptop, or driver missing), skipping"
  exit 0
fi

mkdir -p "$STATE"

if [ "$(cat "$ATTR")" != 1 ]; then
  rm -f "$STATE/rebooted"          # all good: clear the marker from any earlier attempt
  log "dGPU is enabled, nothing to do"
  exit 0
fi

if [ -e "$STATE/rebooted" ]; then
  log "dGPU is still disabled after a reboot, giving up to avoid a reboot loop" >&2
  exit 1
fi

log "dGPU is disabled in firmware (probably Windows / Armoury Crate). Enabling it and rebooting."
if ! echo 0 > "$ATTR"; then
  log "could not write $ATTR" >&2
  exit 1
fi
touch "$STATE/rebooted"
sync
$REBOOT
