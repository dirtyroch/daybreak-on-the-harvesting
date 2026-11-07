#!/usr/bin/env python3
"""Original Daybreak cues. Deterministic synthesis, no borrowed recordings.

Writes audio/original/*.wav and audio/samples/daybreak-original-mix.wav.
These files are silent in-game until their uploadId is set in SfxIds.luau.
"""
import math
import os
import struct
import wave

SR = 22050
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "original")
SAMPLE = os.path.join(ROOT, "samples")


class Rng:
    def __init__(self, seed: int):
        self.state = seed & 0x7FFFFFFF

    def unit(self) -> float:
        self.state = (1103515245 * self.state + 12345) & 0x7FFFFFFF
        return (self.state % 100000) / 100000.0

    def signed(self) -> float:
        return self.unit() * 2.0 - 1.0


def silence(n: int):
    return [0.0] * n


def env(n: int, a: float, d: float):
    out = []
    for i in range(n):
        t = i / SR
        if t < a:
            g = t / a if a else 1
        else:
            g = math.exp(-(t - a) / max(d, 1e-4))
        out.append(g)
    return out


def tone(freq: float, n: int, decay: float, amp: float = 1.0, slide: float = 0.0):
    e = env(n, 0.004, decay)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq * (1.0 + slide * (i / max(n - 1, 1)))
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * e[i] * amp)
    return out


def noise(n: int, seed: int, decay: float, amp: float = 1.0):
    rng = Rng(seed)
    e = env(n, 0.002, decay)
    out = []
    for i in range(n):
        out.append(rng.signed() * e[i] * amp)
    return out


def lowpass(samples, window: int):
    acc = 0.0
    buf = [0.0] * window
    out = []
    for i, s in enumerate(samples):
        acc += s - buf[i % window]
        buf[i % window] = s
        out.append(acc / window)
    return out


def mix_at(dst, src, at: int, gain: float = 1.0):
    for i, s in enumerate(src):
        j = at + i
        if 0 <= j < len(dst):
            dst[j] += s * gain


def normalize(samples, peak: float = 0.5):
    m = max(1e-6, max(abs(s) for s in samples))
    return [s / m * peak for s in samples]


def write(path: str, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    clipped = [max(-1.0, min(1.0, s)) for s in samples]
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(s * 32767)) for s in clipped)
        w.writeframes(frames)


def secs(n: float) -> int:
    return int(SR * n)


def bow():
    n = secs(0.32)
    a = tone(520, n, 0.12, 0.7)
    b = tone(780, n, 0.08, 0.35)
    c = noise(secs(0.04), 3, 0.02, 0.25)
    out = silence(n)
    mix_at(out, a, 0)
    mix_at(out, b, 0, 0.8)
    mix_at(out, c, 0, 0.5)
    return out


def knife():
    n = secs(0.12)
    return lowpass(noise(n, 11, 0.035, 1.0), 3)


def spear():
    n = secs(0.26)
    out = silence(n)
    mix_at(out, tone(96, n, 0.09, 0.9), 0)
    mix_at(out, noise(secs(0.03), 19, 0.012, 0.5), 0)
    return out


def shove():
    n = secs(0.18)
    out = silence(n)
    mix_at(out, tone(150, n, 0.07, 0.75), 0)
    mix_at(out, lowpass(noise(secs(0.06), 23, 0.03, 0.4), 6), 0)
    return out


def throw():
    n = secs(0.3)
    out = silence(n)
    mix_at(out, tone(640, n, 0.12, 0.45, slide=-0.55), 0)
    mix_at(out, lowpass(noise(n, 29, 0.1, 0.35), 8), 0)
    return out


def hit():
    n = secs(0.14)
    out = silence(n)
    mix_at(out, noise(secs(0.04), 31, 0.015, 0.8), 0)
    mix_at(out, tone(220, n, 0.05, 0.55), 0)
    return out


def hurt():
    return tone(140, secs(0.2), 0.07, 0.8)


def knockout():
    n = secs(0.55)
    out = silence(n)
    mix_at(out, tone(523, n, 0.22, 0.45), 0)
    mix_at(out, tone(784, n, 0.16, 0.28), 0)
    return out


def footstep():
    n = secs(0.12)
    body = lowpass(noise(n, 41, 0.04, 0.9), 10)
    thump = tone(78, n, 0.04, 0.7)
    out = silence(n)
    mix_at(out, body, 0)
    mix_at(out, thump, 0, 0.8)
    return out


