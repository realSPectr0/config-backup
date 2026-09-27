#!/usr/bin/env bash

set -euo pipefail

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Display mode" -t 2500 "Display mode" "$1" >/dev/null 2>&1 9>&- &
  fi
}

# Ignore a second key press while Hyprland is applying the first one.
lock_file="${XDG_RUNTIME_DIR:-/tmp}/toggle-monitor-mode.lock"
exec 9>"$lock_file"
flock -n 9 || exit 0

if ! monitors_json=$(hyprctl monitors all -j); then
  notify "Could not read the monitor state"
  exit 1
fi

internal_info=$(jq -r '
  first(.[] | select((.name | startswith("eDP-")) and (.disabled != true))) |
  [.name, .scale, .width, .mirrorOf] | @tsv
' <<< "$monitors_json")

external_info=$(jq -r '
  first(.[] | select(.name == "HDMI-A-1" and (.disabled != true))) |
  [.name, .x, .y] | @tsv
' <<< "$monitors_json")

if [[ -z "$internal_info" || "$internal_info" == "null" ]]; then
  notify "No active internal display found"
  exit 1
fi

if [[ -z "$external_info" || "$external_info" == "null" ]]; then
  notify "HDMI-A-1 is not connected"
  exit 1
fi

IFS=$'\t' read -r internal scale width mirror_of <<< "$internal_info"
IFS=$'\t' read -r external external_x external_y <<< "$external_info"

if [[ "$mirror_of" == "none" ]]; then
  # Only change the mirrored output. Reconfiguring both outputs separately can
  # briefly overlap them and leave Hyprland's pointer mapping in a bad state.
  monitor_rule="$internal,preferred,${external_x}x${external_y},$scale,mirror,$external"
  mode="Duplicate displays"
else
  # Put the laptop immediately left of the external display. Monitor positions
  # use logical pixels, so account for the laptop's fractional scale.
  logical_width=$(awk -v width="$width" -v scale="$scale" 'BEGIN { printf "%.0f", width / scale }')
  internal_x=$((external_x - logical_width))
  monitor_rule="$internal,preferred,${internal_x}x${external_y},$scale"
  mode="Extended displays"
fi

if ! result=$(hyprctl keyword monitor "$monitor_rule" 2>&1); then
  notify "Failed to switch displays: $result"
  exit 1
fi

notify "$mode"
