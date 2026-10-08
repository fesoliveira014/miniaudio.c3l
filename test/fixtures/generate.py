#!/usr/bin/env python3
"""Write tone.wav: 0.25 s, 440 Hz, mono, 48 kHz, 16-bit PCM."""

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 48000
DURATION_SECONDS = 0.25
FREQUENCY_HZ = 440.0
AMPLITUDE = 0.5


def main() -> None:
    frame_count = int(SAMPLE_RATE * DURATION_SECONDS)
    samples = [
        int(AMPLITUDE * 32767 * math.sin(2.0 * math.pi * FREQUENCY_HZ * index / SAMPLE_RATE))
        for index in range(frame_count)
    ]
    path = Path(__file__).resolve().parent / "tone.wav"
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(struct.pack(f"<{frame_count}h", *samples))


if __name__ == "__main__":
    main()
