#!/bin/bash

# Must match the location used by install.sh.
VENV_DIR="${FANSHIM_VENV:-/opt/fanshim/venv}"

if [ "$(id -u)" -ne 0 ]; then
	printf "Script must be run as root. Try 'sudo ./uninstall.sh'\n"
	exit 1
fi

# Stop and remove the service (current and legacy names).
for SERVICE in fanshim.service pimoroni-fanshim.service; do
	if [ -f "/etc/systemd/system/$SERVICE" ]; then
		printf "Removing service: $SERVICE\n"
		systemctl disable --now "$SERVICE" 2>/dev/null || true
		rm -f "/etc/systemd/system/$SERVICE"
	fi
done
systemctl daemon-reload

# Remove the virtual environment created by install.sh.
if [ -d "$VENV_DIR" ]; then
	printf "Removing virtual environment: $VENV_DIR\n"
	rm -rf "$VENV_DIR"
fi

printf "Done!\n"
