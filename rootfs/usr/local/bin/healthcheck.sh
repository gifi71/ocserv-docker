#!/bin/sh
set -e

echo "[healthcheck] Starting ocserv health check..."

# Проверка ocserv
if /opt/ocserv/bin/occtl show status > /dev/null 2>&1; then
  echo "[healthcheck] occtl status: OK"
else
  echo "[healthcheck] ERROR: occtl status failed"
  exit 1
fi

# Проверка метрик, если включено
if [ "$EXPORTER_ENABLED" = "1" ]; then
  echo "[healthcheck] EXPORTER_ENABLED is set to 1, checking metrics..."

  BIND="${EXPORTER_BIND:-0.0.0.0:8000}"
  PORT="${BIND##*:}"
  IP="${BIND%%:*}"

  echo "[healthcheck] Parsed EXPORTER_BIND: IP=$IP, PORT=$PORT"

  if output=$(curl -sf "http://127.0.0.1:${PORT}/metrics"); then
    if [ -n "$output" ]; then
      echo "[healthcheck] Metrics received successfully."
    else
      echo "[healthcheck] ERROR: metrics output is empty"
      exit 1
    fi
  else
    echo "[healthcheck] ERROR: failed to fetch metrics from http://127.0.0.1:${PORT}/metrics"
    exit 1
  fi
else
  echo "[healthcheck] EXPORTER_ENABLED is not 1, skipping metrics check."
fi

echo "[healthcheck] All checks passed."
exit 0
