#!/usr/bin/env bash

## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x
#
## Rofi   : Launcher (Modi Drun, Run, File Browser, Window)
#
## Available Styles
#
## style-1     style-2     style-3     style-4     style-5
## style-6     style-7     style-8     style-9     style-10

dir="$HOME/rofi/files/launchers/type-6"
theme='style-6'
theme_sync="$HOME/.config/hypr/scripts/rofi-wallpaper-theme.py"

if [ -x "$theme_sync" ]; then
  python3 "$theme_sync" >/dev/null 2>&1 || true
fi

## Run
rofi \
  -show drun \
  -theme ${dir}/${theme}.rasi
