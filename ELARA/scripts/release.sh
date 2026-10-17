#!/bin/zsh
# Builds a Release copy of E-LARA into dist/E-LARA.app (ad-hoc signed, runs on this Mac).
set -e
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -project ELARA.xcodeproj -scheme E-LARA -configuration Release \
  -derivedDataPath build/DerivedData clean build | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
rm -rf dist && mkdir dist
cp -R build/DerivedData/Build/Products/Release/E-LARA.app dist/
codesign --verify --deep dist/E-LARA.app && echo "dist/E-LARA.app is ready"
