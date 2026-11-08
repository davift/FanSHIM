# FanSHIM

Turns the Fan SHIM on and off based on the Raspberry Pi CPU temperature. Runs as a systemd service.

Tested on Ubuntu 26.04 with a Raspberry Pi 4.

## Install

```bash
sudo ./install.sh
cd examples
sudo ./install-service.sh --on-threshold 55 --off-threshold 40 --delay 1 --preempt --noled --nobutton
```

`install.sh` installs the library into a virtual environment at `/opt/fanshim/venv`. `install-service.sh` creates and starts `fanshim.service`.

## Check status

The fan is on/off only. It has no speed sensor.

```bash
systemctl status fanshim.service                              # service running?
sudo cat /sys/kernel/debug/gpio | grep -iE 'gpio-18|fan'      # fan on (hi) or off (lo)
cat /sys/class/thermal/thermal_zone0/temp                     # CPU temp in millidegrees C
```

## Uninstall

```bash
sudo ./uninstall.sh
```

## Credits

Forked from [pimoroni/fanshim-python](https://github.com/pimoroni/fanshim-python) by Pimoroni Ltd. MIT licensed (see `LICENSE`).
