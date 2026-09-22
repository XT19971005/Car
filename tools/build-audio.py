"""Rebuild the CC0 domasx2 engine texture; requires numpy."""
from pathlib import Path
import wave
import numpy as np
root = Path(__file__).resolve().parents[1] / "godot/assets/audio"
with wave.open(str(root / "engine_source.wav"), "rb") as source:
    assert source.getnchannels() == 1 and source.getsampwidth() == 2
    rate = source.getframerate()
    data = np.frombuffer(source.readframes(source.getnframes()), dtype="<i2").astype(np.float64)
data -= data.mean()
fade = min(2205, len(data) // 8)
weight = np.linspace(0, 1, fade)
data[:fade] = data[-fade:] * (1 - weight) + data[:fade] * weight
data = data[:-fade]
data *= .78 * 32767 / max(1, np.max(np.abs(data)))
with wave.open(str(root / "engine_texture.wav"), "wb") as target:
    target.setnchannels(1)
    target.setsampwidth(2)
    target.setframerate(rate)
    target.writeframes(data.astype("<i2").tobytes())
print("Engine texture rebuilt", rate, len(data))
