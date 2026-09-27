#!/usr/bin/env bash

# Kitty reloads its configuration (including generated includes) on SIGUSR1.
# Cover both the normal binary name and the wrapped name used by some packages.
for process_name in kitty .kitty-wrapped; do
    pkill -USR1 -u "$(id -u)" -x "$process_name" 2>/dev/null || true
done
