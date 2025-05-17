#!/bin/bash

case $1 in
  post)
    # Spustí se po probuzení (na pozadí, neblokuje)
    su tomas -c "XDG_RUNTIME_DIR=/run/user/$(id -u tomas) systemctl --user restart followsun.service" &
    ;;
esac
