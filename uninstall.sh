#!/bin/sh
set -e
[ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
systemctl disable dgpu-guard.service 2>/dev/null || true
rm -f /etc/systemd/system/dgpu-guard.service /usr/local/bin/dgpu-guard.sh
rm -rf /var/lib/dgpu-guard
systemctl daemon-reload
echo "dgpu-guard removed."
