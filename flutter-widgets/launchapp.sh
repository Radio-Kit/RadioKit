#!/bin/bash

echo "Starting RadioKit Widgets Demo..."
echo "Target: http://127.0.0.1:8008"

# Kill any existing process on port 8008
fuser -k 8008/tcp 2>/dev/null || true

# Run the app in Chrome on port 8008
# --no-pub: skip dependency check (already done)
# --web-hostname 127.0.0.1: avoid localhost resolution delays
# --web-browser-flag="--no-sandbox": often required in container/Toolbx environments
cd example && flutter run -d chrome \
  --web-port 8008 \
  --web-hostname 127.0.0.1 \
  --debug \
  --no-pub