def pickup():
    out = silence(secs(0.28))
    mix_at(out, tone(660, secs(0.08), 0.04, 0.6), 0)
    mix_at(out, tone(990, secs(0.1), 0.05, 0.5), secs(0.09))
    return out


def interact():
    n = secs(0.12)
    out = silence(n)
    mix_at(out, tone(210, n, 0.04, 0.55), 0)
    mix_at(out, noise(secs(0.025), 53, 0.01, 0.45), 0)
    return out


def ambience():
    n = secs(3.0)
    rng = Rng(71)
    raw = [rng.signed() for _ in range(n)]
    bed = lowpass(raw, 40)
    # Crossfade the join so the loop does not click.
    fade = secs(0.2)
    out = []
    for i, s in enumerate(bed):
        g = 0.22
        if i < fade:
            g *= i / fade
        if i > n - fade:
            g *= (n - i) / fade
        out.append(s * g)
    return out


def veil():
    n = secs(0.42)
    out = []
    for i in range(n):
        t = i / SR
        trem = 0.65 + 0.35 * math.sin(2 * math.pi * 5 * t)
        e = math.exp(-t / 0.18)
        out.append(math.sin(2 * math.pi * 196 * t) * trem * e * 0.45)
    return out


def ui():
    return tone(1400, secs(0.06), 0.02, 0.4)


def snack():
    return lowpass(noise(secs(0.14), 83, 0.04, 0.7), 4)


def win():
    out = silence(secs(0.6))
    mix_at(out, tone(392, secs(0.4), 0.16, 0.35), 0)
    mix_at(out, tone(494, secs(0.4), 0.16, 0.28), secs(0.02))
    mix_at(out, tone(587, secs(0.45), 0.18, 0.22), secs(0.04))
    return out


def token():
    out = silence(secs(0.2))
    mix_at(out, tone(740, secs(0.08), 0.04, 0.4), 0)
    mix_at(out, tone(980, secs(0.1), 0.05, 0.32), secs(0.06))
    return out


def air():
    n = secs(0.28)
    return lowpass(noise(n, 97, 0.1, 0.4), 6)


CUES = {
    "weapon_bow.wav": bow,
    "weapon_knife.wav": knife,
    "weapon_spear.wav": spear,
    "weapon_shove.wav": shove,
    "weapon_throw.wav": throw,
    "hit.wav": hit,
    "hurt.wav": hurt,
    "knockout.wav": knockout,
    "footstep.wav": footstep,
    "pickup.wav": pickup,
    "interact.wav": interact,
    "ambience.wav": ambience,
    "veil.wav": veil,
    "ui.wav": ui,
    "snack.wav": snack,
    "win.wav": win,
    "token.wav": token,
    "air.wav": air,
}


def main():
    rendered = {}
    for name, fn in CUES.items():
        audio = normalize(fn(), 0.55)
        rendered[name] = audio
        write(os.path.join(OUT, name), audio)
        print(f"wrote {name} {len(audio) / SR:.2f}s")

    mix = silence(secs(8.6))
    bed = rendered["ambience.wav"]
    # Loop the bed quietly under the demo.
    for t in range(0, len(mix), len(bed)):
        mix_at(mix, bed, t, 0.35)
    timeline = [
        (0.35, "weapon_bow.wav", 0.9),
        (0.9, "weapon_knife.wav", 0.75),
        (1.35, "weapon_spear.wav", 0.9),
        (1.85, "weapon_shove.wav", 0.7),
        (2.3, "weapon_throw.wav", 0.85),
        (2.9, "hit.wav", 0.8),
        (3.25, "hurt.wav", 0.65),
        (3.7, "knockout.wav", 0.7),
        (4.5, "footstep.wav", 0.7),
        (4.88, "footstep.wav", 0.65),
        (5.22, "footstep.wav", 0.6),
        (5.8, "pickup.wav", 0.75),
        (6.3, "interact.wav", 0.7),
        (6.8, "veil.wav", 0.55),
        (7.5, "win.wav", 0.55),
    ]
    for at, name, gain in timeline:
        mix_at(mix, rendered[name], secs(at), gain)
    mix = normalize(mix, 0.5)
    path = os.path.join(SAMPLE, "daybreak-original-mix.wav")
    write(path, mix)
    peak = max(abs(s) for s in mix)
    print(f"wrote mix {len(mix) / SR:.2f}s peak {peak:.3f}")


if __name__ == "__main__":
    main()
