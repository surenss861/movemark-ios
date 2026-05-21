#!/usr/bin/env bash
# Install debug APK and launch MoveMark on a connected emulator or device.
set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$ROOT/movemark-android"
PKG="com.surensureshkumar.movemark"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Set ANDROID_HOME=$ANDROID_HOME"
  exit 1
fi

DEVICES="$(adb devices | awk 'NR>1 && $2=="device" { print $1 }')"
if [ -z "$DEVICES" ]; then
  echo "No device connected."
  echo ""
  echo "In Android Studio: Tools → Device Manager → Start (or Create) an emulator."
  echo "Then run: adb devices"
  echo "Expected: emulator-5554    device"
  exit 1
fi

echo "Using device(s):"
echo "$DEVICES"
echo ""

cd "$ANDROID_DIR"
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/Jbr/Contents/Home}"
./gradlew :app:installDebug --no-daemon

adb shell am start -n "$PKG/.MainActivity"
adb logcat -c 2>/dev/null || true

echo ""
echo "App launched. Run the proof-loop QA (movemark-android/docs/ANDROID_QA.md)."
echo ""
echo "Logcat (errors + MoveMark tags):"
echo "  adb logcat | grep -iE 'MoveMark|Supabase|AndroidRuntime|FATAL'"
