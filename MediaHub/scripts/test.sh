#!/bin/zsh
# Runs the unit tests and prints a short summary.
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -project MediaHub.xcodeproj -scheme MediaHub -derivedDataPath build/DerivedData test 2>&1 \
  | grep -E "error:|Test Case .*(passed|failed)|XCTAssert|Executed|TEST (SUCCEEDED|FAILED)" | grep -v linkd
