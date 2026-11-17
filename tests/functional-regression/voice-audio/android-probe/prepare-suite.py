"""Build the ordered attempt list and the exact RIFF data bytes for Android."""

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import uuid
import wave


audio, assets = map(Path, sys.argv[1:3])
scope, repeats = sys.argv[3], int(sys.argv[4])
assert scope in ("smoke", "full", "noise-smoke", "noise-full")
assert 1 <= repeats <= 5
noise = scope.startswith("noise-")
if noise:
    generated = assets.parent / "generated-wavs"
    subprocess.run([sys.executable, str(audio / "generate-noise.py"), str(generated)], check=True)
    plan = json.loads((audio / "noise-manifest.json").read_text())["fixtures"]
    manifest = {row["sample"]: row for row in plan}
else:
    manifest = {row["id"]: row for row in json.loads((audio / "manifest.json").read_text())}
    plan = json.loads((audio / "digital-plan.json").read_text())
attempts = []
for row in plan:
    if scope.endswith("smoke") and not row.get("smoke"):
        continue
    sample = manifest[row["sample"]]
    assert re.fullmatch(r"[a-z0-9-]+", row["sample"])
    wav = (generated if sample.get("generated") else audio) / sample["file"]
    assert hashlib.sha256(wav.read_bytes()).hexdigest() == sample["sha256"]
    with wave.open(str(wav), "rb") as source:
        assert (source.getnchannels(), source.getsampwidth(), source.getframerate(),
                source.getcomptype()) == (1, 2, 16000, "NONE")
        frames = source.getnframes()
        pcm = source.readframes(frames)
    assert frames > 0 and len(pcm) == 2 * frames
    assert (not any(pcm)) == (row["action"] == "silence")
    pcm_hash = hashlib.sha256(pcm).hexdigest()
    if sample.get("pcmSha256"):
        assert pcm_hash == sample["pcmSha256"]
    (assets / f"{row['sample']}.pcm").write_bytes(pcm)
    count = repeats if scope.endswith("full") and row.get("repeat") else 1
    for attempt in range(1, count + 1):
        attempts.append({
            **row, "attempt": attempt, "sha256": sample["sha256"],
            "phrase": sample["phrase"], "intent": sample["intent"] if noise else sample["expectedIntent"],
            "expectedAction": sample["expectedAction"] if noise else sample["expectedResult"], "bytes": len(pcm),
            "pcmSha256": pcm_hash,
        })
assert attempts
print(json.dumps({"run": str(uuid.uuid4()), "scope": scope, "attempts": attempts}, indent=2))
