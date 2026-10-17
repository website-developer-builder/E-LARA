#!/bin/zsh
# Builds E-LARA. Usage: scripts/build.sh [Debug|Release]
set -e
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -project ELARA.xcodeproj -scheme E-LARA -configuration "${1:-Debug}" \
  -derivedDataPath build/DerivedData build 2>&1 | grep -E "error:|warning: [^M]|BUILD (SUCCEEDED|FAILED)" | grep -v appintents || true
