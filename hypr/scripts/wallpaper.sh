#!/usr/bin/env bash
# wallpaper.sh — switch wallpaper with awww + smart matugen color sync

WALLDIR="$HOME/Pictures/Wallpapers"
CURRENT_FILE="$HOME/.cache/wallpaper-colors/current"
COLORS_JSON="$HOME/.cache/wal/colors.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    WAYLAND_DISPLAY="$(
        find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' ! -name '*awww*' 2>/dev/null \
            | xargs -r -n1 basename \
            | sort \
            | head -n1
    )"
    [ -n "$WAYLAND_DISPLAY" ] && export WAYLAND_DISPLAY
fi

export XDG_RUNTIME_DIR

mkdir -p "$(dirname "$CURRENT_FILE")" "$HOME/.cache/wal"

mapfile -t WALLS < <(find "$WALLDIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | sort)
[ ${#WALLS[@]} -eq 0 ] && exit 1

pick_wallpaper() {
    local current=""; [ -f "$CURRENT_FILE" ] && current=$(cat "$CURRENT_FILE")
    case "${1:-}" in
        --next) local idx=0; for i in "${!WALLS[@]}"; do [ "${WALLS[$i]}" = "$current" ] && idx=$((i+1)) && break; done
                [ $idx -ge ${#WALLS[@]} ] && idx=0; echo "${WALLS[$idx]}" ;;
        --prev) local idx=$((${#WALLS[@]}-1)); for i in "${!WALLS[@]}"; do [ "${WALLS[$i]}" = "$current" ] && idx=$((i-1)) && break; done
                [ $idx -lt 0 ] && idx=$((${#WALLS[@]}-1)); echo "${WALLS[$idx]}" ;;
        "") local pick="$current" n=0; while [ "$pick" = "$current" ] && [ $n -lt 20 ]; do
                pick="${WALLS[$((RANDOM % ${#WALLS[@]}))]}"; n=$((n+1)); done; echo "$pick" ;;
        *) echo "$1" ;;
    esac
}

WALLPAPER=$(pick_wallpaper "$1")
[ ! -f "$WALLPAPER" ] && exit 1
echo "$WALLPAPER" > "$CURRENT_FILE"

# awww
if ! awww query >/dev/null 2>&1; then
    pkill -x awww-daemon >/dev/null 2>&1 || true
    awww-daemon >/dev/null 2>&1 &
    sleep 0.5
    if ! awww query >/dev/null 2>&1; then
        echo "awww daemon is not reachable on ${WAYLAND_DISPLAY:-unknown-display}" >&2
        exit 1
    fi
fi
resize_mode="crop"

if ! awww img "$WALLPAPER" --resize "$resize_mode" --transition-type grow --transition-pos 0.5,0.9 --transition-duration 2 --transition-fps 60; then
    echo "Failed to apply wallpaper with awww" >&2
    exit 1
fi

# Generate colors (smart matugen - picks best preference per wallpaper)
python3 "$SCRIPT_DIR/matugen-smart.py" "$WALLPAPER"

# Regenerate Pywal-compatible outputs from the same palette. This keeps Kitty,
# legacy Rofi themes, shell colors, and other Pywal consumers in sync.
if command -v wal >/dev/null 2>&1; then
    wal --theme "$COLORS_JSON" -n >/dev/null 2>&1 || true
fi

python3 "$SCRIPT_DIR/rofi-wallpaper-theme.py" "$WALLPAPER" >/dev/null 2>&1 || true

# Keep Cava on the same primary -> accent gradient as the Hyprland border.
if python3 "$SCRIPT_DIR/cava-wallpaper-theme.py" >/dev/null 2>&1; then
    pkill -USR2 -x cava 2>/dev/null || true
fi

# Generate Luminary quickshell bar colors
python3 "$SCRIPT_DIR/qs-matugen-colors.py" "$WALLPAPER" &>/dev/null &

# Keep Obsidian's Live Background and Matugen palette in sync.
OBSIDIAN_SYNC="$HOME/obsidian-vault/.obsidian/desktop-wallpaper/sync.py"
[ -x "$OBSIDIAN_SYNC" ] && "$OBSIDIAN_SYNC" "$WALLPAPER" "$WALLPAPER" image &>/dev/null &

# Derive quickshell bar theme from updated wal colors
python3 "$HOME/.config/quickshell/bar/derive-theme.py" &>/dev/null &

# Update hyprland borders
eval "$(python3 -c "
import json
d = json.load(open('$COLORS_JSON'))
c = d['colors']
print(f'C4={c[\"color4\"].lstrip(\"#\")}')
print(f'C5={c[\"color6\"].lstrip(\"#\")}')
print(f'C8={c[\"color1\"].lstrip(\"#\")}')
")"
GRAPHICS_CONF="$HOME/.config/hypr/modules/looknfeel.conf"
if [ -n "$C4" ] && [ -f "$GRAPHICS_CONF" ]; then
    sed -i \
        -e "s/col\.active_border = .*/col.active_border = rgba(${C4}ee) rgba(${C5}ee) 45deg/" \
        -e "s/col\.inactive_border = .*/col.inactive_border = rgba(${C8}aa)/" \
        "$GRAPHICS_CONF"
    hyprctl reload 2>/dev/null
fi

# Sync Tauon theme
bash ~/tauon/sync-theme.sh 2>/dev/null

# Sync swaync colors
bash "$SCRIPT_DIR/swaync-colors.sh" 2>/dev/null
echo "Wallpaper: $(basename "$WALLPAPER")"
