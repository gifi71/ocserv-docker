#!/bin/bash
set -uo pipefail

OCSERV_HOST="172.30.0.10"
OCSERV_PORT="443"
EXPORTER_PORT="8000"
VPN_SUBNET="192.168.99"
PASS=0
FAIL=0

run_test() {
  local name="$1"
  shift
  echo -n "[TEST] $name ... "
  if "$@" >/dev/null 2>&1; then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL"
    FAIL=$((FAIL + 1))
  fi
}

echo "[test-runner] Extracting SPKI pin from server certificate..."
SPKI_PIN=$(openssl x509 -in /etc/ocserv/server-cert.pem -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64)
echo "[test-runner] SPKI pin: $SPKI_PIN"

echo ""
echo "=== Integration Tests ==="
echo ""

# TEST 1: TLS connectivity
run_test "TLS connectivity to ${OCSERV_HOST}:${OCSERV_PORT}" \
  openssl s_client -connect "${OCSERV_HOST}:${OCSERV_PORT}" -brief </dev/null

# TEST 2: openconnect VPN tunnel
echo -n "[TEST] VPN tunnel establishment ... "
OC_LOG="/tmp/openconnect.log"
echo "testpass123" | openconnect \
  --no-dtls \
  --servercert "pin-sha256:${SPKI_PIN}" \
  --user testuser \
  --passwd-on-stdin \
  --non-inter \
  --interface tun-test \
  --background \
  --pid-file /tmp/openconnect.pid \
  "https://${OCSERV_HOST}:${OCSERV_PORT}" >"$OC_LOG" 2>&1 || true

# Wait for tunnel to come up
sleep 3

if ip link show tun-test >/dev/null 2>&1; then
  echo "PASS"
  PASS=$((PASS + 1))
else
  echo "FAIL"
  echo "[DEBUG] openconnect output:"
  cat "$OC_LOG"
  FAIL=$((FAIL + 1))
fi

# TEST 3: tun interface exists
run_test "TUN interface tun-test exists" \
  ip link show tun-test

# TEST 4: assigned IP in VPN range
echo -n "[TEST] Assigned IP in ${VPN_SUBNET}.0/24 range ... "
ASSIGNED_IP=$(ip -4 addr show tun-test 2>/dev/null | grep -oP 'inet \K[0-9.]+' || true)
if echo "$ASSIGNED_IP" | grep -q "^${VPN_SUBNET}\."; then
  echo "PASS ($ASSIGNED_IP)"
  PASS=$((PASS + 1))
else
  echo "FAIL (got: ${ASSIGNED_IP:-none})"
  FAIL=$((FAIL + 1))
fi

# TEST 5: ping VPN gateway
run_test "Ping VPN gateway ${VPN_SUBNET}.1" \
  ping -c 2 -W 3 "${VPN_SUBNET}.1"

# TEST 6: exporter metrics
echo -n "[TEST] Exporter metrics contain vpn_ ... "
METRICS_OUT=$(curl -sf "http://${OCSERV_HOST}:${EXPORTER_PORT}/metrics" 2>&1 || true)
if echo "$METRICS_OUT" | grep -q "vpn_"; then
  echo "PASS"
  PASS=$((PASS + 1))
else
  echo "FAIL"
  echo "[DEBUG] curl output (filtered):"
  echo "$METRICS_OUT" | grep -i "ocserv" || echo "(no ocserv_ metrics found)"
  echo "[DEBUG] total lines in /metrics:"
  echo "$METRICS_OUT" | wc -l
  FAIL=$((FAIL + 1))
fi

# Cleanup openconnect
if [ -f /tmp/openconnect.pid ]; then
  kill "$(cat /tmp/openconnect.pid)" 2>/dev/null || true
fi

echo ""
echo "=== Results: ${PASS}/$((PASS + FAIL)) passed ==="
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

exit 0
