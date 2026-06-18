#!/usr/bin/env bash
set -euo pipefail

WALLDIR="${WALLDIR:-$HOME/Documents/.dw}"
THEME="${THEME:-$HOME/.config/rofi/wallpaper-picker.rasi}"
THUMBDIR="${THUMBDIR:-$HOME/.cache/rofi-wallpaper-thumbs}"
CURRENT_FILE="${CURRENT_FILE:-$HOME/.cache/wallpaper-colors/current}"
THUMB_SIZE="${THUMB_SIZE:-240}"
APPLY_SCRIPT="${APPLY_SCRIPT:-$HOME/.config/hypr/scripts/wallpaper.sh}"
THEME_SYNC="$HOME/.config/hypr/scripts/rofi-wallpaper-theme.py"

if [ -x "$THEME_SYNC" ]; then
  python3 "$THEME_SYNC" >/dev/null 2>&1 || true
fi

if [ ! -d "$WALLDIR" ]; then
  rofi -e "Wallpaper directory not found: $WALLDIR"
  exit 1
fi

mapfile -t SUBDIRS < <(find "$WALLDIR" -mindepth 1 -maxdepth 1 -type d ! -name '.git' | sort)

FOLDER_LABELS=("Root")
FOLDER_PATHS=("$WALLDIR")
if [ ${#SUBDIRS[@]} -gt 0 ]; then
  for d in "${SUBDIRS[@]}"; do
    FOLDER_LABELS+=("$(basename "$d")")
    FOLDER_PATHS+=("$d")
  done
fi

folder_idx="$(
  printf '%s\n' "${FOLDER_LABELS[@]}" | rofi -dmenu -format i -i -no-custom -theme "$THEME" -p "Folder"
)"

if [ -z "${folder_idx:-}" ] || [ "$folder_idx" = "-1" ]; then
  exit 0
fi

if [ "$folder_idx" -lt 0 ] || [ "$folder_idx" -ge "${#FOLDER_PATHS[@]}" ]; then
  exit 1
fi

folder="${FOLDER_PATHS[$folder_idx]}"

mapfile -t WALLS < <(
  find "$folder" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | sort
)

if [ ${#WALLS[@]} -eq 0 ]; then
  rofi -e "No wallpapers found in $folder"
  exit 1
fi

mkdir -p "$THUMBDIR"

make_entry() {
  local path="$1"
  local name icon hash thumb
  name="$(basename "$path")"
  icon="$path"

  if command -v magick >/dev/null 2>&1; then
    hash="$(printf '%s' "$path" | md5sum | cut -d' ' -f1)"
    thumb="$THUMBDIR/${hash}_${THUMB_SIZE}.jpg"
    if [ ! -f "$thumb" ] || [ "$path" -nt "$thumb" ]; then
      magick "$path" \
        -resize "${THUMB_SIZE}x${THUMB_SIZE}^" \
        -gravity center \
        -extent "${THUMB_SIZE}x${THUMB_SIZE}" \
        -quality 85 \
        "$thumb" 2>/dev/null || true
    fi
    [ -f "$thumb" ] && icon="$thumb"
  fi

  printf '%s\0icon\x1f%s\n' "$name" "$icon"
}

choice_idx="$(
  {
    for w in "${WALLS[@]}"; do
      make_entry "$w"
    done
  } | rofi -dmenu -format i -i -no-custom -show-icons -theme "$THEME" -p "Wallpaper"
)"

if [ -z "${choice_idx:-}" ] || [ "$choice_idx" = "-1" ]; then
  exit 0
fi

if [ "$choice_idx" -lt 0 ] || [ "$choice_idx" -ge "${#WALLS[@]}" ]; then
  exit 1
fi

wall="${WALLS[$choice_idx]}"

mkdir -p "$(dirname "$CURRENT_FILE")"
printf '%s\n' "$wall" > "$CURRENT_FILE"
if ! bash "$APPLY_SCRIPT" "$wall"; then
  rofi -e "Failed to apply wallpaper"
  exit 1
fi
