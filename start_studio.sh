#!/usr/bin/env bash
# =============================================================================
# start_studio.sh -- Launcher for R-TRCE Interactive Studio
# =============================================================================
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R_BIN="/home/sam/.r-env/bin/Rscript"

if [ ! -x "$R_BIN" ]; then
  R_BIN="$(which Rscript 2>/dev/null)"
fi

if [ -z "$R_BIN" ]; then
  echo "Error: Rscript not found. Please install R or activate ~/.r-env." >&2
  exit 1
fi

export PORT="${PORT:-8083}"
export HOST="${HOST:-0.0.0.0}"

# Auto-detect IP addresses
HOST_IPS=""
if command -v hostname >/dev/null 2>&1; then
  HOST_IPS="$(hostname -I 2>/dev/null || true)"
fi

echo "=================================================================="
echo "  Starting R-TRCE Studio & Guided Walkthrough"
echo "=================================================================="
echo "  Listening on: http://${HOST}:${PORT}"
echo ""
echo "  Access the Studio in your browser via:"
echo "   -> http://localhost:${PORT}"
echo "   -> http://127.0.0.1:${PORT}"
for ip in $HOST_IPS; do
  [ "$ip" != "127.0.0.1" ] && echo "   -> http://${ip}:${PORT}"
done
if [ -d /dev/vsock ] || [ -f /run/systemd/container ] || [ -d /mnt/chromeos ]; then
  echo ""
  echo "  [Chromebook / ChromeOS / Baguette Tip]:"
  echo "   -> In Chrome browser: http://penguin.linux.test:${PORT}"
fi
echo "=================================================================="

# Attempt to launch browser if available
(sleep 1.5 && (
  if command -v garcon-url-handler >/dev/null 2>&1; then
    garcon-url-handler "http://localhost:${PORT}" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://localhost:${PORT}" >/dev/null 2>&1 || true
  elif command -v open >/dev/null 2>&1; then
    open "http://localhost:${PORT}" >/dev/null 2>&1 || true
  fi
)) &

"$R_BIN" "$DIR/app.R"

