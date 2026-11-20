#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=${1:?build directory}
flat=$(cd "$root/../../flat-headset" && pwd)
python3 "$root/Tools/check_catalogs.py"
python3 "$root/Tests/PackageTest.py"
cmake -S "$root" -B "$work/tests" -DCMAKE_BUILD_TYPE=Debug -DFLAT_HEADSET_SOURCE="$flat"
cmake --build "$work/tests" --parallel 4
ctest --test-dir "$work/tests" --output-on-failure
plutil -lint "$root/Info.plist" "$root/CardboardProfile.xcodeproj/project.pbxproj"
xcodebuild -project "$root/CardboardProfile.xcodeproj" -scheme CardboardProfile \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$work/build" -jobs 4 \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' \
  IPHONEOS_DEPLOYMENT_TARGET=16.0 build
