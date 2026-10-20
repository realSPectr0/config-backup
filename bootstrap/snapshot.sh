#!/usr/bin/env bash
# Refresh the bootstrap/ snapshots from this machine so install.sh restores the
# current setup. Run this before committing/pushing the backup repo.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
boot="$repo_root/bootstrap"
pkgdir="$boot/packages"

log() { printf '==> %s\n' "$*"; }

# Packages that only make sense on specific hardware. install.sh installs these
# only when matching hardware is detected, so keep them out of the main lists.
hardware_re='^(nvidia.*|lib32-nvidia.*|libva-nvidia-driver|cuda|opencl-nvidia|intel-ucode|amd-ucode|asusctl|supergfxctl|rog-control-center)$'

log "Package manifests"
mkdir -p "$pkgdir"
pacman -Qqen | grep -Ev "$hardware_re" > "$pkgdir/pacman-native.txt"
# -debug packages are build by-products, not something to reinstall.
pacman -Qqem | grep -Ev "$hardware_re" | grep -Ev -- '-debug$' > "$pkgdir/aur.txt"
pacman -Qqe | grep -E '^(nvidia.*|lib32-nvidia.*|libva-nvidia-driver|cuda|opencl-nvidia)$' > "$pkgdir/hardware-nvidia.txt" || true
pacman -Qqe | grep -E '^(asusctl|supergfxctl|rog-control-center)$' > "$pkgdir/hardware-asus.txt" || true
if command -v flatpak >/dev/null 2>&1; then
    flatpak list --app --columns=application > "$pkgdir/flatpak.txt"
fi

log "Home dotfiles (secrets are NOT copied; see README)"
# .zshrc is kept as a hand-sanitized copy because the live one holds API keys.
cp -a "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.gtkrc-2.0" "$boot/home-dotfiles/" 2>/dev/null || true

log "~/.local/bin helpers"
for f in caffyne-control caffyne-fastfetch fabric-cli memguard ani-cli; do
    [[ -f "$HOME/.local/bin/$f" ]] && cp -a "$HOME/.local/bin/$f" "$boot/local-bin/"
done

log "~/.local/share data"
rsync -a --delete "$HOME/.local/share/startpage/" "$boot/local-share/startpage/"
rsync -a --delete --exclude themes_link \
    "$HOME/.local/share/quickshell-lockscreen/" "$boot/local-share/quickshell-lockscreen/"

log "Wallpapers"
rsync -a --delete "$HOME/Pictures/Wallpapers/" "$boot/wallpapers/"

log "caffyne-shell patch + overlay"
caffyne="$HOME/.config/caffyne-shell"
if [[ -d "$caffyne/.git" ]]; then
    git -C "$caffyne" rev-parse HEAD > "$boot/caffyne-shell.base"
    git -C "$caffyne" diff > "$boot/caffyne-shell.patch"
    rm -rf "$boot/caffyne-shell-overlay"
    mkdir -p "$boot/caffyne-shell-overlay"
    git -C "$caffyne" ls-files --others --exclude-standard -z \
        | (cd "$caffyne" && xargs -0 -r cp --parents -a -t "$boot/caffyne-shell-overlay")
    # User settings (bar layout, wallpaper, theme) are git-ignored upstream.
    for f in config/config.json config/dock_state.json; do
        [[ -f "$caffyne/$f" ]] && (cd "$caffyne" && cp --parents -a "$f" "$boot/caffyne-shell-overlay/")
    done
fi

log "Current wallpaper"
rm -f "$boot"/current-wallpaper.*
wall="$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1)"
[[ -z "$wall" ]] && wall="$(cat "$HOME/.cache/wallpaper-colors/current" 2>/dev/null || true)"
if [[ -f "$wall" ]]; then
    cp -a "$wall" "$boot/current-wallpaper.${wall##*.}"
fi

log "rofi (adi1090x) patch"
if [[ -d "$HOME/rofi/.git" ]]; then
    git -C "$HOME/rofi" rev-parse HEAD > "$boot/rofi.base"
    git -C "$HOME/rofi" diff > "$boot/rofi.patch"
fi

log "System config"
mkdir -p "$boot/etc"
for f in /etc/NetworkManager/conf.d/wifi_backend.conf /etc/sddm.conf.d/theme.conf /etc/systemd/zram-generator.conf; do
    [[ -f "$f" ]] && install -D -m 644 "$f" "$boot/etc/${f#/etc/}"
done

log "Done. Review 'git status' and commit."
