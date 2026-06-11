#!/usr/bin/env bash
set -euo pipefail

# ─── RadioKit Relay — run.sh ─────────────────────────────────────
# Builds and runs the relay server with sensible local-development
# defaults. Override any variable via environment.
#
# Usage:
#   ./run.sh                  # build + run (port 9000, stats 8080)
#   ./run.sh --release        # optimized release build
#   ./run.sh --port 4443      # custom WS port
#   ./run.sh --help           # show this message
# ─────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Defaults ─────────────────────────────────────────────────────
WS_PORT="${RADIOKIT_PORT:-9000}"
STATS_PORT="${RADIOKIT_STATS_PORT:-8080}"
PROFILE=""
RELEASE_FLAG=""

# ─── Parse args ───────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)   PROFILE="release" ; RELEASE_FLAG="--release" ; shift ;;
    --port)      WS_PORT="$2" ; shift 2 ;;
    --stats)     STATS_PORT="$2" ; shift 2 ;;
    --help|-h)
      cat <<EOF
# RadioKit Relay — run.sh
# Builds and runs the relay server with sensible local-development
# defaults. Override any variable via environment.
#
# Usage:
#   ./run.sh                  # build + run (port 9000, stats 8080)
#   ./run.sh --release        # optimized release build
#   ./run.sh --port 4443      # custom WS port
#   ./run.sh --help           # show this message

Environment variables:
  RADIOKIT_PORT          WebSocket port (default: 9000)
  RADIOKIT_STATS_PORT    Stats HTTP port (default: 8080)

Flags:
  --release    Build and run the release binary
  --port N     WebSocket port (overrides RADIOKIT_PORT)
  --stats N    Stats HTTP port (overrides RADIOKIT_STATS_PORT)
  --help, -h   Show this message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: ./run.sh [--release] [--port N] [--stats N] [--help]" >&2
      exit 1
      ;;
  esac
done

# ─── Kill existing instance ──────────────────────────────────────
PID_FILE="/tmp/radiokit-relay.pid"
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "==> Stopping existing relay (PID $OLD_PID)..."
    kill "$OLD_PID" 2>/dev/null || true
    # Wait for the port to be released
    sleep 1
  fi
  rm -f "$PID_FILE"
fi

# ─── Build ────────────────────────────────────────────────────────
echo "==> Building radiokit-relay${PROFILE:+ ($PROFILE)}..."
if [ "$PROFILE" = "release" ]; then
  cargo build --release
  BINARY="target/release/radiokit-relay"
else
  cargo build
  BINARY="target/debug/radiokit-relay"
fi

# ─── Run ──────────────────────────────────────────────────────────
echo "==> Starting relay: WS on :$WS_PORT  |  Stats on :$STATS_PORT"
echo "    Press Ctrl+C to stop."
echo ""

export RADIOKIT_PORT="$WS_PORT"
export RADIOKIT_STATS_PORT="$STATS_PORT"
echo $$ > "$PID_FILE"
exec "$BINARY"
