#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=${1:?build directory}; out=${2:?artifact directory}
cardboard_commit=${3:?Cardboard commit}; workflow_commit=${4:?workflow and receiver commit}
app="$work/build/Build/Products/Release-iphoneos/CardboardProfile.app"
test -d "$app"
file "$app/CardboardProfile"
xcrun lipo "$app/CardboardProfile" -verify_arch arm64
if signature_result="$(LC_ALL=C codesign --verify "$app" 2>&1)"; then
    echo 'The app unexpectedly contains a signature; an unsigned app is required.' >&2
    exit 1
fi
if [[ "$signature_result" != "$app: code object is not signed at all"$'\nIn architecture: arm64' ]]; then
    printf 'Could not establish that the app is unsigned: %s\n' "$signature_result" >&2
    exit 1
fi
printf '%s\n' "$signature_result"
mkdir -p "$work/package/Payload" "$out"
cp -R "$app" "$work/package/Payload/"
licenses="$work/package/Payload/CardboardProfile.app/Licenses"
mkdir -p "$licenses"
cp "$root/COPYING" "$licenses/CardboardProfile-GPL-3.0.txt"
cp "$root/../LICENSE" "$licenses/Cardboard-Apache-2.0.txt"
ditto -c -k --keepParent "$work/package/Payload" "$out/Cardboard-unsigned.ipa"
python3 "$root/Tools/package_manifest.py" "$out/Cardboard-unsigned.ipa" --commit "$cardboard_commit" --workflow-commit "$workflow_commit"
