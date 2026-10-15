#!/bin/bash
#
# Builds OmniPilot.app into ./build using xcodebuild.
#
# Usage:
#   Scripts/build-app.sh            # Debug
#   Scripts/build-app.sh release    # Release
#
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="Debug"
if [ "${1:-}" = "release" ] || [ "${1:-}" = "Release" ]; then
    CONFIG="Release"
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen not found. Install it with: brew install xcodegen" >&2
    exit 1
fi

echo "==> Generating OmniPilot.xcodeproj"
xcodegen generate --quiet

echo "==> Building ($CONFIG)"
xcodebuild \
    -project OmniPilot.xcodeproj \
    -scheme OmniPilot \
    -configuration "$CONFIG" \
    -derivedDataPath build/DerivedData \
    build

APP_PATH="build/DerivedData/Build/Products/$CONFIG/OmniPilot.app"
if [ ! -d "$APP_PATH" ]; then
    echo "error: built app not found at $APP_PATH" >&2
    exit 1
fi

rm -rf build/OmniPilot.app
mkdir -p build
cp -R "$APP_PATH" build/OmniPilot.app

echo "==> Done: build/OmniPilot.app"
echo "    Run with: open build/OmniPilot.app"
