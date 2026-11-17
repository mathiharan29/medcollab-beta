"""Send WAV PCM to the Android Emulator virtual microphone via loopback gRPC."""

import argparse
import itertools
import json
from pathlib import Path
import time
import wave

import grpc


def varint(value):
    encoded = bytearray()
    while value >= 128:
        encoded.append((value & 127) | 128)
        value >>= 7
    encoded.append(value)
    return bytes(encoded)


def message(field, value):
    return varint((field << 3) | 2) + varint(len(value)) + value


def packets(source):
    rate = source.getframerate()
    # AudioFormat: samplingRate, default Mono, AUD_FMT_S16, MODE_REAL_TIME.
    audio_format = b"\x08" + varint(rate) + b"\x18\x01\x20\x01"
    start = time.monotonic()
    for index in itertools.count():
        pcm = source.readframes(rate // 50)
        if not pcm:
            break
        time.sleep(max(0, start + index / 50 - time.monotonic()))
        yield (message(1, audio_format) + b"\x10" + varint(time.time_ns() // 1000)
               + message(3, pcm))
    # Allow the final packet to drain before closing the virtual input stream.
    time.sleep(max(0, start + index / 50 - time.monotonic()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("discovery", type=Path)
    parser.add_argument("serial")
    parser.add_argument("wav", type=Path)
    args = parser.parse_args()
    config = dict(line.split("=", 1) for line in
                  args.discovery.read_text(encoding="utf-8").splitlines() if "=" in line)
    port = int(config["grpc.port"])
    if f'emulator-{config["port.serial"]}' != args.serial or not 0 < port < 65536:
        raise SystemExit("The gRPC discovery file does not match the ADB serial")
    token = config.get("grpc.token")
    if not token:
        raise SystemExit("Start the emulator with -grpc <port> -grpc-use-token")
    with wave.open(str(args.wav), "rb") as source:
        if (source.getnchannels(), source.getsampwidth(), source.getframerate()) != (1, 2, 16000):
            raise SystemExit("Expected mono PCM16 at 16 kHz")
        with grpc.insecure_channel(
            f"127.0.0.1:{port}", options=(("grpc.enable_http_proxy", 0),)
        ) as channel:
            method = "/android.emulation.control.EmulatorController/injectAudio"
            try:
                channel.stream_unary(method)(
                    packets(source), timeout=12, metadata=(("authorization", f"Bearer {token}"),)
                )
            except grpc.RpcError as error:
                raise SystemExit(f"injectAudio RPC {error.code().name}") from None
        print(json.dumps({"transport": "emulator-microphone-grpc",
                          "frames": source.getnframes(), "sampleRate": source.getframerate()}))


if __name__ == "__main__":
    main()
