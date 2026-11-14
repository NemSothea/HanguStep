#!/bin/zsh
# Builds HanguStep (Release) and installs it on a connected or Wi-Fi-paired iPhone,
# signed with a free personal team (ADR-013). Re-run every 7 days: free signatures expire.
# Learner data stays on the phone across reinstalls.
#
#   Tools/install-iphone.sh [device-udid]
#
# Team ID: HANGUSTEP_TEAM, or the first line of Configs/personal-team.local (git-ignored).
set -euo pipefail
cd "$(dirname "$0")/.."

team="${HANGUSTEP_TEAM:-$(head -n1 Configs/personal-team.local 2>/dev/null || true)}"
[[ -n "$team" ]] || { echo "Set HANGUSTEP_TEAM or write your team ID to Configs/personal-team.local" >&2; exit 1; }

device="${1:-}"
if [[ -z "$device" ]]; then
  json="$(mktemp)"
  xcrun devicectl list devices --json-output "$json" >/dev/null
  device="$(python3 -I -c '
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
phones = [d for d in devices if d["hardwareProperties"].get("platform") == "iOS"
          and d["hardwareProperties"].get("reality") == "physical"
          and d["connectionProperties"].get("pairingState") == "paired"]
print(phones[0]["hardwareProperties"]["udid"] if phones else "")
' "$json")"
  rm -f "$json"
fi
[[ -n "$device" ]] || { echo "No paired iPhone found. Connect it by cable (or pair it for Wi-Fi in Xcode) and unlock it." >&2; exit 1; }

derived="${TMPDIR:-/tmp}/hangustep-iphone"
echo "Building for $device (team $team)…"
xcodebuild -project HanguStep.xcodeproj -scheme HanguStep -configuration Release \
  -destination "id=$device" -derivedDataPath "$derived" -allowProvisioningUpdates -quiet \
  DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_ENTITLEMENTS="$PWD/Configs/Personal-iOS.entitlements" HANGUSTEP_CLOUDKIT_AVAILABLE=NO build

echo "Installing…"
xcrun devicectl device install app --device "$device" "$derived/Build/Products/Release-iphoneos/HanguStep.app" >/dev/null
if xcrun devicectl device process launch --device "$device" com.nemsothea.hangustep >/dev/null 2>&1; then
  echo "Done. HanguStep is installed, opened, and valid for 7 days."
else
  echo "Done. HanguStep is installed and valid for 7 days. Unlock the phone to open it."
fi
