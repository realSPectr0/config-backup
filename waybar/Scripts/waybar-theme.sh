#!/bin/bash

WAYBAR_DIR="$HOME/.config/waybar"
QS_BAR_DIR="$HOME/.config/quickshell/bar"
QS_LUMINARY_DIR="$HOME/.config/hypr/scripts/quickshell"
QS_MANAGER="$HOME/.config/hypr/scripts/qs_manager.sh"
THEME_SYNC="$HOME/.config/hypr/scripts/rofi-wallpaper-theme.py"

if [ -x "$THEME_SYNC" ]; then
    python3 "$THEME_SYNC" >/dev/null 2>&1 || true
fi

# Theme map: "Display Name|config.jsonc|style.css|colors.css"
# Use "qs:<path>" for a quickshell bar launched with quickshell -p.
# Use "qsm:<path>" for qs_manager.sh-based bars (multi-process).
declare -A THEMES
THEMES["  Complex"]="main.jsonc|main.css|maincolors.css"
THEMES["  Minimal"]="minmal.jsonc|minimal.css|minimalcolor.css"
THEMES["  Fugly"]="fugly.jsonc|fugly.css|maincolors.css"
THEMES["  SnarkyDev"]="snarky.jsonc|snarky.css|maincolors.css"
THEMES["  Nocturne"]="qs:$QS_BAR_DIR||"
THEMES["  Luminary"]="qsm:$QS_MANAGER||"

if [[ -n "${1:-}" ]]; then
    case "${1,,}" in
        nocturne|qs|quickshell) CHOSEN="  Nocturne" ;;
        luminary) CHOSEN="  Luminary" ;;
        complex|main) CHOSEN="  Complex" ;;
        minimal|minmal) CHOSEN="  Minimal" ;;
        fugly) CHOSEN="  Fugly" ;;
        snarky|snarkydev) CHOSEN="  SnarkyDev" ;;
        *) CHOSEN="$1" ;;
    esac
else
    # Build rofi menu
    MENU=$(printf '%s\n' "${!THEMES[@]}" | sort)

    CHOSEN=$(echo "$MENU" | rofi -dmenu \
        -p "Bar" \
        -theme "$HOME/.config/waybar/Scripts/waybar-switcher.rasi" \
        -no-custom)
fi

[[ -z "$CHOSEN" ]] && exit 0
if [[ -z "${THEMES[$CHOSEN]+x}" ]]; then
    echo "Unknown bar theme: $CHOSEN" >&2
    exit 1
fi

IFS='|' read -r CONFIG STYLE COLORS <<< "${THEMES[$CHOSEN]}"

stop_qs_bar() {
    # Nocturne (single-process bar)
    quickshell kill -p "$QS_BAR_DIR" --any-display 2>/dev/null || true
    quickshell kill -p "$QS_BAR_DIR/shell.qml" --any-display 2>/dev/null || true
    quickshell kill -c bar --any-display 2>/dev/null || true
    # Luminary (multi-process bar)
    pkill -f "quickshell.*TopBar\.qml" 2>/dev/null || true
    pkill -f "quickshell.*Main\.qml" 2>/dev/null || true
    pkill -f "quickshell.*Floating\.qml" 2>/dev/null || true
}

if [[ "$CONFIG" == qsm:* ]]; then
    # Launch qs_manager-based bar (Luminary)
    QSM_PATH="${CONFIG#qsm:}"
    killall -q -9 waybar
    stop_qs_bar
    sleep 0.3
    bash "$QSM_PATH" &
elif [[ "$CONFIG" == qs:* ]]; then
    # Launch single-process quickshell bar (Nocturne)
    QS_PATH="${CONFIG#qs:}"
    killall -q -9 waybar
    stop_qs_bar
    quickshell -p "$QS_PATH" &
else
    # Symlink the selected waybar theme and restart waybar
    stop_qs_bar
    killall -q -9 waybar
    ln -sf "$WAYBAR_DIR/$CONFIG" "$WAYBAR_DIR/config.jsonc"
    ln -sf "$WAYBAR_DIR/$STYLE"  "$WAYBAR_DIR/style.css"
    ln -sf "$WAYBAR_DIR/$COLORS" "$WAYBAR_DIR/colors.css"
    waybar &
fi
