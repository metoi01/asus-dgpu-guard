#!/bin/sh
# Runs dgpu-guard.sh against a fake sysfs file. Needs no root and no ASUS hardware.
set -u
cd "$(dirname "$0")/.."
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export DGPU_GUARD_ATTR="$T/dgpu_disable" DGPU_GUARD_STATE="$T/state" DGPU_GUARD_WAIT=1
export DGPU_GUARD_REBOOT="touch $T/reboot-called"
fail=0
check() { if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; fail=1; fi; }

echo 0 > "$DGPU_GUARD_ATTR"
./dgpu-guard.sh >/dev/null
check "enabled dGPU: no reboot"           "[ ! -e $T/reboot-called ]"

echo 1 > "$DGPU_GUARD_ATTR"
./dgpu-guard.sh >/dev/null
check "disabled dGPU: flag written to 0"  "[ \"\$(cat $DGPU_GUARD_ATTR)\" = 0 ]"
check "disabled dGPU: reboot requested"   "[ -e $T/reboot-called ]"
check "disabled dGPU: marker left"        "[ -e $T/state/rebooted ]"

rm -f "$T/reboot-called"; echo 1 > "$DGPU_GUARD_ATTR"
./dgpu-guard.sh >/dev/null 2>&1; rc=$?
check "still disabled after reboot: no second reboot" "[ ! -e $T/reboot-called ]"
check "still disabled after reboot: exits non-zero"   "[ $rc -ne 0 ]"

echo 0 > "$DGPU_GUARD_ATTR"
./dgpu-guard.sh >/dev/null
check "back to normal: marker cleared"    "[ ! -e $T/state/rebooted ]"

DGPU_GUARD_ATTR="$T/missing" ./dgpu-guard.sh >/dev/null; rc=$?
check "no ASUS attribute: skips cleanly"  "[ $rc -eq 0 ] && [ ! -e $T/reboot-called ]"

exit $fail
