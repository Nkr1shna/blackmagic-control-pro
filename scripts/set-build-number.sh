#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

PLIST="BlackmagicControl/App/Info.plist"
BUILD_NUMBER="$(git rev-list --count HEAD)"
BUILD_SHA="$(git rev-parse --short HEAD)"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "$PLIST"
if ! /usr/libexec/PlistBuddy -c "Set :KNBuildSHA ${BUILD_SHA}" "$PLIST"; then
  /usr/libexec/PlistBuddy -c "Add :KNBuildSHA string ${BUILD_SHA}" "$PLIST"
fi

echo "Set CFBundleVersion=${BUILD_NUMBER}"
echo "Set KNBuildSHA=${BUILD_SHA}"
