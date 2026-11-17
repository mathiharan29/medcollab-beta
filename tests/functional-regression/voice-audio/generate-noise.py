"""Generate and verify the deterministic Phase 3 WAVs without external audio."""

import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave

ROOT = Path(__file__).resolve().parent
RATE = 16000
VERSION = 1
GAIN = 0.48
CASES = json.loads((ROOT / "digital-plan.json").read_text())
BASE_PLAN = {row["sample"]: row for row in CASES}
BASE = {row["id"]: row for row in json.loads((ROOT / "manifest.json").read_text())}
ANCHORS = ("chat-with-alex", "draft-alex-bed-clear", "chat-needl-clear", "open-profile")
DIAGNOSTICS = ("chat-bala", "chat-with-bala", "chat-bela", "draft-priya",
               "draft-priya-clear", "chat-ward-clear", "search-rounds-quiet")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(sample):
    item = BASE[sample]
    path = ROOT / item["file"]
    assert sha(path.read_bytes()) == item["sha256"], sample
    with wave.open(str(path), "rb") as source:
        assert (source.getnchannels(), source.getsampwidth(), source.getframerate(),
                source.getcomptype()) == (1, 2, RATE, "NONE")
        return [value for value, in struct.iter_unpack("<h", source.readframes(source.getnframes()))]


def power(samples):
    return sum(value * value for value in samples) / len(samples)


def background(condition, length, offset=0):
    rng = random.Random(363 + offset)
    if condition == "babble":
        tracks = [read("unrelated"), read("unrelated-clear"), read("unrelated-clear")[::-1]]
        return [sum(track[(i + start) % len(track)] for track, start in zip(tracks, (3100, 7100, 13200)))
                for i in range(length)]
    state = 0
    output = []
    for i in range(length):
        state = (29 * state + rng.randint(-32768, 32767)) // 30
        if condition == "ventilation":
            output.append(state + rng.randint(-300, 300))
        elif condition == "equipment-steps":
            t = (i + 2700) % 17200
            # Short 800 Hz square-tone bursts and low-frequency movement pulses.
            beep = (3600 if i % 20 < 10 else -3600) if t < 1700 else 0
            step = state * max(0, 2200 - (i + 1600) % 5600) // 480
            output.append(state + beep + step)
        else:
            raise ValueError(condition)
    return output


def variant_id(base, condition, snr):
    if condition == "matched-clean":
        return base + "-matched-clean"
    level = f"neg{-snr}" if snr < 0 else str(snr)
    return f"{base}-{condition}-{level}db"


def entry(sample, classification, *, repeat=False, smoke=False):
    fixture = BASE[sample]
    props = BASE_PLAN[sample]
    case = "FR-AST-42" if classification == "safety" else "FR-AST-41"
    return {**props, "caseId": case, "file": fixture["file"], "baseSample": sample,
            "baseSha256": fixture["sha256"], "sha256": fixture["sha256"], "phrase": fixture["phrase"],
            "intent": fixture["expectedIntent"], "expectedAction": fixture["expectedResult"],
            "condition": fixture["background"] if fixture.get("background", "").startswith("seeded") else "original",
            "snrDb": None, "actualSnrDb": None, "speechGain": 1,
            "classification": classification, "repeat": repeat, "smoke": smoke}


def save(output, row, pcm):
    assert max(map(abs, pcm)) < 32767, (row["sample"], "clipping")
    raw = struct.pack(f"<{len(pcm)}h", *pcm)
    path = output / (row["sample"] + ".wav")
    with wave.open(str(path), "wb") as dest:
        dest.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        dest.writeframes(raw)
    return {**row, "file": path.name, "sha256": sha(path.read_bytes()), "pcmSha256": sha(raw),
            "generated": True, "durationMs": len(pcm) * 1000 / RATE, "format": "WAV PCM16 mono 16000 Hz",
            "peak": max(map(abs, pcm)), "rms": round(math.sqrt(power(pcm)), 2), "clippedSamples": 0,
            "generatorVersion": VERSION}


