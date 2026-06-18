#!/usr/bin/env bash
set -euo pipefail

THEME="$HOME/.config/rofi/powermenu.rasi"
THEME_SYNC="$HOME/.config/hypr/scripts/rofi-wallpaper-theme.py"
LOCKER="$HOME/.local/share/quickshell-lockscreen/lock.sh"

if [ -x "$THEME_SYNC" ]; then
    python3 "$THEME_SYNC" >/dev/null 2>&1 || true
fi

LOCK="  Lock"
SUSPEND="󰤄  Suspend"
LOGOUT="󰍃  Logout"
HIBERNATE="󰤾  Hibernate"
REBOOT="󰜉  Reboot"
SHUTDOWN="󰐥  Shutdown"

choice="$(
    printf '%s\n' "$LOCK" "$SUSPEND" "$LOGOUT" "$HIBERNATE" "$REBOOT" "$SHUTDOWN" \
        | rofi -dmenu -i -no-custom -theme "$THEME" -p "Power" || true
)"

[ -z "${choice:-}" ] && exit 0

confirm() {
    local label="$1"
    local answer

    answer="$(
        printf '%s\n%s\n' "Cancel" "Confirm" \
            | rofi -dmenu -i -no-custom -selected-row 1 -theme "$THEME" \
                -theme-str 'window { width: 360px; } listview { columns: 2; lines: 1; }' \
                -p "$label?" || true
    )"

    [ "$answer" = "Confirm" ]
}

lock_screen() {
    if [ -x "$LOCKER" ]; then
        "$LOCKER"
    elif command -v hyprlock >/dev/null 2>&1; then
        hyprlock
    else
        loginctl lock-session
    fi
}

case "$choice" in
    "$LOCK")
        lock_screen
        ;;
    "$SUSPEND")
        confirm "Suspend" && systemctl suspend
        ;;
    "$LOGOUT")
        confirm "Logout" && hyprctl dispatch exit
        ;;
    "$HIBERNATE")
        confirm "Hibernate" && systemctl hibernate
        ;;
    "$REBOOT")
        confirm "Reboot" && systemctl reboot
        ;;
    "$SHUTDOWN")
        confirm "Shutdown" && systemctl poweroff
        ;;
esac
