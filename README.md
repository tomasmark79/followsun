# FollowSun - GNOME theme switcher based on sunrise/sunset

# Usage

```txt
Usage: followsun.sh [OPTION]

Options:
  --help         Show this help
  --set-location <LAT> <LON>  Set your latitude and longitude
  --set-offset   <SUNRISE_OFFSET> <SUNSET_OFFSET>  Set offsets in minutes
  --force-light  Force light theme
  --force-dark   Force dark theme
  --auto         Apply the appropriate theme based on current time
  
Current configuration:
  Location: 49.8682576, 14.2626625
  Sunrise offset: 0 minutes
  Sunset offset: 0 minutes

```

# Systemd Service

Systemd timer bude spouštět v zadaném intervalu `followsun.sh`. Edit, and copy `followsun.service` and `followsun.timer` to the destination `~/.config/systemd/user/`. Afterwards enable and start systemd service and timer.

```bash
systemctl --user enable followsun.service
systemctl --user start followsun.service

systemctl --user enable followsun.timer
systemctl --user start followsun.timer
```


