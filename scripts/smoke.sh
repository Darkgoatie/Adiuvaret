#!/bin/bash
# Run on the macOS VM from the repo root.
set -o pipefail
cd "$(dirname "$0")/.."
start=$(date +%s)
log=$(mktemp)
(cd Packages && swift test 2>&1) | tee "$log"
rc=$?
if [ -d Adiuvaret.xcodeproj ]; then
  xcodebuild -project Adiuvaret.xcodeproj -scheme Adiuvaret -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath .build/dd CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5 | tee -a "$log"
  [ ${PIPESTATUS[0]} -eq 0 ] || rc=1
fi
errors=$(grep -c "error:" "$log")
echo "SMOKE rc=$rc errors=$errors seconds=$(( $(date +%s) - start ))"
exit $rc
