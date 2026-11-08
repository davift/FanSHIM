#!/bin/bash

# Installs the fanshim library into an isolated virtual environment.
# Uses rpi-lgpio, a drop-in replacement for RPi.GPIO that works on current kernels.

set -euo pipefail

# Location of the virtual environment. Override with FANSHIM_VENV=...
VENV_DIR="${FANSHIM_VENV:-/opt/fanshim/venv}"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [ "$(id -u)" -ne 0 ]; then
	printf "Script must be run as root. Try 'sudo ./install.sh'\n"
	exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
	printf "This installer requires a Debian/Ubuntu based system (apt not found).\n"
	exit 1
fi

# System dependencies. swig, liblgpio-dev, build-essential and python3-dev are
# needed to build lgpio from source, since there's no prebuilt wheel for newer
# Python versions.
apt update
apt install -y python3 python3-venv python3-dev python3-pip build-essential swig liblgpio-dev

# The old python3-rpi.gpio package conflicts with rpi-lgpio.
if dpkg -s python3-rpi.gpio >/dev/null 2>&1; then
	apt remove -y python3-rpi.gpio || true
fi

if [ ! -d "$VENV_DIR" ]; then
	mkdir -p "$(dirname "$VENV_DIR")"
	python3 -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/pip" install --upgrade pip setuptools wheel
"$VENV_DIR/bin/pip" install --upgrade rpi-lgpio apa102 psutil
"$VENV_DIR/bin/pip" install --upgrade "$DIR/library"

if ! "$VENV_DIR/bin/python" -c "import fanshim" >/dev/null 2>&1; then
	printf "\nInstalled, but 'import fanshim' failed. Check the output above.\n"
	exit 1
fi

printf "\nDone! Installed into %s\n" "$VENV_DIR"
printf "Next, install the service:\n"
printf "    cd %s/examples && sudo ./install-service.sh\n" "$DIR"
