#!/bin/zsh
# Builds a Release copy of MediaHub into dist/MediaHub.app (ad-hoc signed, runs on this Mac).
set -e
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -project MediaHub.xcodeproj -scheme MediaHub -configuration Release \
  -derivedDataPath build/DerivedData clean build | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
rm -rf dist && mkdir dist
cp -R build/DerivedData/Build/Products/Release/MediaHub.app dist/
codesign --verify --deep dist/MediaHub.app && echo "dist/MediaHub.app is ready"
