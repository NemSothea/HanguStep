#!/bin/sh
# Regenerates App/Assets.xcassets/AppIcon.appiconset from Tools/app-icon/render.swift.
set -eu
cd "$(dirname "$0")/../.."
dir=App/Assets.xcassets/AppIcon.appiconset
for px in 16 32 64 128 256 512 1024; do
  swift Tools/app-icon/render.swift "$dir/icon-$px.png" "$px"
done
echo "Wrote $dir"
