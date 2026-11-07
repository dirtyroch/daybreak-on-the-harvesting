#!/usr/bin/env python3
"""Synthesize original Daybreak one-shots. No recorded or third-party audio.

These files are the upload set. Until their asset ids are pasted into SfxIds.uploadId,
Studio plays the engine or library stand-in instead, or stays silent for the two beds.
"""
import math
import os
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "samples")


def noise(i, seed):
    x = math.sin(i * 12.9898 + seed * 78.233) * 43758.5453
    return (x - math.floor(x)) * 2.0 - 1.0


def tone(freq, seconds, vol=0.3, slide=0.0, seed=1, noise_mix=0.0, decay=6.0):
    n = int(SR * seconds)
    out = []
    for i in range(n):
        t = i / SR
        attack = min(1.0, t / 0.008)
        f = freq + slide * t
        sample = math.sin(2 * math.pi * f * t)
        if noise_mix:
            sample = sample * (1 - noise_mix) + noise(i, seed) * noise_mix
        sample *= attack * math.exp(-decay * t) * vol
        out.append(sample)
    return out


def mix(*layers):
    n = max(len(layer) for layer in layers)
    out = [0.0] * n
    for layer in layers:
        for i, s in enumerate(layer):
            out[i] += s
    return out


def silence(seconds):
    return [0.0] * int(SR * seconds)


def normalize(samples, peak):
    m = max(1e-8, max(abs(s) for s in samples))
    return [s / m * peak for s in samples]


def write(name, samples, peak):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    data = normalize(samples, peak)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in data)
        w.writeframes(frames)
    return path


