#!/bin/sh
set -e

if ! /opt/ocserv/bin/occtl show status > /dev/null 2>&1; then
  echo "[healthcheck] ERROR: occtl status failed"
  exit 1
fi

if [ "$EXPORTER_ENABLED" = "1" ]; then
  BIND="${EXPORTER_BIND:-127.0.0.1:8000}"
  IP="${BIND%:*}"
  PORT="${BIND##*:}"

  if ! curl -sf "http://${IP}:${PORT}/metrics" > /dev/null; then
    echo "[healthcheck] ERROR: failed to fetch metrics from http://${IP}:${PORT}/metrics"
    exit 1
  fi
fi

exit 0
