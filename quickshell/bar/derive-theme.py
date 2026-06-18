#!/usr/bin/env python3
"""
Derive quickshell bar palette from matugen's Material Design 3 dark scheme.
Reads current wallpaper from ~/.cache/wallpaper-colors/current,
runs matugen (with caching), and maps MD3 color roles to bar palette.
Only cool hues (blues, purples, cyans, greens) are used for accents.
"""

import sys, json, os, hashlib, subprocess, colorsys
from pathlib import Path

CURRENT_WP  = Path.home() / ".cache" / "wallpaper-colors" / "current"
CACHE_DIR   = Path.home() / ".cache" / "quickshell" / "matugen-md3"
OUT_PATH    = Path.home() / ".cache" / "quickshell" / "bar-theme.json"

# Hue ranges 0-1 that are considered warm (red, orange, yellow, pink/rose)
# Cool range is roughly 0.17 – 0.83 (yellow-green through violet)
WARM_LOW  = 0.17   # below this = red/orange/yellow
WARM_HIGH = 0.83   # above this = pink/rose/red-magenta


def hue_of(hex_c: str) -> float:
    r = int(hex_c[1:3], 16) / 255
    g = int(hex_c[3:5], 16) / 255
    b = int(hex_c[5:7], 16) / 255
    h, _l, _s = colorsys.rgb_to_hls(r, g, b)
    return h


def is_cool(hex_c: str) -> bool:
    h = hue_of(hex_c)
    return WARM_LOW <= h <= WARM_HIGH


def run_matugen(wallpaper: str) -> dict:
    """Run matugen and return dark-scheme MD3 colors keyed by role name."""
    result = subprocess.run(
        ["matugen", "--prefer", "lightness", "image", wallpaper, "--json", "hex"],
        capture_output=True, text=True, timeout=25,
    )
    data = json.loads(result.stdout)
    dark = {}
    for role, schemes in data.get("colors", {}).items():
        color = schemes.get("dark", {}).get("color")
        if color:
            dark[role] = color
    return dark


def g(colors: dict, *keys: str, fallback: str = "#888888") -> str:
    """Return first available key value from colors dict."""
    for k in keys:
        if k in colors:
            return colors[k]
    return fallback


def g_cool(colors: dict, *keys: str, fallback: str = "#888888") -> str:
    """Return first cool (non-warm) color from keys, then any cool color."""
    for k in keys:
        v = colors.get(k)
        if v and is_cool(v):
            return v
    # None of the preferred keys were cool — scan all roles for any cool color
    # Prefer vibrant roles over surface roles
    for role in ["primary", "secondary", "tertiary", "inverse_primary",
                 "primary_fixed", "secondary_fixed", "tertiary_fixed",
                 "primary_container", "secondary_container", "tertiary_container"]:
        v = colors.get(role)
        if v and is_cool(v):
            return v
    return fallback


def derive(c: dict) -> dict:
    """Map MD3 roles to bar palette semantics."""

    # Accents: pick cool colors only, with fallback scan if needed
    accent = g_cool(c, "primary", "secondary", "inverse_primary",
                    fallback="#7c8ef0")

    # Secondary accent: cool, and prefer a different hue from accent
    accent_h = hue_of(accent)
    blue = fallback_blue = "#5ba8d4"
    for role in ["tertiary", "secondary", "primary_fixed_dim",
                 "secondary_fixed", "tertiary_fixed"]:
        v = c.get(role)
        if v and is_cool(v) and abs(hue_of(v) - accent_h) > 0.04:
            blue = v
            break
    else:
        blue = g_cool(c, "tertiary", "secondary", fallback=fallback_blue)

    return {
        "cBg":     g(c, "surface_container_lowest", "surface",           fallback="#080c12"),
        "cPill":   g(c, "surface_container_low",    "surface_container", fallback="#0e1828"),
        "cBord":   g(c, "outline_variant",          "outline",           fallback="#1d3450"),
        "cFg":     g(c, "on_surface_variant",                            fallback="#8ba4bc"),
        "cBtnFg":  g(c, "on_surface",                                    fallback="#d8e6f2"),
        "cDim":    g(c, "outline",                  "surface_variant",   fallback="#415a75"),
        "cAccent": accent,
        "cBlue":   blue,
    }


def main():
    if not CURRENT_WP.exists():
        sys.exit(0)

    wallpaper = CURRENT_WP.read_text().strip()
    if not wallpaper or not os.path.exists(wallpaper):
        sys.exit(0)

    wp_hash = hashlib.md5(wallpaper.encode()).hexdigest()[:14]
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_file = CACHE_DIR / f"{wp_hash}.json"

    if cache_file.exists():
        raw = json.loads(cache_file.read_text())
    else:
        raw = run_matugen(wallpaper)
        if not raw:
            sys.exit(1)
        cache_file.write_text(json.dumps(raw))

    theme = derive(raw)
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(json.dumps(theme, indent=2))
    print(json.dumps(theme), flush=True)


if __name__ == "__main__":
    main()
