#!/bin/bash
# Builds PRBar.app — a proper signed .app bundle (required for notifications).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="PRBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/PRBar "$APP/Contents/MacOS/PRBar"
cp Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature is enough for local notifications.
codesign --force --sign - "$APP"

echo "Built $(pwd)/$APP"
