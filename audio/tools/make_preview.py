#!/usr/bin/env python3
"""Diagram of the first-person hand layout. Labeled PREVIEW, not a Studio capture.

Offsets match src/shared/Logic/Presentation.luau (camera looks down -Z, +X is right).
"""
import os
import struct
import zlib

W, H = 1280, 720
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "marketing")

# 5x7 glyphs. Bits are row-major, 5 wide.
FONT = {
    " ": [0, 0, 0, 0, 0, 0, 0],
    "A": [0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
    "B": [0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110],
    "C": [0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110],
    "D": [0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110],
    "E": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111],
    "F": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000],
    "G": [0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110],
    "H": [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
    "I": [0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
    "K": [0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001],
    "L": [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111],
    "M": [0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001],
    "N": [0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001],
    "O": [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
    "P": [0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000],
    "R": [0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001],
    "S": [0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110],
    "T": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100],
    "U": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
    "V": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100],
    "W": [0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b11011, 0b10001],
    "X": [0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001],
    "Y": [0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100],
    "0": [0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110],
    "1": [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
    "7": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000],
    "-": [0, 0, 0, 0b01110, 0, 0, 0],
    ".": [0, 0, 0, 0, 0, 0b00100, 0b00100],
    ":": [0, 0b00100, 0b00100, 0, 0b00100, 0b00100, 0],
    ",": [0, 0, 0, 0, 0b00100, 0b00100, 0b01000],
}


def put(px, x, y, rgb):
    if 0 <= x < W and 0 <= y < H:
        i = (y * W + x) * 3
        px[i : i + 3] = bytes(rgb)


def fill_rect(px, x0, y0, x1, y1, rgb):
    for y in range(int(y0), int(y1)):
        for x in range(int(x0), int(x1)):
            put(px, x, y, rgb)


def text(px, x, y, msg, scale, rgb):
    cx = x
    for ch in msg.upper():
        glyph = FONT.get(ch, FONT[" "])
        for row, bits in enumerate(glyph):
            for col in range(5):
                if bits & (1 << (4 - col)):
                    fill_rect(px, cx + col * scale, y + row * scale, cx + (col + 1) * scale, y + (row + 1) * scale, rgb)
        cx += 6 * scale


def project(x, y, z):
    # Camera at origin looking down -Z. Simple perspective.
    depth = max(0.4, -z)
    s = 280 / depth
    return int(W * 0.5 + x * s), int(H * 0.48 - y * s)


def box(px, x, y, z, sx, sy, sz, rgb):
    corners = []
    for dx in (-sx / 2, sx / 2):
        for dy in (-sy / 2, sy / 2):
            for dz in (-sz / 2, sz / 2):
                corners.append(project(x + dx, y + dy, z + dz))
    xs = [c[0] for c in corners]
    ys = [c[1] for c in corners]
    fill_rect(px, min(xs), min(ys), max(xs), max(ys), rgb)


def sky(px):
    top = (28, 31, 43)
    mid = (196, 154, 110)
    ground = (90, 104, 72)
    for y in range(H):
        t = y / H
        if t < 0.62:
            u = t / 0.62
            rgb = tuple(int(top[i] * (1 - u) + mid[i] * u) for i in range(3))
        else:
            u = (t - 0.62) / 0.38
            rgb = tuple(int(mid[i] * (1 - u) + ground[i] * u) for i in range(3))
        for x in range(W):
            put(px, x, y, rgb)


def preview():
    px = bytearray(W * H * 3)
    sky(px)
    # Horizon band.
    fill_rect(px, 0, 430, W, 434, (212, 167, 44))
    # Arms and a bow, from Presentation offsets. Lower right, off the reticle.
    skin = (196, 146, 114)
    wood = (122, 78, 42)
    string = (237, 230, 214)
    arms = [
        (0.55, -0.38, -1.15, 0.26, 0.62, 0.26),
        (0.22, -0.48, -1.25, 0.26, 0.62, 0.26),
        (0.62, -0.46, -1.4, 0.22, 0.2, 0.24),
        (0.28, -0.55, -1.45, 0.22, 0.2, 0.24),
    ]
    for a in arms:
        box(px, *a, skin)
    # Bow grip sits at (0.72, -0.55, -1.9), scaled. Drawn as a simple limb, not a copy of a prop.
    box(px, 0.72, -0.35, -1.9, 0.08, 0.7, 0.08, wood)
    box(px, 0.72, -0.75, -1.9, 0.08, 0.55, 0.08, wood)
    box(px, 0.78, -0.55, -1.75, 0.02, 0.9, 0.02, string)
    # Reticle: small ring and dot at the optical center. Unobtrusive.
    cx, cy = W // 2, H // 2
    for y in range(cy - 12, cy + 13):
        for x in range(cx - 12, cx + 13):
            d = (x - cx) ** 2 + (y - cy) ** 2
            if 11 * 11 <= d <= 14 * 14:
                put(px, x, y, (244, 239, 230))
    fill_rect(px, cx - 1, cy - 1, cx + 2, cy + 2, (212, 167, 44))
    # Labels. This frame is a diagram.
    fill_rect(px, 24, 24, 430, 78, (22, 25, 36))
    text(px, 36, 36, "PREVIEW", 4, (212, 167, 44))
    text(px, 36, 640, "NOT A STUDIO CAPTURE", 3, (244, 239, 230))
    text(px, 36, 672, "HANDS AND BOW FROM VIEW OFFSETS. FOV 70.", 2, (232, 220, 196))
    return px


def studio_card():
    px = bytearray(W * H * 3)
    for i in range(0, len(px), 3):
        px[i : i + 3] = bytes((22, 25, 36))
    fill_rect(px, 80, 70, 1200, 650, (35, 40, 58))
    text(px, 110, 100, "STUDIO", 6, (212, 167, 44))
    text(px, 110, 160, "NOT CAPTURED", 4, (244, 239, 230))
    lines = [
        "THIS IMAGE IS A CHECKLIST, NOT THE GAME.",
        "OPEN THE RBXLX IN STUDIO AND PRESS PLAY.",
        "ENTER A MATCH. PRESS V OR THE VIEW BUTTON.",
        "CONFIRM HANDS, WEAPON, AND NO HEAD IN THE LENS.",
        "FOV STAYS AT 70 OR NARROWER.",
        "HITS STILL COME FROM THE CHARACTER.",
    ]
    y = 250
    for line in lines:
        text(px, 110, y, line, 2, (232, 220, 196))
        y += 48
    return px


def write_png(path, px):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    rows = []
    for y in range(H):
        rows.append(b"\x00" + bytes(px[y * W * 3 : (y + 1) * W * 3]))
    ihdr = struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)
    print("wrote", path, len(png))


def main():
    write_png(os.path.join(OUT, "fp-view-preview.png"), preview())
    write_png(os.path.join(OUT, "fp-studio-not-captured.png"), studio_card())


if __name__ == "__main__":
    main()
