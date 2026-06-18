#!/usr/bin/env python3
"""
Run matugen with multiple preferences, pick the result whose primary
best represents the dominant hue of the image.
Outputs colors.json to ~/.cache/wal/colors.json
"""

import json
import re
import subprocess
import sys
from colorsys import rgb_to_hls
from pathlib import Path
from PIL import Image
import numpy as np

COLORS_JSON = Path.home() / ".cache" / "wal" / "colors.json"


def get_dominant_hue(image_path: str) -> float:
    """Get the dominant hue of the image by sampling pixels."""
    img = Image.open(image_path).convert("RGB")
    img = img.resize((100, 100), Image.LANCZOS)
    pixels = np.array(img).reshape(-1, 3)

    # Filter out very dark and very light pixels
    brightness = pixels.sum(axis=1) / 3
    mask = (brightness > 30) & (brightness < 220)
    filtered = pixels[mask]
    if len(filtered) < 50:
        filtered = pixels

    # Get hue + saturation for each pixel, weight by saturation
    hues = []
    weights = []
    for r, g, b in filtered[::3]:  # sample every 3rd for speed
        h, l, s = rgb_to_hls(r / 255, g / 255, b / 255)
        if s > 0.15:  # skip greys
            hues.append(h)
            weights.append(s * (0.5 + l))  # weight by saturation and brightness

    if not hues:
        return 0.6  # default blue-ish

    # Weighted circular mean of hues
    sin_sum = sum(w * np.sin(2 * np.pi * h) for h, w in zip(hues, weights))
    cos_sum = sum(w * np.cos(2 * np.pi * h) for h, w in zip(hues, weights))
    dominant_hue = (np.arctan2(sin_sum, cos_sum) / (2 * np.pi)) % 1.0
    return dominant_hue


def run_matugen(image_path: str, prefer: str) -> dict:
    """Run matugen and extract dark scheme colors."""
    try:
        result = subprocess.run(
            ["matugen", "-t", "scheme-content", "image", image_path,
             "--json", "hex", "--prefer", prefer],
            capture_output=True, text=True, timeout=15
        )
        raw = result.stdout
        colors = {}
        for m in re.finditer(
            r'"(\w+)":\s*\{[^}]*"dark":\s*\{[^}]*"color":\s*"(#[0-9a-fA-F]{6})"', raw
        ):
            colors[m.group(1)] = m.group(2)
        return colors
    except Exception:
        return {}


def hex_to_hue(hex_color: str) -> float:
    r = int(hex_color[1:3], 16) / 255
    g = int(hex_color[3:5], 16) / 255
    b = int(hex_color[5:7], 16) / 255
    h, l, s = rgb_to_hls(r, g, b)
    return h


def hue_distance(h1: float, h2: float) -> float:
    d = abs(h1 - h2)
    return min(d, 1 - d)


def build_palette(colors: dict) -> dict:
    return {
        "special": {
            "background": colors.get("surface", "#111318"),
            "foreground": colors.get("on_surface", "#e1e2e9"),
            "cursor": colors.get("on_surface", "#e1e2e9"),
        },
        "colors": {
            "color0": colors.get("surface", "#111318"),
            "color1": colors.get("primary_container", "#5093e3"),
            "color2": colors.get("secondary_container", "#3c4758"),
            "color3": colors.get("tertiary_container", "#9f5db1"),
            "color4": colors.get("primary_container", "#5093e3"),
            "color5": colors.get("tertiary_container", "#9f5db1"),
            "color6": colors.get("tertiary", "#d9bde3"),
            "color7": colors.get("on_surface", "#e1e2e9"),
            "color8": colors.get("on_surface_variant", "#c1c7ce"),
            "color9": colors.get("primary", "#a3c9ff"),
            "color10": colors.get("secondary", "#bcc7db"),
            "color11": colors.get("tertiary", "#d9bde3"),
            "color12": colors.get("primary_container", "#5093e3"),
            "color13": colors.get("tertiary_container", "#9f5db1"),
            "color14": colors.get("on_primary_container", "#d2e4ff"),
            "color15": colors.get("on_surface", "#e1e2e9"),
        },
    }


def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    import hashlib
    image_path = sys.argv[1]
    COLORS_JSON.parent.mkdir(parents=True, exist_ok=True)

    # Check cache
    cache_dir = Path.home() / ".cache" / "matugen-smart"
    cache_dir.mkdir(parents=True, exist_ok=True)
    with open(image_path, "rb") as f:
        img_hash = hashlib.md5(f.read(8192)).hexdigest()[:10]
    cache_file = cache_dir / f"{img_hash}.json"

    if cache_file.exists():
        palette = json.loads(cache_file.read_text())
        COLORS_JSON.write_text(json.dumps(palette, indent=4))
        c = palette["colors"]
        print(f"primary={c['color4']} accent={c['color6']}")
        sys.exit(0)

    # Get dominant hue of image
    dominant = get_dominant_hue(image_path)

    # Run both preferences in parallel
    import concurrent.futures
    best_colors = None
    best_dist = 999

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = {pool.submit(run_matugen, image_path, p): p for p in ["saturation", "lightness"]}
        for future in concurrent.futures.as_completed(futures):
            colors = future.result()
            if not colors:
                continue
            pc = colors.get("primary_container", "")
            if not pc:
                continue
            pc_hue = hex_to_hue(pc)
            dist = hue_distance(pc_hue, dominant)
            if dist < best_dist:
                best_dist = dist
                best_colors = colors

    if not best_colors:
        print("matugen failed", file=sys.stderr)
        sys.exit(1)

    palette = build_palette(best_colors)
    COLORS_JSON.write_text(json.dumps(palette, indent=4))
    cache_file.write_text(json.dumps(palette, indent=4))

    c = palette["colors"]
    print(f"primary={c['color4']} accent={c['color6']}")


if __name__ == "__main__":
    main()
