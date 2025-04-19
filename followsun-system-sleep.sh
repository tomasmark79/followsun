#!/bin/bash

case $1 in
  post)
    # Run after wake up
    su tomas -c "XDG_RUNTIME_DIR=/run/user/$(id -u tomas) systemctl --user start followsun.service"
    ;;
esac
