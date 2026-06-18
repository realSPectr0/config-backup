#!/usr/bin/env bash
set -euo pipefail

THEME="/home/arch/.config/waybar/Scripts/rofi-battery-user.rasi"

battery_path=""
if command -v upower >/dev/null 2>&1; then
  battery_path=$(upower -e | rg -m1 'battery' || true)
fi

msg_lines=("Battery info unavailable")
if [[ -n "$battery_path" ]]; then
  info=$(upower -i "$battery_path")
  percent=$(awk -F: '/percentage/{gsub(/^[ \t]+/,"",$2); print $2}' <<<"$info")
  state=$(awk -F: '/state/{gsub(/^[ \t]+/,"",$2); print $2}' <<<"$info")
  tte=$(awk -F: '/time to empty/{gsub(/^[ \t]+/,"",$2); print $2}' <<<"$info")
  ttf=$(awk -F: '/time to full/{gsub(/^[ \t]+/,"",$2); print $2}' <<<"$info")
  energy_full=$(awk -F: '/energy-full:/{gsub(/^[ \t]+/,"",$2); print $2}' <<<"$info")
  energy_full_design=$(awk -F: '/energy-full-design:/{gsub(/^[ \t]+/,"",$2); print $2}' <<<"$info")
  capacity=$(awk -F: '/capacity:/{gsub(/^[ \t]+/,"",$2); print $2}' <<<"$info")

  time_str=""
  if [[ "$state" == "charging" && -n "$ttf" ]]; then
    time_str="Time to full: $ttf"
  elif [[ -n "$tte" ]]; then
    time_str="Time remaining: $tte"
  fi

  msg_lines=("Battery: ${percent:-?} (${state:-unknown})")
  if [[ -n "$time_str" ]]; then
    msg_lines+=("$time_str")
  fi
  if [[ -n "$energy_full" || -n "$energy_full_design" ]]; then
    cap_line="Capacity:"
    if [[ -n "$energy_full" ]]; then
      cap_line+=" $energy_full"
    fi
    if [[ -n "$energy_full_design" ]]; then
      if [[ -n "$energy_full" ]]; then
        cap_line+=" /"
      fi
      cap_line+=" $energy_full_design (design)"
    fi
    msg_lines+=("$cap_line")
  fi
  if [[ -n "$capacity" ]]; then
    msg_lines+=("Health: $capacity")
  fi
fi

current_profile="unavailable"
if command -v powerprofilesctl >/dev/null 2>&1; then
  current_profile=$(powerprofilesctl get 2>/dev/null || echo "balanced")
fi

profile_label="$current_profile"
case "$current_profile" in
  performance) profile_label="󰓅 Performance";;
  balanced) profile_label="󰾅 Balanced";;
  power-saver) profile_label="󰌪 Power Saver";;
esac

msg_lines+=("")
msg_lines+=("Power profile: $profile_label")

msg=$(printf '%s\n' "${msg_lines[@]}")

if ! command -v powerprofilesctl >/dev/null 2>&1; then
  rofi -theme "$THEME" -e "$msg"
  exit 0
fi

options=(
  "󰌪 Power Saver"
  "󰾅 Balanced"
  "󰓅 Performance"
)

current_line=""
case "$current_profile" in
  power-saver) options[0]="● ${options[0]}"; current_line="${options[0]}";;
  balanced) options[1]="● ${options[1]}"; current_line="${options[1]}";;
  performance) options[2]="● ${options[2]}"; current_line="${options[2]}";;
esac

rofi_args=( -dmenu -theme "$THEME" -p "" -mesg "$msg" -no-custom )
if [[ -n "$current_line" ]]; then
  rofi_args+=( -select "$current_line" )
fi

selection=$(printf '%s\n' "${options[@]}" | rofi "${rofi_args[@]}")

if [[ -z "$selection" ]]; then
  exit 0
fi

case "$selection" in
  *"Power Saver"*) powerprofilesctl set power-saver;;
  *"Balanced"*) powerprofilesctl set balanced;;
  *"Performance"*) powerprofilesctl set performance;;
esac
