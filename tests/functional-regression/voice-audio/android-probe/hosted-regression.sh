#!/usr/bin/env bash
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
output="${1:?evidence directory required}"
export VOCLE_PROBE_SAMPLE=chat-with-alex
export VOCLE_PROBE_ONLINE_ONLY=true
bash "$here/run.sh" "$output/probe"
export VOCLE_DIGITAL_SOURCE_EVIDENCE="$output/probe"
node tests/functional-regression/scripts/validate-catalog.mjs
node tests/functional-regression/scripts/run-device.mjs --cases=FR-AST-34 \
  --emulator=emulator-5554 --source-sha="$(git rev-parse HEAD)" --output="$output/device"
