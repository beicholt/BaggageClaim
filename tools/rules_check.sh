#!/bin/bash
# Compile the rules against the iOS simulator SDK and run them there.
#
# The rules import UIKit (bag colours), so they cannot be built as a plain macOS
# tool — but they need no scene, so the simulator can run them headless in a
# second. Far faster than driving the UI, and it does not care what the belt
# happened to be doing when the screenshot was taken.
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-iPhone 17 Pro}"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
OUT=$(mktemp -d)/rules_check

xcrun swiftc -sdk "$SDK" -target arm64-apple-ios17.0-simulator -O \
  Carousel/Game/Tuning.swift \
  Carousel/Game/Projection.swift \
  Carousel/Game/Track.swift \
  Carousel/Game/BagType.swift \
  Carousel/Game/GameState.swift \
  tools/rulescheck/main.swift \
  -o "$OUT"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl spawn "$DEVICE" "$OUT"
