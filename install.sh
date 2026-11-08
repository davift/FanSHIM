#!/bin/bash

# FanSHIM installer
#
# Modernised for Python 3 and PEP 668 "externally-managed-environment"
# (Ubuntu 24.04 / 26.04, Raspberry Pi OS Bookworm and newer).
#
# What changed vs. the original installer:
#   * Python 2 support dropped entirely (it no longer exists on modern distros).
#   * No more `python setup.py install` (removed from modern setuptools) or
#     system-wide `pip install` (blocked by PEP 668). Everything is installed
#     into an isolated virtual environment instead.
#   * Uses `rpi-lgpio` (a drop-in replacement for `RPi.GPIO`) so the GPIO code
#     keeps working on current kernels. The library's Python code is unchanged.

set -euo pipefail

LIBRARY_NAME="fanshim"
# Location of the isolated virtual environment. Override with FANSHIM_VENV=...
VENV_DIR="${FANSHIM_VENV:-/opt/fanshim/venv}"

# Absolute path to the directory this script lives in.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

printf "FanSHIM Python Library: Installer\n\n"

if [ "$(id -u)" -ne 0 ]; then
	printf "Script must be run as root. Try 'sudo ./install.sh'\n"
	exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
	printf "This installer expects a Debian/Ubuntu based system (apt not found).\n"
	printf "On other distributions, install python3/python3-venv, swig and the lgpio C library (liblgpio-dev) manually and then run:\n"
	printf "    python3 -m venv %s\n" "$VENV_DIR"
	printf "    %s/bin/pip install rpi-lgpio apa102 psutil %s/library\n" "$VENV_DIR" "$DIR"
	exit 1
fi

# 1. System build/runtime dependencies via apt.
#
# On newer Python (e.g. 3.14 on Ubuntu 26.04 / aarch64) there is no prebuilt
# `lgpio` wheel yet, so pip builds it from source. That build needs:
#   * build-essential + python3-dev : C compiler and Python headers
#   * swig                          : generates the C wrapper (lgpio_wrap.c)
#   * liblgpio-dev                  : the lgpio C library to link against (-llgpio)
# This matches the Raspberry Pi / gpiozero recommended build dependencies.
printf "Installing system dependencies...\n"
apt update
apt install -y python3 python3-venv python3-dev python3-pip build-essential swig liblgpio-dev

# The classic python3-rpi.gpio package clashes with rpi-lgpio and no longer
# works on current kernels. We only touch it if it is actually installed.
if dpkg -s python3-rpi.gpio >/dev/null 2>&1; then
	printf "Removing obsolete system package python3-rpi.gpio (replaced by rpi-lgpio)...\n"
	apt remove -y python3-rpi.gpio || true
fi

# 2. Create an isolated virtual environment (PEP 668 safe).
if [ ! -d "$VENV_DIR" ]; then
	printf "Creating virtual environment at %s\n" "$VENV_DIR"
	mkdir -p "$(dirname "$VENV_DIR")"
	python3 -m venv "$VENV_DIR"
fi

# 3. Install the library and its dependencies into the venv.
printf "Installing %s and dependencies into the virtual environment...\n" "$LIBRARY_NAME"
"$VENV_DIR/bin/pip" install --upgrade pip setuptools wheel
# rpi-lgpio provides the RPi.GPIO API on top of lgpio (works on current kernels).
# apa102 drives the RGB LED; psutil is used by the automatic.py example/service.
"$VENV_DIR/bin/pip" install --upgrade rpi-lgpio apa102 psutil
"$VENV_DIR/bin/pip" install --upgrade "$DIR/library"

# 4. Quick sanity check that the package imports.
if "$VENV_DIR/bin/python" -c "import fanshim" >/dev/null 2>&1; then
	printf "\nDone! '%s' installed successfully.\n" "$LIBRARY_NAME"
else
	printf "\nInstalled, but 'import fanshim' failed. Please check the output above.\n"
	exit 1
fi

printf "\nFanSHIM lives in the virtual environment: %s\n\n" "$VENV_DIR"
printf "Try an example (needs root for GPIO access):\n"
printf "    sudo %s/bin/python %s/examples/automatic.py --verbose\n\n" "$VENV_DIR" "$DIR"
printf "Install the background service (fan runs automatically on boot):\n"
printf "    cd %s/examples && sudo ./install-service.sh --venv %s\n\n" "$DIR" "$VENV_DIR"
