"""Build the ordered attempt list and the exact RIFF data bytes for Android."""

import hashlib
import json
from pathlib import Path
import re
import sys
import uuid
import wave


audio, assets = map(Path, sys.argv[1:3])
scope, repeats = sys.argv[3], int(sys.argv[4])
assert scope in ("smoke", "full")
assert 1 <= repeats <= 5
manifest = {row["id"]: row for row in json.loads((audio / "manifest.json").read_text())}
plan = json.loads((audio / "digital-plan.json").read_text())
attempts = []
for row in plan:
    if scope == "smoke" and not row.get("smoke"):
        continue
    sample = manifest[row["sample"]]
    assert re.fullmatch(r"[a-z0-9-]+", sample["id"])
    wav = audio / sample["file"]
    assert hashlib.sha256(wav.read_bytes()).hexdigest() == sample["sha256"]
    with wave.open(str(wav), "rb") as source:
        assert (source.getnchannels(), source.getsampwidth(), source.getframerate(),
                source.getcomptype()) == (1, 2, 16000, "NONE")
        frames = source.getnframes()
        pcm = source.readframes(frames)
    assert frames > 0 and len(pcm) == 2 * frames
    assert (not any(pcm)) == (row["action"] == "silence")
    (assets / f"{sample['id']}.pcm").write_bytes(pcm)
    count = repeats if scope == "full" and row.get("repeat") else 1
    for attempt in range(1, count + 1):
        attempts.append({
            **row, "attempt": attempt, "sha256": sample["sha256"],
            "phrase": sample["phrase"], "intent": sample["expectedIntent"],
            "expectedAction": sample["expectedResult"], "bytes": len(pcm),
            "pcmSha256": hashlib.sha256(pcm).hexdigest(),
        })
assert attempts
print(json.dumps({"run": str(uuid.uuid4()), "scope": scope, "attempts": attempts}, indent=2))
