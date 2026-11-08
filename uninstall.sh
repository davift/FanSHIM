#!/bin/bash

LIBRARY_NAME=`cat library/setup.cfg | grep name | awk -F" = " '{print $2}'`
LIBRARY_VERSION=`cat library/setup.cfg | grep version | awk -F" = " '{print $2}'`

# Must match the location used by install.sh.
VENV_DIR="${FANSHIM_VENV:-/opt/fanshim/venv}"
SERVICE_PATH=/etc/systemd/system/pimoroni-fanshim.service

printf "$LIBRARY_NAME $LIBRARY_VERSION Python Library: Uninstaller\n\n"

if [ "$(id -u)" -ne 0 ]; then
	printf "Script must be run as root. Try 'sudo ./uninstall.sh'\n"
	exit 1
fi

# Stop and remove the systemd service if it was installed.
if [ -f "$SERVICE_PATH" ]; then
	printf "Removing service: $SERVICE_PATH\n"
	systemctl stop pimoroni-fanshim.service 2>/dev/null || true
	systemctl disable pimoroni-fanshim.service 2>/dev/null || true
	rm -f "$SERVICE_PATH"
	systemctl daemon-reload
fi

# Remove the virtual environment created by install.sh.
if [ -d "$VENV_DIR" ]; then
	printf "Removing virtual environment: $VENV_DIR\n"
	rm -rf "$VENV_DIR"
fi

printf "Done!\n"
