#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/script/build_and_run.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local output="$1"
  local expected="$2"
  [[ "$output" == *"$expected"* ]] || fail "expected output to contain: $expected"
}

assert_rejected() {
  local expected="$1"
  shift
  local output
  if output="$(env "$@" "$BUILD_SCRIPT" --print-config 2>&1)"; then
    fail "expected invalid configuration to be rejected: $expected"
  fi
  assert_contains "$output" "$expected"
}

default_output="$(
  env \
    -u SNAP_ACTION_APP_NAME \
    -u SNAP_ACTION_BUNDLE_ID \
    -u SNAP_ACTION_VERSION \
    -u SNAP_ACTION_BUILD \
    -u SNAP_ACTION_SOURCE_URL \
    -u SNAP_ACTION_SOURCE_REVISION \
    "$BUILD_SCRIPT" --print-config
)"

assert_contains "$default_output" "SNAP_ACTION_APP_NAME=SnapAction Community"
assert_contains "$default_output" "SNAP_ACTION_BUNDLE_ID=org.example.snapaction.community"
assert_contains "$default_output" "SNAP_ACTION_VERSION=0.1.0"
assert_contains "$default_output" "SNAP_ACTION_BUILD=1"
assert_contains "$default_output" "SNAP_ACTION_SOURCE_URL="
assert_contains "$default_output" "SNAP_ACTION_SOURCE_REVISION=$(git -C "$ROOT_DIR" rev-parse HEAD)"

assert_rejected "invalid SNAP_ACTION_APP_NAME" SNAP_ACTION_APP_NAME="../SnapAction"
assert_rejected "invalid SNAP_ACTION_BUNDLE_ID" SNAP_ACTION_BUNDLE_ID="not a bundle id"
assert_rejected "invalid SNAP_ACTION_VERSION" SNAP_ACTION_VERSION="v1"
assert_rejected "invalid SNAP_ACTION_BUILD" SNAP_ACTION_BUILD="0"
assert_rejected "invalid SNAP_ACTION_SOURCE_URL" SNAP_ACTION_SOURCE_URL="http://example.com/source"
assert_rejected "invalid SNAP_ACTION_SOURCE_URL" SNAP_ACTION_SOURCE_URL="https://user:password@example.com/source"
assert_rejected "invalid SNAP_ACTION_SOURCE_REVISION" SNAP_ACTION_SOURCE_REVISION="main"

override_revision="0123456789abcdef0123456789abcdef01234567"
override_output="$(
  env \
    SNAP_ACTION_APP_NAME="Example Community Build" \
    SNAP_ACTION_BUNDLE_ID="dev.example.snapaction" \
    SNAP_ACTION_VERSION="2.4.1" \
    SNAP_ACTION_BUILD="37" \
    SNAP_ACTION_SOURCE_URL="https://example.com/snapaction" \
    SNAP_ACTION_SOURCE_REVISION="$override_revision" \
    "$BUILD_SCRIPT" --print-config
)"

assert_contains "$override_output" "SNAP_ACTION_APP_NAME=Example Community Build"
assert_contains "$override_output" "SNAP_ACTION_BUNDLE_ID=dev.example.snapaction"
assert_contains "$override_output" "SNAP_ACTION_VERSION=2.4.1"
assert_contains "$override_output" "SNAP_ACTION_BUILD=37"
assert_contains "$override_output" "SNAP_ACTION_SOURCE_URL=https://example.com/snapaction"
assert_contains "$override_output" "SNAP_ACTION_SOURCE_REVISION=$override_revision"

if rg -q 'pkill[[:space:]]+-x' "$BUILD_SCRIPT"; then
  fail "build script must not terminate every process sharing the SnapAction name"
fi

echo "build configuration tests passed"
