#!/bin/sh
set -e

if ! occtl show status > /dev/null 2>&1; then
  echo "[healthcheck] ERROR: occtl status failed"
  exit 1
fi

exit 0
