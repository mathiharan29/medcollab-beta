#!/usr/bin/env bash
set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fixture_dir="$(dirname -- "$here")"
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?Android SDK required}}"
tools="$sdk/build-tools/35.0.0"
platform="$sdk/platforms/android-35/android.jar"
adb="$sdk/platform-tools/adb"
output="${1:?evidence output path required}"
build="$(mktemp -d)"
trap 'rm -rf -- "$build"' EXIT
mkdir -p "$build/assets" "$build/classes" "$output"

# Validate and strip the checked-in RIFF container without transcoding.
python3 - "$fixture_dir" "$build/assets/sample.pcm" "${VOCLE_PROBE_SAMPLE:-chat-bala}" > "$output/fixture.json" <<'PY'
import hashlib, json, struct, sys, wave
from pathlib import Path

fixtures, destination = map(Path, sys.argv[1:3])
sample = next(row for row in json.loads((fixtures / "manifest.json").read_text())
              if row["id"] == sys.argv[3])
wav = fixtures / sample["file"]
assert hashlib.sha256(wav.read_bytes()).hexdigest() == sample["sha256"]
with wave.open(str(wav), "rb") as stream:
    assert (stream.getnchannels(), stream.getsampwidth(), stream.getframerate(), stream.getcomptype()) == (1, 2, 16000, "NONE")
    frames = stream.getnframes()
    pcm = stream.readframes(frames)
assert len(pcm) == 2 * frames
peak = max(abs(sample[0]) for sample in struct.iter_unpack("<h", pcm))
assert peak > 512
destination.write_bytes(pcm)
print(json.dumps({
    "sample": sample["id"], "phrase": sample["phrase"], "wavSha256": sample["sha256"],
    "pcmSha256": hashlib.sha256(pcm).hexdigest(), "pcmBytes": len(pcm),
    "frames": frames, "channels": 1, "rate": 16000, "encoding": "signed little-endian PCM16",
    "peak": peak, "silenceControlBytes": len(pcm),
}, indent=2))
PY
cp "$output/fixture.json" "$build/assets/fixture.json"

javac --release 11 -classpath "$platform" -d "$build/classes" "$here/AudioSourceProbe.java"
jar cf "$build/classes.jar" -C "$build/classes" .
"$tools/d8" --min-api 33 --lib "$platform" --output "$build" "$build/classes.jar"
"$tools/aapt2" link -I "$platform" --manifest "$here/AndroidManifest.xml" -A "$build/assets" \
  --min-sdk-version 33 --target-sdk-version 35 -o "$build/resources.apk"
(cd "$build" && zip -q resources.apk classes.dex)
"$tools/zipalign" -f 4 "$build/resources.apk" "$build/aligned.apk"
keytool -genkeypair -keystore "$build/debug.keystore" -storepass android -keypass android \
  -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 30 -dname 'CN=Vocle Synthetic Probe' -noprompt
"$tools/apksigner" sign --ks "$build/debug.keystore" --ks-pass pass:android \
  --out "$build/probe.apk" "$build/aligned.apk"

{
  "$adb" shell getprop ro.build.version.sdk
  "$adb" shell getprop ro.build.fingerprint
  "$adb" shell settings get secure voice_recognition_service
  "$adb" shell cmd package query-services --brief -a android.speech.RecognitionService
  "$adb" shell dumpsys speech_recognition || true
} > "$output/services.txt"

"$adb" install -g "$build/probe.apk"
set +e
timeout 420 "$adb" shell am instrument -w com.vocle.audiosourceprobe/.AudioSourceProbe \
  2>&1 | tee "$output/instrumentation.txt"
status="${PIPESTATUS[0]}"
set -e
"$adb" logcat -d -v raw -s 'VocleAudioSource:I' '*:S' | tee "$output/probe.ndjson"
"$adb" logcat -d -v brief -s 'SpeechRecognizer:V' 'RecognitionService:V' \
  'SpeechRecognitionManagerService:V' 'RemoteSpeechRecognitionService:V' 'AndroidRuntime:E' '*:S' \
  > "$output/speech-service.log"
"$adb" uninstall com.vocle.audiosourceprobe
test "$status" = 0
grep -Fx 'AUDIO_SOURCE_PROVEN=true' "$output/instrumentation.txt"
