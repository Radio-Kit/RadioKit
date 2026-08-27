#!/bin/bash
# Move to the project root (where the script is located)
cd "$(dirname "$0")"

echo "📲 Sideloading RadioKit APK to device..."
adb install build/app/outputs/flutter-apk/app-debug.apk

if [ $? -eq 0 ]; then
    echo "✅ Sideload Successful!"
else
    echo "❌ Sideload Failed! Is the device connected?"
    exit 1
fi
