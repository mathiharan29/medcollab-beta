"""Regenerate the synthetic fixtures with Python 3.12 and espeakng-loader 0.2.4."""

import audioop
import ctypes
import hashlib
import json
from pathlib import Path
import random
import wave

from espeakng_loader import get_data_path, load_library


HERE = Path(__file__).resolve().parent
RATE = 16000

# ID, phrase, eSpeak voice, words/minute, pitch, case, intent, target, outcome
SAMPLES = [
    ("chat-bala", "Open Bala chat.", "en+m3", 145, 42, "FR-AST-31",
     "OpenChat", "B", "Open the existing Bala DM after confirmation"),
    ("chat-with-bala", "Open chat with Doctor Bala.", "en-us+f2", 132, 57, "FR-AST-31",
     "OpenChat", "B", "Open the existing Bala DM after confirmation"),
    ("chat-bala-noise", "Open chat with Bala.", "en+f3", 160, 53, "FR-AST-31",
     "OpenChat", "B", "Open the existing Bala DM after confirmation"),
    ("chat-bela", "Open Bela chat.", "en-us+m3", 145, 42, "FR-AST-31",
     "OpenChat", "F", "Open the existing Bela DM after confirmation"),
    ("draft-priya", "Hand off bed seven to Priya.", "en+f2", 140, 56, "FR-AST-32",
     "Handoff", "C", "Persist an unsubmitted draft for Priya with bed 7"),
    ("draft-priya-paused", "Draft a handoff for bed seven to Priya.", "en-us+m2",
     126, 46, "FR-AST-32", "Handoff", "C", "Persist an unsubmitted draft for Priya with bed 7"),
    ("unknown", "Open Zelda chat.", "en-us+f3", 146, 60, "FR-AST-33",
     "Clarify", None, "Display a clarification with no choices and stay on Home"),
    ("missing-destination", "Create a handoff for Priya.", "en+f2", 146, 53,
     "FR-AST-33", None, None, "Show unsupported feedback and leave the database unchanged"),
    ("ambiguous", "Open Asha chat.", "en+m2", 142, 45, "FR-AST-33",
     "Clarify", ["D", "E"], "Show both Asha identities, then open only the chosen E DM"),
    ("chat-with-alex", "Open chat with Doctor Alex.", "en-us+m3", 132, 46, "FR-AST-34",
     "OpenChat", "B", "Open the exact existing Alex DM after confirmation in the hosted digital smoke test"),
]


def main():
    synth = load_library()
    synth.espeak_Initialize.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_char_p, ctypes.c_int]
    synth.espeak_SetVoiceByName.argtypes = [ctypes.c_char_p]
    synth.espeak_SetParameter.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int]
    synth.espeak_Synth.argtypes = [
        ctypes.c_char_p, ctypes.c_size_t, ctypes.c_uint, ctypes.c_int, ctypes.c_uint,
        ctypes.c_uint, ctypes.c_void_p, ctypes.c_void_p,
    ]
    synth.espeak_Info.argtypes = [ctypes.c_void_p]
    synth.espeak_Info.restype = ctypes.c_char_p
    native_rate = synth.espeak_Initialize(2, 0, str(Path(get_data_path()).parent).encode(), 0x8000)
    if native_rate <= 0:
        raise RuntimeError("Could not initialize eSpeak NG")
    version = synth.espeak_Info(None).decode()
    chunks = []
    callback_type = ctypes.CFUNCTYPE(
        ctypes.c_int, ctypes.POINTER(ctypes.c_int16), ctypes.c_int, ctypes.c_void_p
    )

    @callback_type
    def collect(samples, count, _events):
        if samples and count:
            chunks.append(ctypes.string_at(samples, count * 2))
        return 0

    synth.espeak_SetSynthCallback(collect)
    samples = []
    for key, phrase, voice, speed, pitch, case, intent, target, outcome in SAMPLES:
        assert synth.espeak_SetVoiceByName(voice.encode()) == 0, voice
        assert synth.espeak_SetParameter(1, speed, 0) == 0
        assert synth.espeak_SetParameter(3, pitch, 0) == 0
        chunks.clear()
        spoken = phrase.replace("bed seven to", "bed seven, to") if key.endswith("-paused") else phrase
        payload = spoken.encode()
        assert synth.espeak_Synth(payload, len(payload) + 1, 0, 1, 0, 1, None, None) == 0
        pcm, _ = audioop.ratecv(b"".join(chunks), 2, 1, native_rate, RATE, None)
        assert audioop.rms(pcm, 2) > 100
        if key.endswith("-noise"):
            rng = random.Random(1414)
            noise = b"".join(rng.randint(-210, 210).to_bytes(2, "little", signed=True)
                             for _ in range(len(pcm) // 2))
            pcm = audioop.add(pcm, noise, 2)
        pcm = bytes(RATE // 2) + pcm + bytes(RATE * 2)
        path = HERE / f"{key}.wav"
        with wave.open(str(path), "wb") as output:
            output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
            output.writeframes(pcm)
        samples.append({
            "id": key, "file": path.name, "phrase": phrase, "synthesisText": spoken,
            "voice": voice, "locale": "en-GB" if voice.startswith("en+") else "en-US", "wordsPerMinute": speed,
            "pitch": pitch, "background": "seeded low-amplitude white noise" if key.endswith("-noise") else "clean",
            "format": "WAV PCM16 mono 16000 Hz", "durationMs": len(pcm) * 1000 // (2 * RATE),
            "caseId": case, "expectedIntent": intent, "target": target, "expectedResult": outcome,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "provenance": f"eSpeak NG {version} via espeakng-loader 0.2.4, generated for Vocle",
        })
    (HERE / "manifest.json").write_text(json.dumps(samples, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
