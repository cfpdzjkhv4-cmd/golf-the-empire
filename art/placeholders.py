#!/usr/bin/env python3
"""Placeholder generator: one image per manifest id, plus the asset index.

Reads docs/assets_manifest.csv and writes into App/Resources/GeneratedAssets/:
  * <id>@2x.png and <id>@3x.png for every image asset, coloured by category,
    so the game and the asset gallery have something real to load by id;
  * asset_index.json, which the app's AssetLibrary reads. It lists every
    manifest entry and whether it is still a placeholder, final, or missing.

Real generators (Milestone 2 onwards) write final art under the same ids and
mark it final in art/final_assets.txt; this script then leaves those files alone.

Standard library only, so it runs on any Mac with Xcode installed:
    python3 art/placeholders.py      (or: make assets)
"""

import csv
import hashlib
import json
import os
import re
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "docs", "assets_manifest.csv")
OUT = os.path.join(ROOT, "App", "Resources", "GeneratedAssets")
FINAL_LIST = os.path.join(ROOT, "art", "final_assets.txt")
AUDIO = os.path.join(ROOT, "App", "Resources", "GeneratedAudio")

# Placeholders are capped at this many pixels on the longest side.
MAX_PIXELS = 1024

CATEGORY_COLOURS = {
    "Terrain": (122, 168, 84),
    "Vegetation": (61, 105, 58),
    "Characters": (196, 120, 82),
    "Buildings": (176, 150, 120),
    "Event dressing": (201, 151, 26),
    "Props": (230, 216, 170),
    "Effects": (110, 160, 200),
    "Map": (90, 120, 150),
    "UI": (40, 62, 90),
    "Portraits": (150, 110, 150),
    "Marketing": (120, 120, 120),
}


def png(width, height, pixel):
    """Encodes an RGBA image; pixel(x, y) returns (r, g, b, a)."""
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            rows.extend(pixel(x, y))

    def chunk(kind, body):
        c = struct.pack(">I", len(body)) + kind + body
        return c + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))


def placeholder(asset_id, category, w, h):
    base = CATEGORY_COLOURS.get(category, (128, 128, 128))
    digest = hashlib.sha1(asset_id.encode()).digest()
    accent = (digest[0], digest[1], digest[2])
    border = max(2, min(w, h) // 24)
    stripe = max(4, min(w, h) // 8)
    dark = tuple(int(c * 0.6) for c in base)
    light = tuple(min(255, int(c * 1.15) + 12) for c in base)
    tab = max(4, min(w, h) // 4)

    def pixel(x, y):
        if x < border or y < border or x >= w - border or y >= h - border:
            return (*dark, 255)
        if x < tab and y < tab:
            return (*accent, 255)
        return (*(light if ((x + y) // stripe) % 2 else base), 255)

    return png(w, h, pixel)


def parse_size(text):
    m = re.match(r"^(\d+)x(\d+)$", text.strip())
    return (int(m.group(1)), int(m.group(2))) if m else None


def kind_of(row):
    if row["source"].strip() == "Cut":
        return "cut"
    if row["category"].startswith("Audio"):
        return "audio"
    if row["category"] == "Marketing":
        return "capture"
    return "image"


def main():
    os.makedirs(OUT, exist_ok=True)
    final = set()
    if os.path.exists(FINAL_LIST):
        with open(FINAL_LIST) as f:
            final = {line.strip() for line in f if line.strip() and not line.startswith("#")}

    index = []
    made = 0
    with open(MANIFEST, newline="") as f:
        for row in csv.DictReader(f):
            asset_id = row["id"].strip()
            kind = kind_of(row)
            size = parse_size(row["size_pt"]) or ((128, 128) if kind == "image" else None)
            entry = {
                "id": asset_id,
                "category": row["category"],
                "description": row["description"],
                "sizePt": row["size_pt"],
                "frames": row["frames"],
                "variants": row["variants"],
                "format": row["format"],
                "priority": row["priority"],
                "source": row["source"],
                "notes": row["notes"],
                "kind": kind,
            }
            if kind == "image":
                entry["status"] = "final" if asset_id in final else "placeholder"
                if asset_id not in final:
                    for scale in (2, 3):
                        w, h = size[0] * scale, size[1] * scale
                        shrink = min(1.0, MAX_PIXELS / max(w, h))
                        w, h = max(8, int(w * shrink)), max(8, int(h * shrink))
                        with open(os.path.join(OUT, f"{asset_id}@{scale}x.png"), "wb") as out:
                            out.write(placeholder(asset_id, row["category"], w, h))
                    made += 1
            elif kind == "audio":
                made_audio = os.path.exists(os.path.join(AUDIO, asset_id + ".wav"))
                entry["status"] = "final" if made_audio else "missing"
            else:
                entry["status"] = "cut" if kind == "cut" else "missing"
            index.append(entry)

    with open(os.path.join(OUT, "asset_index.json"), "w") as f:
        json.dump({"generated": "art/placeholders.py", "assets": index}, f, indent=1)
        f.write("\n")
    print(f"{len(index)} manifest entries, {made} placeholder images written to {os.path.relpath(OUT, ROOT)}")


if __name__ == "__main__":
    main()
