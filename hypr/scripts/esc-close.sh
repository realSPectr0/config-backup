#!/usr/bin/env bash
# Esc closes the swaync panel and the focused quickshell Settings window.
# Bound with bindn, so the key still reaches the focused app.
swaync-client -cp -sw >/dev/null 2>&1
if hyprctl activewindow -j | jq -e '.class == "org.quickshell" and .title == "Settings"' >/dev/null; then
    "$HOME/.local/bin/settings" hide >/dev/null 2>&1
fi
