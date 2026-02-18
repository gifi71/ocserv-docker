#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export IMAGE="${IMAGE:-ghcr.io/gifi71/ocserv-docker}"
export TAG="${TAG:-latest}"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.test.yml"

TMPDIR_TEST=""
RESULT=1

cleanup() {
  echo "[test] Cleaning up..."
  if [ "$RESULT" -ne 0 ]; then
    echo "[test] === ocserv logs ==="
    docker compose -f "$COMPOSE_FILE" logs ocserv 2>/dev/null || true
    echo "[test] === test-runner logs ==="
    docker compose -f "$COMPOSE_FILE" logs test-runner 2>/dev/null || true
  fi
  docker compose -f "$COMPOSE_FILE" down --remove-orphans 2>/dev/null || true
  if [ -n "$TMPDIR_TEST" ] && [ -d "$TMPDIR_TEST" ]; then
    rm -rf "$TMPDIR_TEST"
  fi
}

trap cleanup EXIT

echo "[test] Creating temp directory for test artifacts..."
TMPDIR_TEST="$(mktemp -d)"
export TEST_CONFIG_DIR="$TMPDIR_TEST"

echo "[test] Generating self-signed EC certificate..."
openssl ecparam -genkey -name prime256v1 -out "$TMPDIR_TEST/server-key.pem" 2>/dev/null
openssl req -new -x509 -key "$TMPDIR_TEST/server-key.pem" \
  -out "$TMPDIR_TEST/server-cert.pem" \
  -days 1 -subj "/CN=ocserv-test" \
  -addext "subjectAltName=IP:172.30.0.10" 2>/dev/null

echo "[test] Copying test config..."
cp "$SCRIPT_DIR/ocserv.test.conf" "$TMPDIR_TEST/ocserv.conf"
chmod 600 "$TMPDIR_TEST/server-key.pem"

echo "[test] Creating test user via ocpasswd..."
docker run --rm -i \
  -v "$TMPDIR_TEST:/etc/ocserv" \
  --entrypoint sh \
  "$IMAGE:$TAG" \
  -c 'printf "testpass123\ntestpass123\n" | ocpasswd -c /etc/ocserv/ocpasswd testuser'

echo "[test] Starting ocserv and test-runner..."
docker compose -f "$COMPOSE_FILE" up \
  --abort-on-container-exit \
  --exit-code-from test-runner

RESULT=$?
exit "$RESULT"
