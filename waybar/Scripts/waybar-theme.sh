#!/bin/bash

WAYBAR_DIR="$HOME/.config/waybar"
QS_BAR_DIR="$HOME/.config/quickshell/bar"
QS_LUMINARY_DIR="$HOME/.config/hypr/scripts/quickshell"
QS_MANAGER="$HOME/.config/hypr/scripts/qs_manager.sh"
CAFFYNE_DIR="$HOME/.config/caffyne-shell"
CAFFYNE_START="$HOME/.local/bin/caffyne-shell-local"
THEME_SYNC="$HOME/.config/hypr/scripts/rofi-wallpaper-theme.py"
HYPR_BAR_THEME="$HOME/.config/hypr/modules/bar-theme.conf"
BAR_STATE="$HOME/.config/waybar/.last-bar"

if [ -x "$THEME_SYNC" ]; then
    python3 "$THEME_SYNC" >/dev/null 2>&1 || true
fi

# Theme map: "Display Name|config.jsonc|style.css|colors.css"
# Use "qs:<path>" for a quickshell bar launched with quickshell -p.
# Use "qsm:<path>" for qs_manager.sh-based bars (multi-process).
# Use "caffyne:<path>" for the standalone Fabric-based Caffyne shell.
declare -A THEMES
THEMES["  Complex"]="main.jsonc|main.css|maincolors.css"
THEMES["  Minimal"]="minmal.jsonc|minimal.css|minimalcolor.css"
THEMES["  Fugly"]="fugly.jsonc|fugly.css|maincolors.css"
THEMES["  Whitewashed"]="whitewashed.jsonc|whitewashed.css|maincolors.css"
THEMES["  Nocturne"]="qs:$QS_BAR_DIR||"
THEMES["  Luminary"]="qsm:$QS_MANAGER||"
THEMES["  Caffyne"]="caffyne:$CAFFYNE_START||"

if [[ "${1:-}" == "--restore" ]]; then
    CHOSEN=""
    if [[ -r "$BAR_STATE" ]]; then
        IFS= read -r CHOSEN < "$BAR_STATE"
    fi
    # Preserve the old login behavior if no choice has been saved yet.
    CHOSEN="${CHOSEN:-  Luminary}"
elif [[ -n "${1:-}" ]]; then
    case "${1,,}" in
        nocturne|qs|quickshell) CHOSEN="  Nocturne" ;;
        luminary) CHOSEN="  Luminary" ;;
        caffyne|fabric) CHOSEN="  Caffyne" ;;
        complex|main) CHOSEN="  Complex" ;;
        minimal|minmal) CHOSEN="  Minimal" ;;
        fugly) CHOSEN="  Fugly" ;;
        white|whitewashed) CHOSEN="  Whitewashed" ;;
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
    if [[ "${1:-}" == "--restore" ]]; then
        CHOSEN="  Luminary"
    else
        echo "Unknown bar theme: $CHOSEN" >&2
        exit 1
    fi
fi

# Remember both menu selections and command-line selections for the next login.
printf '%s\n' "$CHOSEN" > "$BAR_STATE"

IFS='|' read -r CONFIG STYLE COLORS <<< "${THEMES[$CHOSEN]}"

if [[ "$CHOSEN" == "  Whitewashed" ]]; then
    ROUNDING=0
else
    ROUNDING=10
fi

# Keep the selected corner style across Hyprland config reloads, and apply it now.
printf '# Updated automatically by ~/.config/waybar/Scripts/waybar-theme.sh.\ndecoration:rounding = %s\n' \
    "$ROUNDING" > "$HYPR_BAR_THEME"
hyprctl keyword decoration:rounding "$ROUNDING" >/dev/null 2>&1 || true

stop_qs_bar() {
    # Nocturne (single-process bar)
    timeout 3s quickshell kill -p "$QS_BAR_DIR" --any-display >/dev/null 2>&1 || true
    pkill -f "quickshell.*\.config/quickshell/bar" 2>/dev/null || true
    # Luminary (multi-process bar)
    pkill -f "quickshell.*TopBar\.qml" 2>/dev/null || true
    pkill -f "quickshell.*Main\.qml" 2>/dev/null || true
    pkill -f "quickshell.*Floating\.qml" 2>/dev/null || true
}

stop_caffyne() {
    systemctl --user stop caffyne-shell.service 2>/dev/null || true
    pkill -f "$CAFFYNE_DIR/main.py" 2>/dev/null || true
    pkill -x caffyne-shell 2>/dev/null || true
    pkill -f "swayidle.*$CAFFYNE_DIR" 2>/dev/null || true
}

if [[ "$CONFIG" == caffyne:* ]]; then
    CAFFYNE_PATH="${CONFIG#caffyne:}"
    if [[ ! -x "$CAFFYNE_PATH" ]]; then
        echo "Caffyne launcher is missing or not executable: $CAFFYNE_PATH" >&2
        exit 1
    fi
    killall -q -9 waybar
    stop_qs_bar
    stop_caffyne
    sleep 0.3
    systemctl --user import-environment \
        WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP \
        DBUS_SESSION_BUS_ADDRESS >/dev/null 2>&1 || true
    systemctl --user daemon-reload
    systemctl --user restart caffyne-shell.service
elif [[ "$CONFIG" == qsm:* ]]; then
    # Launch qs_manager-based bar (Luminary)
    QSM_PATH="${CONFIG#qsm:}"
    killall -q -9 waybar
    stop_qs_bar
    stop_caffyne
    sleep 0.3
    bash "$QSM_PATH" &
elif [[ "$CONFIG" == qs:* ]]; then
    # Launch single-process quickshell bar (Nocturne)
    QS_PATH="${CONFIG#qs:}"
    killall -q -9 waybar
    stop_qs_bar
    stop_caffyne
    quickshell -p "$QS_PATH" &
else
    # Symlink the selected waybar theme and restart waybar
    stop_qs_bar
    stop_caffyne
    killall -q -9 waybar
    ln -sf "$WAYBAR_DIR/$CONFIG" "$WAYBAR_DIR/config.jsonc"
    ln -sf "$WAYBAR_DIR/$STYLE"  "$WAYBAR_DIR/style.css"
    ln -sf "$WAYBAR_DIR/$COLORS" "$WAYBAR_DIR/colors.css"
    waybar &
fi
