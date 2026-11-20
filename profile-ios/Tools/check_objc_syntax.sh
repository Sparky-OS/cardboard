#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
flat=$(cd "$root/../../flat-headset" && pwd)
clang++ -x objective-c++ -std=c++17 -fsyntax-only -fobjc-runtime=gnustep-2.0 \
  -fobjc-arc -fblocks -Werror -DFH_OBJC_SYNTAX_ONLY=1 \
  -I "$root/Tests/ObjCStubs" -I "$flat/ios/Tests/ObjCStubs" -I "$flat/ios/Viewer" "$root/Sources/Main.mm"
echo 'PASS: Cardboard Main.mm syntax with authored doubles; not SDK/API/ABI validation'
