#!/usr/bin/env bash
# =============================================================================
# start_studio.sh -- Launcher for R-TRCE Interactive Studio
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
export HOST="${HOST:-127.0.0.1}"

echo "=================================================================="
echo "  Starting R-TRCE Studio & Guided Walkthrough"
echo "  Access at: http://${HOST}:${PORT}"
echo "=================================================================="

"$R_BIN" "$DIR/app.R"
