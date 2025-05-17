# FollowSun

FollowSun The GNOME theme switcher based on sunrise/sunset

## Usage

```txt
Usage: followsun.sh [OPTION]

Options:
  --help         Show this help
  --set-location <LAT> <LON> Set your latitude and longitude
  --set-offset   <SUNRISE_OFFSET> <SUNSET_OFFSET> Set offsets in minutes
  --force-light  Force light theme
  --force-dark   Force dark theme
  --auto         Apply the appropriate theme based on current time
  --verbose      The same as --auto with verbose debugging output

Current configuration:
  Location: 49.1111, 14.9999
  Sunrise offset: 0 minutes
  Sunset offset: 0 minutes

Note: For offline sun calculation, place a sun_calculator.py script in the same
      directory as this script. It should accept latitude, longitude, and offsets
      as parameters and output 'SOURCE HH:MM HH:MM' for sunrise and sunset.
```

## Systemd Service `followsun.service` is triggered by Systemd Timer `followsun.timer`

### copy and edit as you wish both to

`~/.config/systemd/user`

### then 

```bash
systemctl --user daemon-reload
```

### enable and start timer

```bash
systemctl --user enable followsun.timer
systemctl --user start followsun.timer
systemctl --user status followsun.timer
systemctl --user list-timers
```

### enable and start service 

```bash
systemctl --user start followsun.service
systemctl --user status followsun.service
```

### systemd logs

```bash
journalctl --user-unit=followsun.service
journalctl --user-unit=followsun.timer
```

### bash script `followsun.sh` and python helper `sun_calculator.py`

Make sure these two files are located in the directory specified path in the  Systemd Service file.

---

Due to issues with running the script immediately after the computer wakes from sleep, I have permanently removed this script from the repository and instead reduced the timer interval for Systemd Service.


