#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/SnapAction.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

cd "$ROOT_DIR"
./script/build_and_run.sh run

test "$(plutil -extract NSScreenCaptureUsageDescription raw -o - "$INFO_PLIST")" = \
  "SnapAction captures the display you choose so it can recognize text and suggest actions."
test "$(plutil -extract NSCalendarsWriteOnlyAccessUsageDescription raw -o - "$INFO_PLIST")" = \
  "SnapAction creates calendar events only after you review and confirm them."
test "$(plutil -extract NSRemindersFullAccessUsageDescription raw -o - "$INFO_PLIST")" = \
  "SnapAction creates reminders only after you review and confirm them."

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if rg -q 'requestFullAccessToEvents' Sources/SnapActionApp/PlatformActionExecutor.swift; then
  echo "Calendar creation must request write-only EventKit access." >&2
  exit 1
fi
rg -q 'requestWriteOnlyAccessToEvents' Sources/SnapActionApp/PlatformActionExecutor.swift

echo "Bundle privacy metadata, signature integrity, and EventKit access policy verified."
