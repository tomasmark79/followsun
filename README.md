# Folowsun - GNOME theme switcher based on sunrise/sunset

# Usage

```bash
Usage: folowsun.sh [OPTION]

Options:
  --help         Show this help
  --set-location LAT LON  Set your latitude and longitude
  --set-offset SUNRISE_OFFSET SUNSET_OFFSET  Set offsets in minutes
  --force-light  Force light theme
  --force-dark   Force dark theme
  --auto         Apply the appropriate theme based on current time
  --daemon       Run as daemon, changing themes at sunrise/sunset

Current configuration:
  Location: 49.8682576, 14.2626625
  Sunrise offset: 0 minutes
  Sunset offset: 0 minutes

```

# systemd service

Save **folowsun.service** to `~/.config/systemd/user/`

```bash
systemctl --user enable folowsun.service
systemctl --user start folowsun.service
```

status output

```bash
❯ systemctl --user status folowsun.service
● folowsun.service - Folowsun - GNOME theme switcher based on sunrise/sunset
     Loaded: loaded (/home/tomas/.config/systemd/user/folowsun.service; enabled; preset: disabled)
    Drop-In: /usr/lib/systemd/user/service.d
             └─10-timeout-abort.conf
     Active: active (running) since Tue 2025-04-01 19:07:50 CEST; 4s ago
 Invocation: 4eb8c0e0f78b448cb0350d4554b38585
    Process: 721379 ExecStartPre=/bin/sh -c mkdir -p ${CONFIG_DIR} (code=exited, status=0/SUCCESS)
   Main PID: 721381 (folowsun.sh)
      Tasks: 2 (limit: 67032)
     Memory: 876K (peak: 4.8M)
        CPU: 109ms
     CGroup: /user.slice/user-1000.slice/user@1000.service/app.slice/folowsun.service
             ├─721381 /bin/bash /home/tomas/dev/bash/folowsun/folowsun.sh --daemon
             └─721449 sleep 1689

Apr 01 19:07:50 bluediamond systemd[2168]: Starting folowsun.service - Folowsun - GNOME theme switcher based on sunrise/sunset...
Apr 01 19:07:50 bluediamond systemd[2168]: Started folowsun.service - Folowsun - GNOME theme switcher based on sunrise/sunset.
Apr 01 19:07:50 bluediamond folowsun.sh[721381]: Starting folowsun daemon
Apr 01 19:07:51 bluediamond folowsun.sh[721381]: Next change time extracted: 19:36
Apr 01 19:07:51 bluediamond folowsun.sh[721381]: Sleeping for 1689 seconds until next change
```