#!/usr/bin/env bash
set -euo pipefail

image="${1:?SDK system image required}"
output="${2:?emulator evidence directory required}"
shift 2
sdk="${ANDROID_HOME:?Android SDK required}"
cmdline="$sdk/cmdline-tools/latest/bin"
adb="$sdk/platform-tools/adb"
emulator="$sdk/emulator/emulator"
export PATH="$sdk/platform-tools:$PATH"
mkdir -p "$output"
sudo chmod a+rw /dev/kvm
"$cmdline/sdkmanager" --install "emulator" "platform-tools" "platforms;android-35" "build-tools;35.0.0" "$image"

export ANDROID_AVD_HOME="${RUNNER_TEMP:?GitHub runner temp directory required}/vocle-avds"
mkdir -p "$ANDROID_AVD_HOME"
"$cmdline/avdmanager" create avd --name vocle-audio-source --package "$image" \
  --path "$ANDROID_AVD_HOME/vocle-audio-source.avd" --device pixel_7 --force <<< no
test -s "$ANDROID_AVD_HOME/vocle-audio-source.ini"
"$emulator" -list-avds | grep -Fx vocle-audio-source

android_user_dir="${ANDROID_USER_HOME:-$HOME/.android}"
mkdir -p "$android_user_dir"
if [ ! -s "$android_user_dir/adbkey.pub" ]; then
  "$adb" keygen "$android_user_dir/adbkey"
fi
export ADB_VENDOR_KEYS="$android_user_dir/adbkey"
"$adb" start-server
"$emulator" -avd vocle-audio-source -port 5554 -no-window -no-audio \
  -no-snapshot -wipe-data -no-boot-anim -gpu swiftshader -memory 3072 -cores 2 \
  > "$output/emulator.log" 2>&1 &
emulator_pid=$!
trap 'kill "$emulator_pid" 2>/dev/null || true; wait "$emulator_pid" 2>/dev/null || true' EXIT
end=$((SECONDS + 240))
until [ "$(timeout 8 "$adb" -s emulator-5554 shell getprop sys.boot_completed | tr -d '\r')" = 1 ] &&
    timeout 8 "$adb" -s emulator-5554 shell pm path android; do
  if [ "$SECONDS" -ge "$end" ] || ! kill -0 "$emulator_pid" 2>/dev/null; then
    timeout 8 "$adb" devices -l > "$output/adb-devices.txt" || true
    echo "::error::The Android emulator never became ready"
    exit 1
  fi
  sleep 3
done
"$@"
