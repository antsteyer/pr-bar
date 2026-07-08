#!/bin/bash
# Builds pr-bar.app — a proper signed .app bundle (required for notifications).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="pr-bar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/pr-bar "$APP/Contents/MacOS/pr-bar"
cp Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature is enough for local notifications.
codesign --force --sign - "$APP"

echo "Built $(pwd)/$APP"
