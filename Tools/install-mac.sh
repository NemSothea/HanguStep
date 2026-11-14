#!/bin/zsh
# Builds HanguStep for this Mac (Release), signed to run locally, and copies it to
# /Applications. Local signatures do not expire. No iCloud sync (ADR-013).
#
#   Tools/install-mac.sh [destination folder, default /Applications]
set -euo pipefail
cd "$(dirname "$0")/.."
destination="${1:-/Applications}"
derived="${TMPDIR:-/tmp}/hangustep-mac"

echo "Building for this Mac…"
xcodebuild -project HanguStep.xcodeproj -scheme HanguStep -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$derived" -quiet \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  CODE_SIGN_ENTITLEMENTS="$PWD/Configs/Personal-macOS.entitlements" HANGUSTEP_CLOUDKIT_AVAILABLE=NO build

app="$derived/Build/Products/Release/HanguStep.app"
rm -rf "$destination/HanguStep.app"
cp -R "$app" "$destination/"
echo "Done. Open $destination/HanguStep.app"
