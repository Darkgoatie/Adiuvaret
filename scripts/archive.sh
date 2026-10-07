#!/bin/bash
# Unsigned archive (SSH has no keychain), cloud-signed at export with the App Store Connect team key.
set -eo pipefail
cd "$(dirname "$0")/.."
KID=A4C267SY9T
ISS=66854a67-a093-43c2-a3c2-d3910dbbdbd9
P8=$HOME/.appstoreconnect/private_keys/AuthKey_$KID.p8
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$P8" -authenticationKeyID $KID -authenticationKeyIssuerID $ISS)
xcodebuild -project Adiuvaret.xcodeproj -scheme Adiuvaret -destination 'generic/platform=iOS' \
  -configuration Release -archivePath build/Adiuvaret.xcarchive CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO archive | tail -3
xcodebuild -exportArchive -archivePath build/Adiuvaret.xcarchive -exportOptionsPlist signing/ExportOptions.plist \
  -exportPath build/ipa "${AUTH[@]}" | tail -3
ls -l build/ipa
