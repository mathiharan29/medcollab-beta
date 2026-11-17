"""Join a Phase 2 device report to the immutable speech fixtures."""

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import wave


def inspect_wav(path):
    with wave.open(str(path), "rb") as source:
        rate, width, channels = source.getframerate(), source.getsampwidth(), source.getnchannels()
        assert (rate, width, channels, source.getcomptype()) == (16000, 2, 1, "NONE")
        values = [item[0] for item in struct.iter_unpack("<h", source.readframes(source.getnframes()))]
    peak = max(map(abs, values))
    power = sum(value * value for value in values) / len(values)
    return {"rate": rate, "sampleWidthBytes": width, "channels": channels,
            "durationMs": len(values) * 1000 / rate, "peak": peak, "rms": round(math.sqrt(power), 1),
            "clippedSamples": sum(value in (-32768, 32767) for value in values),
            "nearSilenceFraction": round(sum(abs(value) <= 32 for value in values) / len(values), 4)}


def cause(row):
    if row.get("failureCategory") == "command_parsing" and row.get("transcriptMatched"):
        return "App parser or directory"
    if row.get("recognitionError"):
        return "Native recognition error"
    if row.get("transcriptMatched") is False:
        return "Transcript mismatch before Vocle"
    return row.get("failureCategory") or "Verified application outcome"


def audit(report, audio):
    manifest = {row["id"]: row for row in json.loads((audio / "manifest.json").read_text())}
    for row in report["attempts"]:
        sample = manifest[row["sample"]]
        wav = audio / sample["file"]
        assert hashlib.sha256(wav.read_bytes()).hexdigest() == sample["sha256"]
        assert row["sha256"] == sample["sha256"]
        yield {**row, **inspect_wav(wav), "voice": sample.get("voice"),
               "wordsPerMinute": sample.get("wordsPerMinute"), "lengthScale": sample.get("lengthScale"),
               "condition": sample.get("background", "silence"),
               "cause": cause(row)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    rows = list(audit(json.loads(args.report.read_text(encoding="utf-8")),
                      Path(__file__).resolve().parent))
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "clean-audio-audit.json").write_text(json.dumps(rows, indent=2) + "\n")
    columns = ("sample", "attempt", "voice", "wordsPerMinute", "lengthScale", "durationMs",
               "peak", "rms", "clippedSamples", "intendedCommand", "recognizedTranscript",
               "recognitionError", "expectedIntent", "parsedIntent", "expectedTarget",
               "resolvedTarget", "actualAction", "cause")
    def cell(value):
        return str(value if value is not None else "—").replace("|", "&#124;").replace("\n", " ")
    lines = ["# Phase 2 audio failures", "",
             "All fixtures were verified as signed PCM16 mono at 16 kHz. Amplitudes are PCM units.",
             "", "| " + " | ".join(columns) + " |",
             "|" + "---|" * len(columns)]
    lines.extend("| " + " | ".join(cell(row.get(key)) for key in columns) + " |"
                 for row in rows if row["result"] == "FAIL")
    (args.output / "clean-audio-failures.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
