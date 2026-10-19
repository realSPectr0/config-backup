#!/usr/bin/env bash

# Get current directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Export paths for Quickshell
export QML2_IMPORT_PATH="$DIR/imports:$QML2_IMPORT_PATH"
export QML_XHR_ALLOW_FILE_READ=1

# Change theme here if you want
export QS_THEME="${1:-pixel-night-city}"

echo "Locking with Quickshell using theme: $QS_THEME"

# Safety: Kill any other lockers that might be running (like hyprlock from hypridle)
# Only one app can hold the Wayland session lock at a time.
killall -9 hyprlock swaylock wlogout 2>/dev/null || true

# Run the shell with a unique filename to avoid IPC interference with existing bars
quickshell -p "$DIR/lock_shell.qml"
