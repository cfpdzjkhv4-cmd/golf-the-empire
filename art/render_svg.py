#!/usr/bin/env python3
"""Renders the hand made SVG art in art/svg to PNGs, named by manifest id, at @2x and @3x.

SVGs are drawn with headless Chrome or Chromium (set CHROME to its path if it isn't found).
Outputs go to App/Resources/GeneratedAssets, and the app icon to App/Assets.xcassets.
Every id rendered here is listed in art/final_assets.txt so the placeholder generator leaves it alone.

    python3 art/render_svg.py
"""

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG = os.path.join(ROOT, "art", "svg")
OUT = os.path.join(ROOT, "App", "Resources", "GeneratedAssets")
ICON = os.path.join(ROOT, "App", "Assets.xcassets", "AppIcon.appiconset")
FINAL = os.path.join(ROOT, "art", "final_assets.txt")

# file name (without .svg) -> (asset id, width in points, height in points)
ART = {
    "title_hero": ("title_hero", 645, 450),
    "portrait_percy_neutral": ("portrait_percy", 128, 128),
    "portrait_percy_amused": ("portrait_percy_amused", 128, 128),
    "portrait_percy_appalled": ("portrait_percy_appalled", 128, 128),
    "app_icon": ("app_icon", 512, 512),
}

CANDIDATES = [
    os.environ.get("CHROME", ""),
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
    shutil.which("chromium") or "", shutil.which("google-chrome") or "",
]


def chrome():
    for c in CANDIDATES:
        if c and os.path.exists(c):
            return c
    sys.exit("No Chrome or Chromium found. Install Google Chrome, or set CHROME to its path.")


def render(browser, svg_path, width, height, out_path):
    with tempfile.TemporaryDirectory() as tmp:
        page = os.path.join(tmp, "page.html")
        with open(page, "w") as f:
            f.write(f'<!doctype html><body style="margin:0;background:transparent">'
                    f'<img src="file://{svg_path}" width="{width}" height="{height}" style="display:block">')
        shot = os.path.join(tmp, "shot.png")
        subprocess.run([browser, "--headless", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--default-background-color=00000000", f"--window-size={width},{height + 100}",
                        f"--screenshot={shot}", f"file://{page}"], check=True, capture_output=True)
        # Chrome's window includes spare height; crop to the picture.
        subprocess.run(["convert", shot, "-crop", f"{width}x{height}+0+0", "+repage", out_path], check=True)


def main():
    browser = chrome()
    os.makedirs(OUT, exist_ok=True)
    finals = set()
    for name, (asset_id, w, h) in ART.items():
        src = os.path.join(SVG, name + ".svg")
        for scale in (2, 3):
            render(browser, src, w * scale, h * scale, os.path.join(OUT, f"{asset_id}@{scale}x.png"))
        finals.add(asset_id)
        print("rendered", asset_id)
    # App icon: one 1024 square, no transparency.
    os.makedirs(ICON, exist_ok=True)
    icon = os.path.join(ICON, "icon-1024.png")
    render(browser, os.path.join(SVG, "app_icon.svg"), 1024, 1024, icon)
    subprocess.run(["convert", icon, "-background", "white", "-alpha", "remove", "-alpha", "off", icon], check=True)
    with open(os.path.join(ICON, "Contents.json"), "w") as f:
        f.write('{\n  "images" : [\n    { "filename" : "icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }\n  ],\n'
                '  "info" : { "author" : "xcode", "version" : 1 }\n}\n')
    contents = os.path.join(ROOT, "App", "Assets.xcassets", "Contents.json")
    with open(contents, "w") as f:
        f.write('{\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n')
    existing = set()
    if os.path.exists(FINAL):
        with open(FINAL) as f:
            existing = {l.strip() for l in f if l.strip() and not l.startswith("#")}
    with open(FINAL, "w") as f:
        f.write("# Manifest ids whose art is final. The placeholder generator leaves these alone.\n")
        for i in sorted(existing | finals):
            f.write(i + "\n")


if __name__ == "__main__":
    main()
