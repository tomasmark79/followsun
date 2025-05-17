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

## Start followsun.service after wake up from suspend

> 💡 change user

`sudo vim /lib/systemd/system-sleep/followsun-wakeup`

```bash
#!/bin/bash
case $1 in
  post)
    su tomas -c "XDG_RUNTIME_DIR=/run/user/$(id -u tomas) systemctl --user start followsun.service"
    ;;
esac
````

`sudo chmod +x /lib/systemd/system-sleep/followsun-wakeup`

## Systemd service and timer for theme switching

### service 

```bash
systemctl --user enable followsun.service
systemctl --user start followsun.service
systemctl --user status followsun.service
```

### timer for service (instead of deprecated cron solution)

```bash
systemctl --user enable followsun.timer
systemctl --user start followsun.timer
systemctl --user status followsun.timer
systemctl --user list-timers
```

### reload if we did changes within files

```bash
systemctl --user daemon-reload
```

### logs

```bash
journalctl --user-unit=followsun.service
journalctl --user-unit=followsun.timer
```


