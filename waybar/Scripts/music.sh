#!/usr/bin/env bash

status="$(playerctl status 2>/dev/null || true)"

if [[ -z "$status" ]]; then
    jq -cn '{
        text: "",
        tooltip: "No media player",
        class: "idle"
    }'
    exit 0
fi

artist="$(playerctl metadata artist 2>/dev/null || true)"
title="$(playerctl metadata title 2>/dev/null || true)"
player="$(playerctl metadata --format '{{playerName}}' 2>/dev/null || true)"

if [[ -n "$artist" && -n "$title" ]]; then
    text="$artist - $title"
elif [[ -n "$title" ]]; then
    text="$title"
else
    text="$player"
fi

jq -cn \
    --arg text "$text" \
    --arg tooltip "${player:-Media player} · $status\n$text" \
    --arg class "${status,,}" \
    '{text: $text, tooltip: $tooltip, class: [$class, "active"]}'
