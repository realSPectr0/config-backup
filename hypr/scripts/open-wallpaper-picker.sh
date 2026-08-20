#!/usr/bin/env bash

set -u

BAR_STATE="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/.last-bar"
CAFFYNE_CONTROL="$HOME/.local/bin/caffyne-control"
ROFI_PICKER="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/wallpaper-picker.sh"

selected_bar=""
if [[ -r "$BAR_STATE" ]]; then
    IFS= read -r selected_bar < "$BAR_STATE" || true
fi

# The saved selection is authoritative, while the service check also handles
# Caffyne started independently of the bar switcher.
if [[ "$selected_bar" == *Caffyne* ]] \
    || systemctl --user is-active --quiet caffyne-shell.service 2>/dev/null; then
    if [[ -x "$CAFFYNE_CONTROL" ]] && "$CAFFYNE_CONTROL" Wallpapers; then
        exit 0
    fi
fi

exec "$ROFI_PICKER"
