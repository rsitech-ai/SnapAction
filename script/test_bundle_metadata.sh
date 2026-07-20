#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/SnapAction Community.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

cd "$ROOT_DIR"
./script/build_and_run.sh --package

test "$(plutil -extract NSScreenCaptureUsageDescription raw -o - "$INFO_PLIST")" = \
  "SnapAction captures the first display after you choose Capture Screen so it can recognize text and suggest actions."
test "$(plutil -extract NSCalendarsWriteOnlyAccessUsageDescription raw -o - "$INFO_PLIST")" = \
  "SnapAction creates calendar events only after you review and confirm them."
test "$(plutil -extract NSRemindersFullAccessUsageDescription raw -o - "$INFO_PLIST")" = \
  "SnapAction creates reminders only after you review and confirm them."
test "$(plutil -extract CFBundleExecutable raw -o - "$INFO_PLIST")" = "SnapAction"
test "$(plutil -extract CFBundleDisplayName raw -o - "$INFO_PLIST")" = "SnapAction Community"
test "$(plutil -extract CFBundleIdentifier raw -o - "$INFO_PLIST")" = "org.example.snapaction.community"
test "$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")" = "0.1.0"
test "$(plutil -extract CFBundleVersion raw -o - "$INFO_PLIST")" = "1"
test "$(plutil -extract SnapActionSourceRevision raw -o - "$INFO_PLIST")" = \
  "$(git rev-parse HEAD)"

if plutil -extract SnapActionSourceURL raw -o - "$INFO_PLIST" >/dev/null 2>&1; then
  echo "The default community bundle must not claim an unconfigured source URL." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if rg -q 'requestFullAccessToEvents' Sources/SnapActionApp/PlatformActionExecutor.swift; then
  echo "Calendar creation must request write-only EventKit access." >&2
  exit 1
fi
rg -q 'requestWriteOnlyAccessToEvents' Sources/SnapActionApp/PlatformActionExecutor.swift

echo "Bundle privacy metadata, signature integrity, and EventKit access policy verified."
