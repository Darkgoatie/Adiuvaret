#!/bin/bash
# Signed archive + .ipa on the macOS VM using the App Store Connect team key (cloud signing).
set -eo pipefail
cd "$(dirname "$0")/.."
KID=A4C267SY9T
ISS=66854a67-a093-43c2-a3c2-d3910dbbdbd9
P8=$HOME/.appstoreconnect/private_keys/AuthKey_$KID.p8
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$P8" -authenticationKeyID $KID -authenticationKeyIssuerID $ISS)
xcodebuild -project Adiuvaret.xcodeproj -scheme Adiuvaret -destination 'generic/platform=iOS' \
  -archivePath build/Adiuvaret.xcarchive "${AUTH[@]}" archive | tail -3
xcodebuild -exportArchive -archivePath build/Adiuvaret.xcarchive -exportOptionsPlist signing/ExportOptions.plist \
  -exportPath build/ipa "${AUTH[@]}" | tail -3
ls -l build/ipa
