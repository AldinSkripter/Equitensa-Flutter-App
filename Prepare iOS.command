#!/bin/bash
# Run once on the Mac before opening the Xcode workspace, and after moving the project.
set -euo pipefail

on_exit() {
  local result=$?
  if [ "$result" -ne 0 ]; then
    printf '\nPreparation stopped. Copy the error above when requesting help.\n'
    if [ -t 0 ]; then read -r -p 'Press Return to close...' _reply; fi
  fi
}
trap on_exit EXIT

cd "$(dirname "$0")"
PROJECT_DIR="$(pwd -P)"
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.pub-cache/bin:$PATH"

if [ "$(uname -s)" != Darwin ]; then
  printf 'This launcher must run on macOS with Xcode installed.\n' >&2
  exit 1
fi
if ! xcrun --find xcodebuild >/dev/null 2>&1 || ! xcrun --find simctl >/dev/null 2>&1; then
  printf 'Open the full Xcode app and complete its first-launch setup.\nSelect Xcode > Settings > Locations > Command Line Tools.\n' >&2
  exit 1
fi

VERSION="$(sed -n 's/.*"flutter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .fvmrc)"
if [ -z "$VERSION" ]; then
  printf 'Cannot read the Flutter version from .fvmrc.\n' >&2
  exit 1
fi

FLUTTER_BIN=""
for candidate in \
  "$PROJECT_DIR/.fvm/flutter_sdk/bin/flutter" \
  "${FLUTTER_ROOT:-/nonexistent}/bin/flutter" \
  "$HOME/fvm/versions/$VERSION/bin/flutter" \
  "$HOME/Library/Caches/Equitensa/flutter-$VERSION/bin/flutter" \
  "$(command -v flutter || true)"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    if "$candidate" --version --machine | grep -Eq '"frameworkVersion"[[:space:]]*:[[:space:]]*"'"$VERSION"'"'; then
      FLUTTER_BIN="$candidate"
      break
    fi
  fi
done

if [ -z "$FLUTTER_BIN" ]; then
  # Keep our SDK separate; never replace an existing system Flutter installation.
  SDK_DIR="$HOME/Library/Caches/Equitensa/flutter-$VERSION"
  if [ -e "$SDK_DIR" ]; then
    printf 'Flutter cache exists but is incomplete or has the wrong version: %s\n' "$SDK_DIR" >&2
    exit 1
  fi
  printf '\nDownloading Flutter %s from the official Flutter repository.\nThe first setup can take several minutes.\n' "$VERSION"
  mkdir -p "$(dirname "$SDK_DIR")"
  git clone --depth 1 --branch "$VERSION" https://github.com/flutter/flutter.git "$SDK_DIR"
  FLUTTER_BIN="$SDK_DIR/bin/flutter"
fi

export PATH="$(dirname "$FLUTTER_BIN"):$PATH"
printf '\nProject: %s\nFlutter: %s\n' "$PROJECT_DIR" "$FLUTTER_BIN"
"$FLUTTER_BIN" --version
"$FLUTTER_BIN" precache --ios
"$FLUTTER_BIN" pub get

# This rewrites generated Windows/old-Mac paths and prepares the Swift packages.
# API_BASE is optional; without it iOS uses the local Mac backend on port 3000.
if [ -n "${API_BASE:-}" ]; then
  "$FLUTTER_BIN" build ios --debug --config-only --no-codesign --dart-define="API_BASE=$API_BASE"
else
  "$FLUTTER_BIN" build ios --debug --config-only --no-codesign
fi

printf '\nPrepared for Xcode. Select Runner, choose an iPhone Simulator, then Run.\n'
printf 'Backend: %s (must be running separately).\n' "${API_BASE:-http://localhost:3000}"
open "$PROJECT_DIR/ios/Runner.xcworkspace"
