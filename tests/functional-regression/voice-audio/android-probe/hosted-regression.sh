#!/usr/bin/env bash
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
output="${1:?evidence directory required}"
export VOCLE_AUDIO_SUITE_SCOPE="${VOCLE_AUDIO_SUITE_SCOPE:-full}"
baseline_status=0
env -u VOCLE_AUDIO_SUITE_SCOPE VOCLE_PROBE_SAMPLE=chat-with-alex VOCLE_PROBE_ONLINE_ONLY=true \
  bash "$here/run.sh" "$output/probe" || baseline_status=$?

batch_status=0
bash "$here/run.sh" "$output/batch" || batch_status=$?
export VOCLE_DIGITAL_SOURCE_EVIDENCE="$output/probe"
export VOCLE_DIGITAL_SUITE_EVIDENCE="$output/batch"
node tests/functional-regression/scripts/validate-catalog.mjs
cases="$(node --input-type=module -e '
import {configuredDigitalAttempts} from "./tests/functional-regression/scripts/voice-digital-suite.mjs";
console.log(["FR-AST-34", ...new Set(configuredDigitalAttempts().map(row => row.caseId))].join(","));
')"
node tests/functional-regression/scripts/run-device.mjs --cases="$cases" \
  --emulator=emulator-5554 --adb-bin="$ANDROID_HOME/platform-tools/adb" \
  --source-sha="$(git rev-parse HEAD)" --output="$output/device"
test "$baseline_status" -eq 0 && test "$batch_status" -eq 0
