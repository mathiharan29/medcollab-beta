"""Generate the public-domain-trained Piper speech fixtures (Python 3.12)."""

import audioop
import hashlib
from importlib.metadata import version
import io
import json
from pathlib import Path
import sys
import wave

from piper import PiperVoice, SynthesisConfig


HERE = Path(__file__).resolve().parent
REVISION = "375a0fe641dea077c2a47b4e9a056d6da521eed3"
MODELS = {
    "ljspeech": "6f52a751e2349abe7a76735eb09dc1875298c77ea2342ffd2fef79ff81b87f22",
    "norman": "b9739443232a80a59c7d18810dd856899bf16a7964725f5ab81ea49b1351cb71",
}

# Unique ID, script, voice, speed scale, intent, fixture target and postcondition.
SAMPLES = {
    "FR-AST-36": [
        ("chat-morgan-clear", "Show conversation with Doctor Morgan.", "ljspeech", 1.06,
         "OpenChat", "H", "Open the exact Morgan DM after confirmation"),
        ("chat-bala-clear", "Open chat with Doctor Bala.", "norman", 1.06,
         "OpenChat", "B", "Open the exact Bala DM after confirmation"),
        ("chat-ward-clear", "Open chat with general.", "norman", 0.95,
         "OpenChat", "ward", "Open the exact space channel after confirmation"),
        ("chat-needl-clear", "Open chat with Nurse Station.", "ljspeech", 1.0,
         "OpenChat", "needl", "Open the exact Needl after confirmation"),
    ],
    "FR-AST-37": [
        ("draft-alex-clear", "Hand off to Alex.", "ljspeech", 1.1,
         "Handoff", "G", "Persist and open an unsubmitted Alex draft with no patients"),
        ("draft-priya-clear", "Hand off bed seven to Priya.", "norman", 1.06,
         "Handoff", "C", "Persist and open an unsubmitted Priya draft with bed 7"),
        ("draft-alex-bed-clear", "Hand off bed twelve to Alex.", "ljspeech", 0.95,
         "Handoff", "G", "Persist and open an unsubmitted Alex draft with bed 12"),
    ],
    "FR-AST-38": [
        ("cancel-alex-clear", "Open chat with Doctor Alex.", "norman", 1.0,
         "OpenChat", "G", "Dismiss the actionable proposal without a DM lookup"),
        ("unrelated-clear", "The sky is blue.", "ljspeech", 0.97,
         None, None, "Show unsupported feedback and make no changes"),
        ("unknown-clear", "Open chat with Doctor Zelda.", "ljspeech", 1.0,
         "Clarify", None, "Clarify the missing doctor without choices"),
        ("ambiguous-jordan", "Open chat with Doctor Jordan.", "norman", 1.08,
         "Clarify", ["Y", "Z"], "Offer both Jordan IDs. Confirm only the chosen Jordan DM"),
        ("draft-taylor-clear", "Hand off to Taylor.", "norman", 1.08,
         "Handoff", "T", "Reject the handoff because no space is shared"),
        ("missing-handoff-recipient", "Create a handoff for Doctor Alex.", "ljspeech", 1.06,
         None, None, "Show unsupported feedback because the local grammar requires a to-recipient"),
        ("chat-unavailable", "Show chat with Doctor Alex.", "ljspeech", 1.03,
         "OpenChat", "G", "Keep Home and show the DM backend failure after confirmation"),
    ],
    "FR-AST-39": [
        ("search-rounds", "Find rounds.", "ljspeech", 1.07,
         "Search", None, "Open Search with its implemented empty input"),
    ],
    "FR-AST-40": [
        ("send-alex-clear", "Tell Alex that the meeting is complete.", "ljspeech", 1.02,
         "SendMessage", "G", "Persist one exact message in Alex's existing DM"),
        ("set-on-call", "Mark me as on call.", "norman", 1.06,
         "SetAvailability", None, "Persist on_call for the signed-in doctor"),
        ("read-alerts-clear", "Mark all alerts as read.", "ljspeech", 1.08,
         "MarkAlertsRead", None, "Mark the actor's alerts read and clear the badge"),
        ("clear-notifications", "Clear notifications.", "norman", 1.06,
         "MarkAlertsRead", None, "Mark the actor's alerts read and clear the badge"),
    ],
}


def main(model_dir):
    assert version("piper-tts") == "1.4.2"
    voices = {}
    for name, sha in MODELS.items():
        model = model_dir / name / f"en_US-{name}-medium.onnx"
        assert hashlib.sha256(model.read_bytes()).hexdigest() == sha
        voices[name] = PiperVoice.load(model)
    manifest = HERE / "manifest.json"
    previous = json.loads(manifest.read_text())
    known = {row["id"]: row for row in previous}
    for case, samples in SAMPLES.items():
        for key, text, name, speed, intent, target, outcome in samples:
            path = HERE / f"{key}.wav"
            if key in known and path.exists():
                assert hashlib.sha256(path.read_bytes()).hexdigest() == known[key]["sha256"], key
                continue
            rendered = io.BytesIO()
            with wave.open(rendered, "wb") as output:
                voices[name].synthesize_wav(text, output, SynthesisConfig(
                    length_scale=speed, noise_scale=0.0, noise_w_scale=0.0))
            rendered.seek(0)
            with wave.open(rendered, "rb") as source:
                assert (source.getnchannels(), source.getsampwidth()) == (1, 2)
                pcm, _ = audioop.ratecv(source.readframes(source.getnframes()), 2, 1,
                                        source.getframerate(), 16000, None)
            assert audioop.rms(pcm, 2) > 100
            pcm = bytes(8000) + pcm + bytes(32000)
            with wave.open(str(path), "wb") as output:
                output.setparams((1, 2, 16000, 0, "NONE", "not compressed"))
                output.writeframes(pcm)
            previous.append({
                "id": key, "file": path.name, "phrase": text, "synthesisText": text,
                "voice": f"en_US-{name}-medium", "locale": "en-US", "lengthScale": speed,
                "background": "clean", "format": "WAV PCM16 mono 16000 Hz",
                "durationMs": len(pcm) // 32, "caseId": case, "expectedIntent": intent,
                "target": target, "expectedResult": outcome,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "modelSha256": MODELS[name],
                "modelCard": f"https://huggingface.co/rhasspy/piper-voices/blob/{REVISION}/en/en_US/{name}/medium/MODEL_CARD",
                "provenance": "Piper TTS 1.4.2 CPU synthesis, public-domain training recordings, zero synthesis noise",
            })
    manifest.write_text(json.dumps(previous, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
