#!/usr/bin/env bash

set -u

BAR_STATE="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/.last-bar"
CAFFYNE_CONTROL="$HOME/.local/bin/caffyne-control"
ROFI_LAUNCHER="$HOME/rofi/files/launchers/type-6/launcher.sh"

selected_bar=""
if [[ -r "$BAR_STATE" ]]; then
    IFS= read -r selected_bar < "$BAR_STATE" || true
fi

if [[ "$selected_bar" == *Caffyne* ]] \
    || systemctl --user is-active --quiet caffyne-shell.service 2>/dev/null; then
    if [[ -x "$CAFFYNE_CONTROL" ]] && "$CAFFYNE_CONTROL" Dash; then
        exit 0
    fi
fi

exec "$ROFI_LAUNCHER"