CUES = {
    "bow-draw.wav": (mix(tone(220, 0.18, 0.2, slide=900, decay=3.5), tone(330, 0.18, 0.08, slide=700, decay=4)), 0.32),
    "bow-release.wav": (mix(tone(680, 0.16, 0.25, slide=-400, decay=10), tone(240, 0.12, 0.1, decay=8, noise_mix=0.25, seed=2)), 0.34),
    "spear-swing.wav": (tone(180, 0.2, 0.2, slide=-80, noise_mix=0.85, seed=3, decay=7), 0.3),
    "spear-throw.wav": (tone(420, 0.14, 0.2, slide=-260, noise_mix=0.7, seed=4, decay=9), 0.3),
    "knife-swing.wav": (tone(900, 0.08, 0.18, slide=-500, noise_mix=0.8, seed=5, decay=14), 0.28),
    "shove.wav": (tone(90, 0.14, 0.3, decay=8, noise_mix=0.2, seed=6), 0.3),
    "equip.wav": (tone(520, 0.12, 0.16, slide=80, noise_mix=0.45, seed=7, decay=8), 0.26),
    "hit-light.wav": (tone(340, 0.09, 0.28, decay=16), 0.32),
    "hit-heavy.wav": (tone(120, 0.14, 0.3, decay=9), 0.3),
    "hurt.wav": (tone(260, 0.1, 0.22, decay=12), 0.26),
    "knockout.wav": (mix(tone(523, 0.28, 0.16, decay=4), tone(392, 0.36, 0.12, decay=3.2)), 0.28),
    "knock-confirm.wav": (tone(880, 0.08, 0.2, decay=14), 0.26),
    "foot-grass.wav": (tone(140, 0.09, 0.12, noise_mix=0.9, seed=8, decay=12), 0.22),
    "foot-dirt.wav": (tone(90, 0.1, 0.14, noise_mix=0.85, seed=9, decay=10), 0.22),
    "foot-stone.wav": (tone(640, 0.06, 0.22, decay=22, noise_mix=0.35, seed=10), 0.24),
    "foot-wood.wav": (mix(tone(180, 0.09, 0.16, decay=10), tone(360, 0.08, 0.08, decay=12)), 0.24),
    "foot-metal.wav": (tone(1400, 0.05, 0.16, decay=24), 0.2),
    "foot-water.wav": (tone(200, 0.16, 0.12, noise_mix=0.75, seed=11, decay=6), 0.2),
    "foot-glass.wav": (tone(1800, 0.05, 0.12, decay=20), 0.16),
    "foot-default.wav": (tone(220, 0.08, 0.12, noise_mix=0.6, seed=12, decay=12), 0.2),
    "foot-land.wav": (tone(100, 0.12, 0.2, decay=10, noise_mix=0.3, seed=13), 0.24),
    "pickup.wav": (mix(tone(660, 0.09, 0.16, decay=10), tone(990, 0.1, 0.1, decay=9)), 0.26),
    "crate.wav": (tone(160, 0.12, 0.18, noise_mix=0.4, seed=14, decay=9), 0.24),
    "snack.wav": (mix(tone(300, 0.06, 0.1, noise_mix=0.8, seed=15, decay=16), tone(280, 0.12, 0.08, noise_mix=0.8, seed=16, decay=10)), 0.22),
    "token.wav": (mix(tone(988, 0.12, 0.12, decay=8), tone(1318, 0.14, 0.08, decay=7)), 0.24),
    "parachute.wav": (tone(500, 0.22, 0.12, slide=-300, noise_mix=0.7, seed=17, decay=4), 0.22),
    "ui-click.wav": (tone(1400, 0.045, 0.16, decay=30), 0.22),
    "chime.wav": (tone(784, 0.2, 0.14, decay=6), 0.24),
    "win.wav": (mix(tone(523, 0.16, 0.12, decay=5), tone(659, 0.22, 0.1, decay=4), tone(784, 0.3, 0.1, decay=3.5)), 0.24),
    "purchase.wav": (mix(tone(1046, 0.08, 0.12, decay=12), tone(1568, 0.1, 0.08, decay=10)), 0.22),
    "gift.wav": (tone(700, 0.12, 0.12, slide=-200, noise_mix=0.65, seed=18, decay=8), 0.22),
    "cutscene.wav": (mix(tone(392, 0.2, 0.12, decay=4), tone(523, 0.26, 0.1, decay=3.5)), 0.22),
    "arena-air.wav": (tone(180, 0.25, 0.08, noise_mix=0.9, seed=19, decay=3), 0.14),
    "lobby-air.wav": (tone(494, 0.22, 0.08, decay=5), 0.12),
    "ambient-arena.wav": (tone(140, 2.8, 0.05, noise_mix=0.92, seed=21, decay=0.35), 0.12),
    "ambient-lobby.wav": (mix(tone(196, 2.8, 0.05, decay=0.25), tone(247, 2.8, 0.04, decay=0.3)), 0.1),
    "veil-touch.wav": (tone(240, 0.28, 0.1, noise_mix=0.8, seed=22, decay=4), 0.18),
    "veil-warn.wav": (tone(300, 0.36, 0.12, slide=220, decay=3), 0.2),
    "veil-soon.wav": (tone(440, 0.16, 0.1, decay=8), 0.18),
    "veil-core.wav": (tone(660, 0.2, 0.12, decay=6), 0.2),
    "veil-break.wav": (mix(tone(523, 0.22, 0.1, decay=4), tone(784, 0.26, 0.08, decay=3.5)), 0.2),
    "hazard.wav": (tone(110, 0.2, 0.14, decay=6, noise_mix=0.3, seed=23), 0.2),
    "pact-warn.wav": (tone(370, 0.16, 0.14, decay=8), 0.2),
}


def main():
    lines = ["original synthesized samples", "peak is the file peak after normalize", "uploadId in SfxIds stays 0 until these are uploaded", ""]
    for name, (samples, peak) in CUES.items():
        write(name, samples, peak)
        lines.append(f"{name}\t{len(samples) / SR:.3f}s\tpeak {peak:.2f}")
    preview = []
    for name in ("bow-release.wav", "spear-swing.wav", "knife-swing.wav", "hit-light.wav", "knockout.wav", "foot-grass.wav", "foot-stone.wav", "foot-water.wav", "pickup.wav", "veil-warn.wav"):
        preview.extend(CUES[name][0])
        preview.extend(silence(0.12))
    preview_path = os.path.join(os.path.dirname(OUT), "daybreak-mix-preview.wav")
    data = normalize(preview, 0.32)
    with wave.open(preview_path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in data))
    lines.append("")
    lines.append(f"mix preview audio/daybreak-mix-preview.wav {len(data) / SR:.2f}s")
    manifest = os.path.join(os.path.dirname(OUT), "SAMPLES.txt")
    with open(manifest, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {len(CUES)} samples and a mix preview")


if __name__ == "__main__":
    main()
