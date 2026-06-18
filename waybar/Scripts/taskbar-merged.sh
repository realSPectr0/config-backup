#!/usr/bin/env bash
set -euo pipefail

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo '{"text":""}'
  exit 0
fi

clients_json=$(hyprctl clients -j 2>/dev/null || echo '[]')

# Build class -> count list
mapfile -t rows < <(
  jq -r '[.[] | .class // empty | select(length>0)] | sort | group_by(.) | map({class: .[0], count: length}) | .[] | "\(.class)\t\(.count)"' <<<"$clients_json"
)

if [ ${#rows[@]} -eq 0 ]; then
  echo '{"text":""}'
  exit 0
fi

icon_for() {
  local cls="${1,,}"
  case "$cls" in
    *firefox*|*librewolf*|*floorp*) echo "" ;;
    *chromium*|*google-chrome*|*brave*|*vivaldi*|*thorium*|*edge*|*opera*|*zen*|*qutebrowser*) echo "" ;;
    *kitty*|*alacritty*|*foot*|*wezterm*|*gnome-terminal*|*konsole*|*xfce4-terminal*|*tilix*|*xterm*) echo "" ;;
    *code*|*vscodium*|*codium*|*sublime*|*atom*|*jetbrains*|*idea*|*pycharm*|*webstorm*|*clion*|*goland*|*rider*) echo "" ;;
    *thunar*|*nautilus*|*dolphin*|*pcmanfm*|*nemo*|*ranger*|*lf*) echo "" ;;
    *spotify*) echo "" ;;
    *discord*|*vesktop*) echo "" ;;
    *slack*|*teams*|*element*|*signal*|*whatsapp*|*telegram*|*telegramdesktop*|*zoom*|*skype*) echo "" ;;
    *steam*|*lutris*|*heroic*|*prismlauncher*|*minecraft*) echo "" ;;
    *mpv*|*vlc*|*celluloid*|*plex*|*kodi*) echo "" ;;
    *gimp*|*krita*|*inkscape*|*blender*) echo "" ;;
    *obsidian*) echo "" ;;
    *obs*|*recordmydesktop*) echo "" ;;
    *libreoffice*|*writer*|*calc*|*impress*) echo "" ;;
    *thunderbird*|*evolution*|*mailspring*) echo "" ;;
    *filezilla*) echo "" ;;
    *pavucontrol*|*pwvucontrol*|*pactl*|*wireplumber*|*helvum*) echo "" ;;
    *) echo "" ;;
  esac
}

text_parts=()
tip_parts=()

for row in "${rows[@]}"; do
  cls=${row%%$'\t'*}
  cnt=${row##*$'\t'}
  icon=$(icon_for "$cls")
  text_parts+=("${icon} ${cnt}")
  tip_parts+=("${cls}: ${cnt}")
 done

text=$(printf ' %s' "${text_parts[@]}")
text=${text# }

tooltip=$(printf '%s\n' "${tip_parts[@]}")

tooltip_json=$(jq -Rs . <<<"$tooltip")

printf '{"text":"%s","tooltip":%s,"class":"merged-taskbar"}\n' "$text" "$tooltip_json"
