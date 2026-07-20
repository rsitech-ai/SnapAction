#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PRODUCT_NAME="SnapAction"
MIN_SYSTEM_VERSION="26.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${SNAP_ACTION_APP_NAME:-SnapAction Community}"
BUNDLE_ID="${SNAP_ACTION_BUNDLE_ID:-org.example.snapaction.community}"
VERSION="${SNAP_ACTION_VERSION:-0.1.0}"
BUILD="${SNAP_ACTION_BUILD:-1}"
SOURCE_URL="${SNAP_ACTION_SOURCE_URL:-}"
SOURCE_REVISION="${SNAP_ACTION_SOURCE_REVISION:-$(git -C "$ROOT_DIR" rev-parse HEAD)}"

configuration_error() {
  echo "invalid $1: $2" >&2
  exit 2
}

[[ "$APP_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._\ -]{0,63}$ ]] \
  || configuration_error "SNAP_ACTION_APP_NAME" "use 1-64 letters, numbers, spaces, dots, underscores, or hyphens"
[[ "$BUNDLE_ID" =~ ^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z][A-Za-z0-9-]*)+$ ]] \
  || configuration_error "SNAP_ACTION_BUNDLE_ID" "use a reverse-DNS identifier with at least two components"
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] \
  || configuration_error "SNAP_ACTION_VERSION" "use one to three dot-separated non-negative integers"
[[ "$BUILD" =~ ^[1-9][0-9]*$ ]] \
  || configuration_error "SNAP_ACTION_BUILD" "use a positive integer"
[[ "$SOURCE_REVISION" =~ ^[0-9a-fA-F]{40}$ ]] \
  || configuration_error "SNAP_ACTION_SOURCE_REVISION" "use the exact 40-character Git revision"

validate_and_escape_source_url() {
  python3 - "$1" <<'PYTHON'
import ipaddress
import re
import sys
from urllib.parse import urlsplit
from xml.sax.saxutils import escape

url = sys.argv[1]
if not url or any(character.isspace() or ord(character) < 0x20 for character in url):
    raise SystemExit(1)
try:
    parsed = urlsplit(url)
    port = parsed.port
except ValueError:
    raise SystemExit(1)
if parsed.scheme != "https" or not parsed.netloc or not parsed.hostname:
    raise SystemExit(1)
if parsed.username is not None or parsed.password is not None or port == 0:
    raise SystemExit(1)
hostname = parsed.hostname
try:
    ipaddress.ip_address(hostname)
except ValueError:
    try:
        labels = hostname.encode("idna").decode("ascii").split(".")
    except UnicodeError:
        raise SystemExit(1)
    label = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?")
    if any(not label.fullmatch(item) for item in labels):
        raise SystemExit(1)
sys.stdout.write(escape(url))
PYTHON
}

SOURCE_URL_PLIST_VALUE=""
if [[ -n "$SOURCE_URL" ]]; then
  if ! SOURCE_URL_PLIST_VALUE="$(validate_and_escape_source_url "$SOURCE_URL")"; then
    configuration_error "SNAP_ACTION_SOURCE_URL" "use a credential-free HTTPS URL with a valid host"
  fi
fi

print_config() {
  printf '%s\n' \
    "SNAP_ACTION_APP_NAME=$APP_NAME" \
    "SNAP_ACTION_BUNDLE_ID=$BUNDLE_ID" \
    "SNAP_ACTION_VERSION=$VERSION" \
    "SNAP_ACTION_BUILD=$BUILD" \
    "SNAP_ACTION_SOURCE_URL=$SOURCE_URL" \
    "SNAP_ACTION_SOURCE_REVISION=$SOURCE_REVISION"
}

case "$MODE" in
  --print-config|print-config)
    print_config
    exit 0
    ;;
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--print-config]" >&2
    exit 2
    ;;
esac

DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$PRODUCT_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

staged_process_pids() {
  local pid executable
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    executable="$(ps -p "$pid" -o comm= 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || true)"
    case "$executable" in
      "$DIST_DIR"/*.app/Contents/MacOS/"$PRODUCT_NAME") printf '%s\n' "$pid" ;;
    esac
  done < <(pgrep -x "$PRODUCT_NAME" || true)
}

while IFS= read -r staged_pid; do
  kill "$staged_pid" >/dev/null 2>&1 || true
done < <(staged_process_pids)

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$PRODUCT_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSCalendarsWriteOnlyAccessUsageDescription</key>
  <string>SnapAction creates calendar events only after you review and confirm them.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSRemindersFullAccessUsageDescription</key>
  <string>SnapAction creates reminders only after you review and confirm them.</string>
  <key>NSScreenCaptureUsageDescription</key>
  <string>SnapAction captures the first display after you choose Capture Screen so it can recognize text and suggest actions.</string>
  <key>SnapActionSourceRevision</key>
  <string>$SOURCE_REVISION</string>
PLIST

if [[ -n "$SOURCE_URL" ]]; then
  cat >>"$INFO_PLIST" <<PLIST
  <key>SnapActionSourceURL</key>
  <string>$SOURCE_URL_PLIST_VALUE</string>
PLIST
fi

cat >>"$INFO_PLIST" <<PLIST
</dict>
</plist>
PLIST

/usr/bin/codesign --force --sign - "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PRODUCT_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    app_pid=""
    for _ in {1..50}; do
      app_pid="$(staged_process_pids | head -n 1 || true)"
      if [[ -n "$app_pid" ]]; then
        break
      fi
      sleep 0.1
    done
    if [[ -z "$app_pid" ]]; then
      echo "$APP_NAME did not start within 5 seconds." >&2
      exit 1
    fi
    for _ in {1..10}; do
      if ! kill -0 "$app_pid" >/dev/null 2>&1; then
        echo "$APP_NAME exited during the startup stability check." >&2
        exit 1
      fi
      sleep 0.1
    done
    swift test
    if ! kill -0 "$app_pid" >/dev/null 2>&1; then
      echo "$APP_NAME exited before verification completed." >&2
      exit 1
    fi
    ;;
esac
