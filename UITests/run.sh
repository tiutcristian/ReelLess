#!/bin/bash
# Runs the swipe UI tests against the local Instagram fixture.
# Usage:
#   UITests/run.sh                          # simulator "iPhone 17"
#   UITests/run.sh --device "Cristian's iPhone"   # a real iPhone on the same network as this Mac
set -euo pipefail
cd "$(dirname "$0")/.."
PORT=8765
if [[ "${1:-}" == "--device" ]]; then
  DESTINATION="platform=iOS,name=$2"
  IP="$(ipconfig getifaddr en0 || ipconfig getifaddr en1)"
  BIND=0.0.0.0
  export TEST_RUNNER_REELLESS_ORIGIN="http://$IP:$PORT"
  EXTRA=(-allowProvisioningUpdates)
else
  DESTINATION="platform=iOS Simulator,name=${1:-iPhone 17}"
  BIND=127.0.0.1
  EXTRA=()
fi
python3 UITests/Fixtures/server.py "$PORT" "$BIND" &
SERVER=$!
trap 'kill $SERVER' EXIT
xcodegen generate --quiet
xcodebuild test -project ReelLess.xcodeproj -scheme ReelLess -destination "$DESTINATION" \
  -only-testing:ReelLessUITests ${EXTRA[@]+"${EXTRA[@]}"}
