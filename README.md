# FollowSun

GNOME theme switcher based on sunrise/sunset

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
  --debug        Run with verbose debugging output

Current configuration:
  Location: 49.1111, 14.9999
  Sunrise offset: 0 minutes
  Sunset offset: 0 minutes

Note: For offline sun calculation, place a sun_calculator.py script in the same
      directory as this script. It should accept latitude, longitude, and offsets
      as parameters and output 'SOURCE HH:MM HH:MM' for sunrise and sunset.
```

# Automatisation

service 

```bash
systemctl --user enable followsun.service
systemctl --user start followsun.service
systemctl --user status followsun.service
```

timer for service (instead of cron)

```bash
systemctl --user enable followsun.timer
systemctl --user start followsun.timer
systemctl --user status followsun.timer
systemctl --user list-timers
```

reload if we did changes within files

```bash
systemctl --user daemon-reload
```

logs

```bash
journalctl --user-unit=followsun.timer
```