def mix(output, base, condition, snr, *, smoke=False, repeat=False, classification="characterization",
        masker=None):
    original = read(base)
    speech = [round(GAIN * value) for value in original]
    active = [i for i, value in enumerate(original) if abs(value) >= 128]
    lo, hi = active[0], active[-1] + 1
    noise = [0] * len(original)
    measured = None
    if snr is not None:
        if masker:
            # A separate, recognizable command starts at the same time as the
            # intended one. Its ending can extend beyond the foreground WAV.
            interference = read(masker)
            length = max(len(interference), len(speech))
            noise = interference + [0] * (length - len(interference))
            speech.extend([0] * (length - len(speech)))
        else:
            noise = background(condition, len(original))
        factor = math.sqrt(power(speech[lo:hi]) / power(noise[lo:hi]) / 10 ** (snr / 10))
        noise = [round(factor * value) for value in noise]
        measured = round(10 * math.log10(power(speech[lo:hi]) / power(noise[lo:hi])), 4)
        assert abs(measured - snr) <= 0.02
    row = entry(base, classification, smoke=smoke, repeat=repeat)
    sample = variant_id(base, condition, snr)
    return save(output, {**row, "sample": sample, "condition": condition,
                         "actualSnrDb": measured, "snrDb": snr, "speechGain": GAIN,
                         "speechWindowSamples": [lo, hi], "masker": masker,
                         **({"maskerSha256": BASE[masker]["sha256"]} if masker else {})},
                [spoken + ambient for spoken, ambient in zip(speech, noise)])


def generate(output):
    rows = [entry(base, "functional", repeat=True, smoke=base in ANCHORS[:2]) for base in ANCHORS]
    rows += [entry(base, "characterization", repeat=True) for base in DIAGNOSTICS]
    for base in ANCHORS[:2]:
        rows.append(mix(output, base, "matched-clean", None, repeat=True))
        for snr in (20, 10, 5, 0, -5):
            rows.append(mix(output, base, "babble", snr, repeat=snr in (10, 0)))
        for condition in ("ventilation", "equipment-steps"):
            for snr in (10, 0):
                smoke = base == ANCHORS[0] and condition == "ventilation" and snr == 10
                rows.append(mix(output, base, condition, snr, smoke=smoke,
                                classification="functional" if smoke else "characterization"))
    rows += [entry("unknown-clear", "safety", repeat=True),
             entry("ambiguous-jordan", "safety", repeat=True),
             entry("incomplete-chat", "safety", repeat=True, smoke=True),
             entry("silence", "safety", smoke=True)]
    for primary, masker in (("chat-bala", "chat-with-alex"), ("draft-priya-clear", "draft-alex-bed-clear")):
        rows.append(mix(output, primary, "competing-command", -5, masker=masker, classification="safety"))
    # Background speech control contains a known synthetic command with no
    # authorized foreground speaker. Identical PCM is intentional.
    rows.append(save(output, {**entry("chat-with-alex", "safety", smoke=True),
                              "sample": "background-command", "condition": "background-only",
                              "action": "background", "target": None, "intent": None, "phrase": "",
                              "expectedAction": "Observe and cancel any proposal without execution"},
                     read("chat-with-alex")))
    noise = background("equipment-steps", RATE * 3)
    scale = 2500 / math.sqrt(power(noise))
    rows.append(save(output, {**entry("silence", "safety"), "sample": "background-equipment",
                              "condition": "background-only", "action": "background",
                              "expectedAction": "Observe and cancel any proposal without execution"},
                     [round(scale * value) for value in noise]))
    assert len({row["sample"] for row in rows}) == len(rows)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--write-manifest", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    target = ROOT / "noise-manifest.json"
    manifest = {
        "version": VERSION, "seed": 363, "sampleRate": RATE,
        "provenance": "Synthetic ventilation, equipment tones, movement and speech-only maskers drawn from the existing synthetic corpus",
        "fixtures": generate(args.output),
    }
    if args.write_manifest:
        target.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    else:
        assert json.loads(target.read_text()) == manifest, "Regenerated WAVs differ from the committed noise manifest"


if __name__ == "__main__":
    main()
