#!/usr/bin/env bash
# apply-wallpaper.sh — helper for quickshell wallpaper picker

SOURCE="$1"
URL_OR_PATH="$2"
NAME="$3"
WALLDIR="$HOME/Pictures/Wallpapers"
ONLINEDIR="$WALLDIR/Online"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$ONLINEDIR"

if [ "$SOURCE" = "wallhaven" ]; then
    # Extract extension or assume jpg
    EXT="${URL_OR_PATH##*.}"
    TARGET="$ONLINEDIR/$NAME.$EXT"
    
    if [ ! -f "$TARGET" ]; then
        curl -L -o "$TARGET" "$URL_OR_PATH"
    fi
    WALLPAPER="$TARGET"
else
    WALLPAPER="$URL_OR_PATH"
fi

[ -f "$WALLPAPER" ] && bash "$SCRIPT_DIR/wallpaper.sh" "$WALLPAPER"
