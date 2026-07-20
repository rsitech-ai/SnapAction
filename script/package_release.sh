#!/usr/bin/env bash
set -euo pipefail
umask 022

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/.artifacts/release"
VERSION="0.1.0"
BUILD="1"
APP_NAME="SnapAction"
BUNDLE_ID="ai.rsitech.snapaction"
SOURCE_URL="https://github.com/rsitech-ai/SnapAction"
ARCHITECTURE="arm64"
SIGNING_MODE="developer-id"
SIGNING_IDENTITY="Developer ID Application: Rafal Sikora (2NY8A789TN)"
SIGNING_TEAM="2NY8A789TN"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || { echo "--output requires a directory" >&2; exit 2; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --signing-mode)
      [[ $# -ge 2 ]] || { echo "--signing-mode requires developer-id or ad-hoc" >&2; exit 2; }
      SIGNING_MODE="$2"
      shift 2
      ;;
    *)
      echo "usage: $0 [--signing-mode developer-id|ad-hoc] [--output DIRECTORY]" >&2
      exit 2
      ;;
  esac
done

[[ "$SIGNING_MODE" == "developer-id" || "$SIGNING_MODE" == "ad-hoc" ]] || {
  echo "--signing-mode requires developer-id or ad-hoc" >&2
  exit 2
}

if ! git -C "$ROOT_DIR" diff --quiet || ! git -C "$ROOT_DIR" diff --cached --quiet || \
   [[ -n "$(git -C "$ROOT_DIR" ls-files --others --exclude-standard)" ]]; then
  echo "release packaging requires a clean source tree at an exact commit" >&2
  exit 1
fi

HOST_ARCHITECTURE="$(uname -m)"
[[ "$HOST_ARCHITECTURE" == "$ARCHITECTURE" ]] || {
  echo "release packaging requires an arm64 host; found $HOST_ARCHITECTURE" >&2
  exit 2
}

SOURCE_REVISION="$(git -C "$ROOT_DIR" rev-parse HEAD)"

if [[ "$OUTPUT_DIR" != /* ]]; then
  OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR"
fi

APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
ARCHIVE_NAME="SnapAction-$VERSION-macos-$ARCHITECTURE.zip"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

cd "$ROOT_DIR"
env \
  SNAP_ACTION_APP_NAME="$APP_NAME" \
  SNAP_ACTION_BUNDLE_ID="$BUNDLE_ID" \
  SNAP_ACTION_VERSION="$VERSION" \
  SNAP_ACTION_BUILD="$BUILD" \
  SNAP_ACTION_SOURCE_URL="$SOURCE_URL" \
  SNAP_ACTION_SOURCE_REVISION="$SOURCE_REVISION" \
  ./script/build_and_run.sh --package

/usr/libexec/PlistBuddy -c "Add :SnapActionDistributionChannel string direct-download" \
  "$APP_BUNDLE/Contents/Info.plist"

if [[ "$SIGNING_MODE" == "developer-id" ]]; then
  /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -Fq "\"$SIGNING_IDENTITY\"" || {
    echo "required signing identity is not installed: $SIGNING_IDENTITY" >&2
    exit 1
  }
  /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
else
  /usr/bin/codesign --force --sign - "$APP_BUNDLE"
fi

/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_BUNDLE/Contents/Info.plist")" = "$BUNDLE_ID"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")" = "$VERSION"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist")" = "$BUILD"
test "$(/usr/libexec/PlistBuddy -c 'Print :SnapActionBuildConfiguration' "$APP_BUNDLE/Contents/Info.plist")" = "release"
test "$(/usr/libexec/PlistBuddy -c 'Print :SnapActionDistributionChannel' "$APP_BUNDLE/Contents/Info.plist")" = "direct-download"
test "$(/usr/libexec/PlistBuddy -c 'Print :SnapActionSourceURL' "$APP_BUNDLE/Contents/Info.plist")" = "$SOURCE_URL"
test "$(/usr/libexec/PlistBuddy -c 'Print :SnapActionSourceRevision' "$APP_BUNDLE/Contents/Info.plist")" = "$SOURCE_REVISION"
test "$(/usr/bin/lipo -archs "$APP_BUNDLE/Contents/MacOS/SnapAction")" = "$ARCHITECTURE"

SIGNING_DETAILS="$(/usr/bin/codesign -dvvv "$APP_BUNDLE" 2>&1)"
if [[ "$SIGNING_MODE" == "developer-id" ]]; then
  /usr/bin/grep -Fq "Authority=$SIGNING_IDENTITY" <<<"$SIGNING_DETAILS"
  /usr/bin/grep -Fq "TeamIdentifier=$SIGNING_TEAM" <<<"$SIGNING_DETAILS"
  /usr/bin/grep -Eq '^Runtime Version=' <<<"$SIGNING_DETAILS"
else
  /usr/bin/grep -Fq "Signature=adhoc" <<<"$SIGNING_DETAILS"
fi

# Normalize archive-visible metadata after signing so identical source inputs
# produce byte-identical ZIP files without changing signed file contents.
STAGING_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/snapaction-release.XXXXXX")"
trap '/bin/rm -rf -- "$STAGING_DIR"' EXIT
/usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
/bin/cp "$ROOT_DIR/LICENSE" "$ROOT_DIR/NOTICE" "$STAGING_DIR/"
/usr/bin/find -d "$STAGING_DIR" -exec /usr/bin/touch -h -t 200001010000 {} +
/usr/bin/codesign --verify --deep --strict "$STAGING_DIR/$APP_NAME.app"

mkdir -p "$OUTPUT_DIR"
rm -f -- "$ARCHIVE_PATH" "$CHECKSUM_PATH"
(
  cd "$STAGING_DIR"
  COPYFILE_DISABLE=1 LC_ALL=C /usr/bin/find -s LICENSE NOTICE "$APP_NAME.app" -print | \
    COPYFILE_DISABLE=1 LC_ALL=C /usr/bin/zip -X -q -y "$ARCHIVE_PATH" -@
)
(
  cd "$OUTPUT_DIR"
  /usr/bin/shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)

printf '%s\n' \
  "artifact=$ARCHIVE_PATH" \
  "checksum=$CHECKSUM_PATH" \
  "source_revision=$SOURCE_REVISION" \
  "signing=$SIGNING_MODE" \
  "signing_team=$([[ "$SIGNING_MODE" == "developer-id" ]] && printf '%s' "$SIGNING_TEAM" || printf '%s' none)" \
  "notarization=not-notarized"
