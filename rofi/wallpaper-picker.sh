#!/usr/bin/env bash
# Wallpaper picker: one rofi window, one tab per folder in $WALLDIR,
# a row of wallpaper cards with a "Random Wallpaper" card first.
# Run with no args to open it; rofi calls it back as a script mode
# ("wallpaper-picker.sh --mode <folder>") to list and apply wallpapers.
set -uo pipefail

WALLDIR="${WALLDIR:-$HOME/Documents/.dw}"
THEME="${THEME:-$HOME/.config/rofi/wallpaper-picker.rasi}"
THUMBDIR="${THUMBDIR:-$HOME/.cache/rofi-wallpaper-thumbs}"
CURRENT_FILE="${CURRENT_FILE:-$HOME/.cache/wallpaper-colors/current}"
LAST_TAB_FILE="$HOME/.cache/rofi-wallpaper-last-tab"
THUMB_GEOM="${THUMB_GEOM:-480x270}"
APPLY_SCRIPT="${APPLY_SCRIPT:-$HOME/.config/hypr/scripts/wallpaper.sh}"
THEME_SYNC="$HOME/.config/hypr/scripts/rofi-wallpaper-theme.py"
SELF="$(readlink -f "$0")"

thumb_for() {
  local hash
  hash="$(printf '%s' "$1" | md5sum | cut -d' ' -f1)"
  printf '%s/%s_%s.jpg' "$THUMBDIR" "$hash" "$THUMB_GEOM"
}

make_thumb() {
  local src="$1" thumb
  thumb="$(thumb_for "$src")"
  if [ ! -f "$thumb" ] || [ "$src" -nt "$thumb" ]; then
    magick "$src[0]" -resize "${THUMB_GEOM}^" -gravity center -extent "$THUMB_GEOM" \
      -quality 85 "$thumb" 2>/dev/null
  fi
}

list_walls() {
  find "$1" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort
}

# ---- script mode: called by rofi ----
if [ "${1:-}" = "--mode" ]; then
  folder="$WALLDIR/$2"

  current=""
  [ -f "$CURRENT_FILE" ] && current="$(cat "$CURRENT_FILE")"

  if [ "${ROFI_RETV:-0}" = "1" ] && [ -n "${ROFI_INFO:-}" ]; then
    wall="$ROFI_INFO"
    if [ "$wall" = "__random__" ]; then
      wall="$(list_walls "$folder" | grep -vxF -- "$current" | shuf -n1)"
      [ -n "$wall" ] || exit 0
    fi
    printf '%s\n' "$2" > "$LAST_TAB_FILE"
    mkdir -p "$(dirname "$CURRENT_FILE")"
    printf '%s\n' "$wall" > "$CURRENT_FILE"
    # Apply after rofi closes so the window doesn't hang on it.
    setsid -f bash "$APPLY_SCRIPT" "$wall" >/dev/null 2>&1
    exit 0
  fi

  printf '\0prompt\x1f%s\n' "$2"
  printf '\0no-custom\x1ftrue\n'

  mapfile -t walls < <(list_walls "$folder")
  [ ${#walls[@]} -gt 0 ] || exit 0

  # Row options must come before the rows; row 0 is the random card.
  for i in "${!walls[@]}"; do
    [ "${walls[$i]}" = "$current" ] && printf '\0active\x1f%s\n' "$((i + 1))"
  done

  printf '%s\0icon\x1f%s\x1finfo\x1f__random__\x1fmeta\x1frandom shuffle\n' \
    "  Random Wallpaper" "$(thumb_for "${walls[RANDOM % ${#walls[@]}]}")"

  for wall in "${walls[@]}"; do
    printf '%s\0icon\x1f%s\x1finfo\x1f%s\n' "$(basename "$wall")" "$(thumb_for "$wall")" "$wall"
  done
  exit 0
fi

# ---- launcher ----
[ -x "$THEME_SYNC" ] && python3 "$THEME_SYNC" >/dev/null 2>&1

if [ ! -d "$WALLDIR" ]; then
  rofi -e "Wallpaper directory not found: $WALLDIR"
  exit 1
fi

mkdir -p "$THUMBDIR"

export -f make_thumb thumb_for
export THUMBDIR THUMB_GEOM
find "$WALLDIR" -mindepth 2 -maxdepth 2 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0 \
  | xargs -0 -P "$(nproc)" -I{} bash -c 'make_thumb "$1"' _ {}

modi=()
while IFS= read -r d; do
  name="$(basename "$d")"
  [ -n "$(list_walls "$d" | head -n1)" ] || continue
  modi+=("$name:$SELF --mode '$name'")
done < <(find "$WALLDIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | sort)

if [ ${#modi[@]} -eq 0 ]; then
  rofi -e "No wallpapers found in $WALLDIR"
  exit 1
fi

# Open on the folder holding the current wallpaper, else the last tab used.
start=""
if [ -f "$CURRENT_FILE" ]; then
  cur_dir="$(dirname "$(cat "$CURRENT_FILE")")"
  [ "$(dirname "$cur_dir")" = "$WALLDIR" ] && start="$(basename "$cur_dir")"
fi
[ -z "$start" ] && [ -f "$LAST_TAB_FILE" ] && start="$(cat "$LAST_TAB_FILE")"
[ -z "$start" ] && start="${modi[0]%%:*}"

exec rofi -show "$start" -modi "$(IFS=,; echo "${modi[*]}")" \
  -show-icons -theme "$THEME" -kb-mode-next "Tab,Control+Tab" -kb-mode-previous "ISO_Left_Tab,Control+ISO_Left_Tab" \
  -kb-row-tab "" -kb-element-next "" -kb-element-prev "" \
  -kb-move-char-back "Control+b" -kb-move-char-forward "Control+f" \
  -kb-row-left "Left" -kb-row-right "Right" \
  -me-select-entry "" -me-accept-entry "MousePrimary"
