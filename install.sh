#!/bin/sh
# Installs dgpu-guard. Works on regular distros and on image-based ones
# (Bazzite, Silverblue, ...) because /usr/local and /etc are writable there.
set -e
[ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
cd "$(dirname "$0")"
install -Dm755 dgpu-guard.sh /usr/local/bin/dgpu-guard.sh
install -Dm644 dgpu-guard.service /etc/systemd/system/dgpu-guard.service
systemctl daemon-reload
systemctl enable dgpu-guard.service
systemctl start dgpu-guard.service
systemctl --no-pager status dgpu-guard.service | head -n 8
