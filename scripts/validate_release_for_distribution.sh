#!/usr/bin/env bash
# Validates a Release build for TestFlight / App Store–critical settings.
# Run from repo root: movemork/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="movemork"
CONFIG="Release"
DEST="${DEST:-platform=iOS Simulator,name=iPhone 17,OS=26.2}"
DERIVED="${DERIVED:-$(mktemp -d /tmp/movemark-release-check.XXXXXX)}"

echo "==> Building $SCHEME ($CONFIG) → $DERIVED"
xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" -destination "$DEST" \
  -derivedDataPath "$DERIVED" -quiet build

APP=$(find "$DERIVED" -path "*/Release-iphonesimulator/MoveMark.app" -print -quit)
if [[ -z "$APP" || ! -d "$APP" ]]; then
  APP=$(find "$DERIVED" -path "*/Release-iphoneos/MoveMark.app" -print -quit)
fi
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "ERROR: Could not find MoveMark.app under $DERIVED"
  exit 1
fi

PLIST="$APP/Info.plist"
echo "==> Checking $PLIST"

fail() { echo "ERROR: $*" >&2; exit 1; }

supabase_url=$(/usr/libexec/PlistBuddy -c 'Print :SupabaseURL' "$PLIST" 2>/dev/null || true)
[[ -n "$supabase_url" ]] || fail "SupabaseURL missing"
[[ "$supabase_url" != *'$('* ]] || fail "SupabaseURL not expanded (still contains \$(…)): $supabase_url"
[[ "$supabase_url" == https://* ]] || fail "SupabaseURL must be a full https URL (xcconfig uses https:/\$( )/\$(/)host to avoid // comments). Got: ${supabase_url:0:80}"

anon=$(/usr/libexec/PlistBuddy -c 'Print :SupabaseAnonKey' "$PLIST" 2>/dev/null || true)
[[ -n "$anon" ]] || fail "SupabaseAnonKey missing"
[[ "$anon" != *'$('* ]] || fail "SupabaseAnonKey not expanded"

api=$(/usr/libexec/PlistBuddy -c 'Print :MoveMarkAPIBaseURL' "$PLIST" 2>/dev/null || true)
[[ -n "$api" ]] || fail "MoveMarkAPIBaseURL missing"
[[ "$api" == http*://* ]] || fail "MoveMarkAPIBaseURL should be an absolute URL: $api"

rc=$(/usr/libexec/PlistBuddy -c 'Print :RevenueCatPublicAPIKey' "$PLIST" 2>/dev/null || true)
[[ -n "$rc" ]] || fail "RevenueCatPublicAPIKey missing"
[[ "$rc" == appl_* ]] || [[ "$rc" == test_* ]] || fail "RevenueCatPublicAPIKey should start with appl_ or test_: ${rc:0:12}…"

for key in NSCameraUsageDescription NSPhotoLibraryUsageDescription NSPhotoLibraryAddUsageDescription; do
  v=$(/usr/libexec/PlistBuddy -c "Print :$key" "$PLIST" 2>/dev/null || true)
  [[ -n "$v" ]] || fail "$key missing (privacy crash risk)"
done

echo "OK — Release Info.plist looks safe for distribution (simulator build)."
echo "    For App Store upload, still archive in Xcode with your team + run App Store Connect validation."
