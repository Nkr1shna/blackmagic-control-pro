#!/bin/bash
# Builds a versioned, unsigned IPA for SideStore distribution, plus dSYMs.
# Output: dist/v<version>-<build>/  (IPA, xcarchive, dSYMs, commit.txt)
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -n "$(git status --porcelain)" ]]; then
  echo "warning: working tree is dirty — the IPA will not map to a single commit" >&2
fi

if [[ -x scripts/set-build-number.sh ]]; then
  scripts/set-build-number.sh
fi

xcodegen generate

PLIST=BlackmagicControl/App/Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$PLIST")
STAMP="v${VERSION}-${BUILD}"
OUT="dist/${STAMP}"
ARCHIVE="${OUT}/BlackmagicControlPro.xcarchive"
mkdir -p "$OUT"

echo "Toolchain: $(xcodebuild -version | tr '\n' ' ')"
echo "Building ${STAMP} from $(git rev-parse --short HEAD)"

xcodebuild archive \
  -project BlackmagicControl.xcodeproj \
  -scheme BlackmagicControl \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" \
  | tail -5

APP_PATH="$ARCHIVE/Products/Applications/BlackmagicControl.app"
STAGING="$(mktemp -d)"
mkdir -p "$STAGING/Payload"
cp -R "$APP_PATH" "$STAGING/Payload/"
(cd "$STAGING" && zip -qry "BlackmagicControlPro-${STAMP}.ipa" Payload)
mv "$STAGING/BlackmagicControlPro-${STAMP}.ipa" "$OUT/"
rm -rf "$STAGING"

git rev-parse HEAD > "$OUT/commit.txt"
xcodebuild -version >> "$OUT/commit.txt"

echo ""
echo "Done:"
echo "  IPA:     $OUT/BlackmagicControlPro-${STAMP}.ipa"
echo "  Archive: $ARCHIVE (dSYMs inside — keep this folder for every shipped build)"
