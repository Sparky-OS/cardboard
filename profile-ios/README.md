# Cardboard viewer profiles for iPhone

Scan the QR code on your viewer, then tap **Use in Flat Headset**. Flat Headset validates the profile and asks before saving it for the next connection. Its paste field remains a second way to import a full profile link. This app has no tracking or desktop connection.

The native camera path is adapted from Google's Cardboard iOS QR scanner at `8bd424da7f1e399255a1b6e7c02be8e281ecc974`. The app uses AVFoundation and UIKit. Its bounded parser and Cardboard parameters come from the same Flat Headset source used to build the receiver. No optical coefficient is added. The application and shared receiver sources are GPL-3.0-or-later; Google's code retains its Apache-2.0 licence and copyright. Both texts ship in the package.

A full QR profile works offline. A shortened `goo.gl` or `g.co` link offers an explicit network action, with HTTPS, five redirects and a time limit. The final profile is parsed locally without downloading a webpage. Refusal, unavailable camera, invalid profile, interruption and failed resolution are shown in ten languages. Cancelling or leaving the app stops capture and resolution. A failed scan never selects a default profile. The exact upstream `g.co/cardboard` code denotes Cardboard v1.

The handoff is `flatheadset://viewer?p=BASE64URL`, containing only the validated lens parameters. It carries no identity, address, pairing secret or session grant. The receiver validates it again, including its screen geometry, and asks before saving. Installing both apps is required; the on-screen failure remains visible if the receiver cannot open.

## Build and check

Check out `Sparky-OS/cardboard` and the matching `Sparky-OS/flat-headset` as sibling directories named `cardboard` and `flat-headset`. The central workflow in Flat Headset pins this repository's commit and uses its own commit for shared sources. Build unsigned on the hosted Mac:

```sh
bash cardboard/profile-ios/Tools/build_unsigned.sh "$RUNNER_TEMP/cardboard-iphone"
bash cardboard/profile-ios/Tools/package_unsigned.sh "$RUNNER_TEMP/cardboard-iphone" "$PWD/artifact" "$CARDBOARD_COMMIT" "$WORKFLOW_COMMIT"
```

The artifact contains an unsigned arm64 IPA, SHA256SUMS and `cardboard-artifact.json` for the three-program renewal manifest. No signing account or SDK file enters source control. The workflow records its actual Xcode/SDK versions.

Linux checks require CMake, a C++17 compiler and Clang for the syntax check:

```sh
cmake -S cardboard/profile-ios -B check -DCMAKE_BUILD_TYPE=Debug -DFLAT_HEADSET_SOURCE="$PWD/flat-headset"
cmake --build check --parallel 4
ctest --test-dir check --output-on-failure
python3 cardboard/profile-ios/Tools/check_catalogs.py
python3 cardboard/profile-ios/Tests/PackageTest.py
bash cardboard/profile-ios/Tools/check_objc_syntax.sh
```

Run these in an isolated container without a network. Optional `Tests/QRImageTest.py check/scan-test` requires python-qrcode, Pillow and pyzbar; it feeds independently decoded QR pixels through the real profile policy. It does not exercise AVFoundation. The authored Objective-C declarations check language syntax, ARC, blocks and C++ members, not Apple's API or ABI. Only the hosted build checks those; camera capture, app-to-app opening and the optical result require a phone session after all three packages are ready.
