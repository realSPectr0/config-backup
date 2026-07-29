#!/usr/bin/env python3
"""
Generate the shared Luminary/Whitewashed palette by mapping matugen's
Material You roles to the catppuccin-style names used by both bars.
"""

import json
import subprocess
import sys
from pathlib import Path

WALLPAPER_CACHE = Path.home() / ".cache" / "wallpaper-colors" / "current"
OUTPUT = Path("/tmp/qs_colors.json")
WAYBAR_OUTPUT = Path.home() / ".config" / "waybar" / "whitewashed-colors.css"

FALLBACK = {
    "base":     "#1e1e2e", "mantle":   "#181825", "crust":    "#11111b",
    "text":     "#cdd6f4", "subtext1": "#bac2de", "subtext0": "#a6adc8",
    "surface2": "#585b70", "surface1": "#45475a", "surface0": "#313244",
    "overlay2": "#9399b2", "overlay1": "#7f849c", "overlay0": "#6c7086",
    "blue":     "#89b4fa", "sapphire": "#74c7ec", "mauve":    "#cba6f7",
    "pink":     "#f5c2e7", "peach":    "#fab387", "green":    "#a6e3a1",
    "red":      "#f38ba8", "maroon":   "#eba0ac", "yellow":   "#f9e2af",
    "teal":     "#94e2d5",
}


def run_matugen(image_path: str) -> dict:
    try:
        result = subprocess.run(
            ["matugen", "-t", "scheme-content", "image", image_path,
             "--json", "hex", "--prefer", "saturation"],
            capture_output=True, text=True, timeout=20,
        )
        data = json.loads(result.stdout)
        # Extract dark scheme colors from the 'colors' key
        raw = data.get("colors", {})
        return {k: v["dark"]["color"] for k, v in raw.items() if "dark" in v}
    except Exception as e:
        print(f"matugen error: {e}", file=sys.stderr)
        return {}


def get(c: dict, *keys: str, fallback: str = "#000000") -> str:
    for k in keys:
        if k in c:
            return c[k]
    return fallback


def grayscale(hex_color: str) -> str:
    value = hex_color.lstrip("#")
    red, green, blue = (int(value[index:index + 2], 16) for index in (0, 2, 4))
    level = round(0.2126 * red + 0.7152 * green + 0.0722 * blue)
    return f"#{level:02x}{level:02x}{level:02x}"


def is_monochrome(image_path: str) -> bool:
    try:
        result = subprocess.run(
            [
                "magick", image_path, "-resize", "96x96",
                "-colorspace", "HSL", "-channel", "G", "-separate",
                "-format", "%[fx:mean]", "info:",
            ],
            capture_output=True, text=True, timeout=15, check=True,
        )
        return float(result.stdout.strip()) < 0.08
    except (FileNotFoundError, subprocess.SubprocessError, ValueError):
        return False


def build_palette(c: dict, monochrome: bool = False) -> dict:
    palette = {
        "base":     get(c, "background",                fallback=FALLBACK["base"]),
        "mantle":   get(c, "surface",                   fallback=FALLBACK["mantle"]),
        "crust":    get(c, "surface_container_lowest",
                            "surface_container_low",    fallback=FALLBACK["crust"]),
        "text":     get(c, "on_background",             fallback=FALLBACK["text"]),
        "subtext1": get(c, "on_surface",                fallback=FALLBACK["subtext1"]),
        "subtext0": get(c, "on_surface_variant",        fallback=FALLBACK["subtext0"]),
        "surface2": get(c, "surface_container_highest", fallback=FALLBACK["surface2"]),
        "surface1": get(c, "surface_container_high",    fallback=FALLBACK["surface1"]),
        "surface0": get(c, "surface_container",         fallback=FALLBACK["surface0"]),
        "overlay2": get(c, "outline",                   fallback=FALLBACK["overlay2"]),
        "overlay1": get(c, "outline_variant",           fallback=FALLBACK["overlay1"]),
        "overlay0": get(c, "surface_variant",           fallback=FALLBACK["overlay0"]),
        "blue":     get(c, "primary",                   fallback=FALLBACK["blue"]),
        "sapphire": get(c, "inverse_primary",           fallback=FALLBACK["sapphire"]),
        "mauve":    get(c, "tertiary",                  fallback=FALLBACK["mauve"]),
        "pink":     get(c, "on_tertiary_container",     fallback=FALLBACK["pink"]),
        "peach":    get(c, "secondary",                 fallback=FALLBACK["peach"]),
        "green":    get(c, "secondary_container",       fallback=FALLBACK["green"]),
        "red":      get(c, "error",                     fallback=FALLBACK["red"]),
        "maroon":   get(c, "error_container",           fallback=FALLBACK["maroon"]),
        "yellow":   get(c, "tertiary_container",        fallback=FALLBACK["yellow"]),
        "teal":     get(c, "on_primary_container",      fallback=FALLBACK["teal"]),
    }
    if monochrome:
        palette = {name: grayscale(value) for name, value in palette.items()}
        palette.update({
            "blue": palette["text"],
            "sapphire": palette["overlay2"],
            "mauve": palette["text"],
            "pink": palette["subtext1"],
            "peach": palette["subtext0"],
            "green": palette["overlay1"],
            "red": palette["text"],
            "maroon": palette["surface2"],
            "yellow": palette["overlay2"],
            "teal": palette["text"],
        })
    return palette


def write_waybar_palette(palette: dict) -> None:
    lines = [
        "/* Generated by ~/.config/hypr/scripts/qs-matugen-colors.py */",
        "/* Shared by Luminary and the Whitewashed Waybar theme. */",
    ]
    for name, value in palette.items():
        lines.append(f"@define-color lum_{name} {value};")
    lines.append("")

    temp = WAYBAR_OUTPUT.with_suffix(".css.tmp")
    temp.write_text("\n".join(lines))
    temp.replace(WAYBAR_OUTPUT)


def main():
    if len(sys.argv) > 1:
        wallpaper = sys.argv[1]
    elif WALLPAPER_CACHE.exists():
        wallpaper = WALLPAPER_CACHE.read_text().strip()
    else:
        print("No wallpaper found", file=sys.stderr)
        sys.exit(1)

    if not Path(wallpaper).exists():
        print(f"Wallpaper not found: {wallpaper}", file=sys.stderr)
        sys.exit(1)

    monochrome = is_monochrome(wallpaper)
    c = run_matugen(wallpaper)
    palette = build_palette(c, monochrome)

    OUTPUT.write_text(json.dumps(palette, indent=2))
    write_waybar_palette(palette)
    mode = "monochrome" if monochrome else "color"
    print(
        f"qs_colors: mode={mode} base={palette['base']} "
        f"blue={palette['blue']} mauve={palette['mauve']}"
    )


if __name__ == "__main__":
    main()
