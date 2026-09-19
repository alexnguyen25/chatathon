#!/bin/bash
# Run the real app's pure-rule tests and compile the native simulator target.
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun swift test
xcodebuild -quiet \
  -project ios/LowCor.xcodeproj \
  -scheme LowCor \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
