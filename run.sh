#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

PORT=5000
CERT=cert.pem
KEY=key.pem

# Detect LAN IP
IP=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
[ -z "$IP" ] && IP=127.0.0.1

# HTTPS only when --https is passed; default is HTTP so any phone can connect.
USE_HTTPS=0
for arg in "$@"; do
    [ "$arg" = "--https" ] && USE_HTTPS=1
done

SSL_ARGS=()
SCHEME="http"
if [ "$USE_HTTPS" = "1" ]; then
    SCHEME="https"
    if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
        echo ">>> Generating self-signed cert for $IP..."
        openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout "$KEY" -out "$CERT" -days 3650 \
            -subj "/CN=$IP" \
            -addext "subjectAltName=IP:$IP,IP:127.0.0.1,DNS:localhost" >/dev/null 2>&1
    fi
    SSL_ARGS=(--certfile="$CERT" --keyfile="$KEY")
fi

if pgrep -f "gunicorn.*app:app" >/dev/null; then
    echo ">>> Stopping existing gunicorn..."
    pkill -f "gunicorn.*app:app" || true
    sleep 1
fi

echo
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   Weapon Detection + Control System              ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo "  ➜  Open  $SCHEME://$IP:$PORT  on your phone or laptop"
if [ "$USE_HTTPS" = "0" ]; then
    echo
    echo "     (plain HTTP — for phone GPS, enable this flag in Chrome:"
    echo "      chrome://flags/#unsafely-treat-insecure-origin-as-secure"
    echo "      add: http://$IP:$PORT  then relaunch Chrome)"
    echo
    echo "     For HTTPS instead, run:  ./run.sh --https"
fi
echo "  Press Ctrl+C to stop."
echo

exec gunicorn \
    -b "0.0.0.0:$PORT" -w 1 --threads 8 --timeout 120 \
    "${SSL_ARGS[@]}" \
    app:app
