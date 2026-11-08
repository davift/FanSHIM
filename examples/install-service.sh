#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ON_THRESHOLD=65
OFF_THRESHOLD=55
HYSTERESIS=5
DELAY=2
PREEMPT="no"
POSITIONAL_ARGS=()
NOLED="no"
NOBUTTON="no"
BRIGHTNESS=255
EXTCOLOURS="no"

# FanSHIM is installed into an isolated virtual environment by install.sh.
# Default to that location; override with --venv <path> or FANSHIM_VENV=...
VENV="${FANSHIM_VENV:-/opt/fanshim/venv}"

ON_THRESHOLD_SET=false
OFF_THRESHOLD_SET=false

SERVICE_NAME=fanshim.service
SERVICE_PATH=/etc/systemd/system/$SERVICE_NAME
# Name used by older versions of this installer.
LEGACY_SERVICE=pimoroni-fanshim.service

USAGE="sudo ./install-service.sh --off-threshold <n> --on-threshold <n> --delay <n> --brightness <n> --low-temp <n> --high-temp <n> --venv <python_virtual_environment> (--preempt) (--noled) (--nobutton) (--extended-colours)"

while [[ $# -gt 0 ]]; do
	K="$1"
	case $K in
	-p|--preempt)
		if [ "$2" == "yes" ] || [ "$2" == "no" ]; then
			PREEMPT="$2"
			shift
		else
			PREEMPT="yes"
		fi
		shift
		;;
	-l|--noled)
		if [ "$2" == "yes" ] || [ "$2" == "no" ]; then
			NOLED="$2"
			shift
		else
			NOLED="yes"
		fi
		shift
		;;
	-b|--nobutton)
		if [ "$2" == "yes" ] || [ "$2" == "no" ]; then
			NOBUTTON="$2"
			shift
		else
			NOBUTTON="yes"
		fi
		shift
		;;
	-o|--on-threshold)
		ON_THRESHOLD="$2"
		ON_THRESHOLD_SET=true
		shift
		shift
		;;
	-f|--off-threshold)
		OFF_THRESHOLD="$2"
		OFF_THRESHOLD_SET=true
		shift
		shift
		;;
	-G|--low-temp)
		LOW_TEMP="$2"
		shift
		shift
		;;
	-R|--high-temp)
		HIGH_TEMP="$2"
		shift
		shift
		;;
	-d|--delay)
		DELAY="$2"
		shift
		shift
		;;
	-r|--brightness)
		BRIGHTNESS="$2"
		shift
		shift
		;;
	--venv)
		VENV="$(realpath "${2%/}")"
		shift
		shift
		;;
	-x|--extended-colours)
		if [ "$2" == "yes" ] || [ "$2" == "no" ]; then
			EXTCOLOURS="$2"
			shift
		else
			EXTCOLOURS="yes"
		fi
		shift
		;;
	*)
		if [[ $1 == -* ]]; then
			printf "Unrecognised option: $1\n";
			printf "Usage: $USAGE\n";
			exit 1
		fi
		POSITIONAL_ARGS+=("$1")
		shift
	esac
done

if [ "$(id -u)" -ne 0 ]; then
	printf "Script must be run as root. Try 'sudo ./install-service.sh'\n"
	exit 1
fi

PYTHON="$VENV/bin/python3"

if ! [ -x "$PYTHON" ]; then
	printf "Could not find a FanSHIM virtual environment at: %s\n" "$VENV"
	printf "Run the library installer first:\n"
	printf "    cd %s && sudo ./install.sh\n" "$(dirname "$DIR")"
	printf "or pass an existing environment with --venv <path>.\n"
	exit 1
fi

# Make sure the fanshim package is actually importable in this environment.
if ! "$PYTHON" -c "import fanshim" >/dev/null 2>&1; then
	printf "The 'fanshim' package is not installed in: %s\n" "$VENV"
	printf "Run the library installer first:\n"
	printf "    cd %s && sudo ./install.sh\n" "$(dirname "$DIR")"
	exit 1
fi

set -- "${POSITIONAL_ARGS[@]}"

EXTRA_ARGS=""

if [ "$PREEMPT" == "yes" ]; then
	EXTRA_ARGS+=' --preempt'
fi

if [ "$NOLED" == "yes" ]; then
	EXTRA_ARGS+=' --noled'
fi

if [ "$NOBUTTON" == "yes" ]; then
	EXTRA_ARGS+=' --nobutton'
fi

if [ "$EXTCOLOURS" == "yes" ]; then
	EXTRA_ARGS+=' --extended-colours'
fi

if ! [ "$1" == "" ]; then
	if [ $ON_THRESHOLD_SET ]; then
		printf "Refusing to overwrite explicitly set On Threshold ($ON_THRESHOLD) with positional argument!\n"
		printf "Please double-check your arguments and use one or the other!\n"
		exit 1
	fi
	ON_THRESHOLD=$1
fi

if ! [ "$2" == "" ]; then
	if [ $OFF_THRESHOLD_SET ]; then
		printf "Refusing to overwrite explicitly set Off Threshold ($OFF_THRESHOLD) with positional argument!\n"
		printf "Please double-check your arguments and use one or the other!\n"
		exit 1
	fi
	(( OFF_THRESHOLD = ON_THRESHOLD - $2 ))
fi

if [ "$LOW_TEMP" == "" ]; then
    LOW_TEMP=$OFF_THRESHOLD
fi

if [ "$HIGH_TEMP" == "" ]; then
    HIGH_TEMP=$ON_THRESHOLD
fi

cat << EOF
Setting up with:
Off Threshold:    $OFF_THRESHOLD C
On Threshold:     $ON_THRESHOLD C
Low Temp:         $LOW_TEMP C
High Temp:        $HIGH_TEMP C
Delay:            $DELAY seconds
Preempt:          $PREEMPT
Disable LED:      $NOLED
Disable Button:   $NOBUTTON
Brightness:       $BRIGHTNESS
Extended Colours: $EXTCOLOURS
Python:           $PYTHON

To change these options, run:
$USAGE

Or edit: $SERVICE_PATH


EOF

read -r -d '' UNIT_FILE << EOF
[Unit]
Description=Fan SHIM temperature control
After=multi-user.target

[Service]
Type=simple
WorkingDirectory=$DIR
ExecStart=$PYTHON $DIR/automatic.py --on-threshold $ON_THRESHOLD --off-threshold $OFF_THRESHOLD --low-temp $LOW_TEMP --high-temp $HIGH_TEMP --delay $DELAY --brightness $BRIGHTNESS $EXTRA_ARGS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Remove the service installed under the old name, so two services don't
# fight over the fan GPIO.
if [ -f "/etc/systemd/system/$LEGACY_SERVICE" ]; then
	printf "Removing old service: $LEGACY_SERVICE\n"
	systemctl disable --now "$LEGACY_SERVICE" 2>/dev/null || true
	rm -f "/etc/systemd/system/$LEGACY_SERVICE"
fi

printf "Installing service to: $SERVICE_PATH\n"
echo "$UNIT_FILE" > $SERVICE_PATH
systemctl daemon-reload
systemctl enable --no-pager $SERVICE_NAME
systemctl restart --no-pager $SERVICE_NAME
systemctl status --no-pager $SERVICE_NAME
