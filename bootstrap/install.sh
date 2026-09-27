#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="$HOME/.config-backup-before-restore/$timestamp"

log() {
    printf '\n==> %s\n' "$*"
}

have() {
    command -v "$1" >/dev/null 2>&1
}

backup_path() {
    local path="$1"
    if [[ -e "$path" || -L "$path" ]]; then
        mkdir -p "$backup_dir/$(dirname "${path#$HOME/}")"
        cp -a "$path" "$backup_dir/${path#$HOME/}"
    fi
}

copy_config_path() {
    local rel="$1"
    local src="$repo_root/$rel"
    local dst="$HOME/.config/$rel"
    [[ -e "$src" ]] || return 0
    backup_path "$dst"
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
}

install_pacman_packages() {
    [[ -s "$repo_root/bootstrap/packages/pacman-native.txt" ]] || return 0
    if ! have pacman; then
        log "pacman not found; skipping Arch package install"
        return 0
    fi

    log "Installing native pacman packages"
    sudo pacman -Syu --needed - < "$repo_root/bootstrap/packages/pacman-native.txt"
}

ensure_aur_helper() {
    if have paru; then
        printf 'paru\n'
        return 0
    fi
    if have yay; then
        printf 'yay\n'
        return 0
    fi

    log "Installing yay AUR helper"
    local tmp
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    printf 'yay\n'
}

install_aur_packages() {
    [[ -s "$repo_root/bootstrap/packages/aur.txt" ]] || return 0
    if ! have pacman; then
        log "pacman not found; skipping AUR package install"
        return 0
    fi

    local helper
    helper="$(ensure_aur_helper)"
    log "Installing AUR packages with $helper"
    "$helper" -S --needed --noconfirm - < "$repo_root/bootstrap/packages/aur.txt"
}

install_flatpaks() {
    [[ -s "$repo_root/bootstrap/packages/flatpak.txt" ]] || return 0
    if ! have flatpak; then
        log "flatpak not found; skipping Flatpak install"
        return 0
    fi

    log "Installing Flatpak apps"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    while IFS= read -r app; do
        [[ -n "$app" ]] && flatpak install -y flathub "$app"
    done < "$repo_root/bootstrap/packages/flatpak.txt"
}

restore_dotfiles() {
    log "Restoring ~/.config desktop setup"
    local config_paths=(
        btop
        cava
        easyeffects
        fastfetch
        fcitx5
        gtk-3.0
        gtk-4.0
        hypr
        kitty
        mpd
        mpv
        nautilus
        nvim
        nwg-look
        quickshell
        ranger
        rofi
        swaync
        systemd
        wal
        waybar
        wlogout
        xfce4
        xsettingsd
        starship.toml
        mimeapps.list
        user-dirs.dirs
    )

    mkdir -p "$HOME/.config"
    for rel in "${config_paths[@]}"; do
        copy_config_path "$rel"
    done

    log "Restoring sanitized home shell files"
    for file in "$repo_root"/bootstrap/home-dotfiles/.*; do
        [[ -f "$file" ]] || continue
        local name
        name="$(basename "$file")"
        [[ "$name" == ".gitconfig.example" ]] && continue
        backup_path "$HOME/$name"
        cp -a "$file" "$HOME/$name"
    done

    mkdir -p "$HOME/.config/shell"
    if [[ ! -e "$HOME/.config/shell/private.env" ]]; then
        install -m 600 /dev/null "$HOME/.config/shell/private.env"
    fi
}

restore_local_files() {
    log "Restoring ~/.local helper scripts and startpage"
    if [[ -d "$repo_root/bootstrap/local-bin" ]]; then
        mkdir -p "$HOME/.local/bin"
        for file in "$repo_root"/bootstrap/local-bin/*; do
            [[ -f "$file" ]] || continue
            local dst="$HOME/.local/bin/$(basename "$file")"
            backup_path "$dst"
            cp -a "$file" "$dst"
            chmod +x "$dst"
        done
    fi

    if [[ -d "$repo_root/bootstrap/local-share/startpage" ]]; then
        mkdir -p "$HOME/.local/share"
        backup_path "$HOME/.local/share/startpage"
        cp -a "$repo_root/bootstrap/local-share/startpage" "$HOME/.local/share/startpage"
    fi
}

restore_caffyne_shell() {
    log "Restoring caffyne-shell with local patch and overlay"
    local dst="$HOME/.config/caffyne-shell"
    if [[ ! -d "$dst/.git" ]]; then
        backup_path "$dst"
        rm -rf "$dst"
        git clone https://github.com/caffyne-org/caffyne-shell.git "$dst"
    fi

    if [[ -s "$repo_root/bootstrap/caffyne-shell.patch" ]]; then
        (cd "$dst" && git apply --whitespace=nowarn "$repo_root/bootstrap/caffyne-shell.patch") || {
            log "caffyne-shell patch did not apply cleanly; leaving checkout for manual review"
        }
    fi

    if [[ -d "$repo_root/bootstrap/caffyne-shell-overlay" ]]; then
        cp -a "$repo_root"/bootstrap/caffyne-shell-overlay/. "$dst"/
    fi

    if [[ -f "$dst/requirements.txt" && ! -x "$dst/venv/bin/python" ]]; then
        python3 -m venv "$dst/venv"
        "$dst/venv/bin/pip" install -r "$dst/requirements.txt"
    fi

    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/caffyne-shell-local" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail

CAFFYNE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/caffyne-shell"
PYTHON="$CAFFYNE_DIR/venv/bin/python"
RUNTIME_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/caffyne-shell/root"

if [[ ! -x "$PYTHON" ]]; then
    echo "Caffyne virtual environment is missing: $PYTHON" >&2
    exit 1
fi

if [[ -d "$RUNTIME_ROOT/usr" ]]; then
    export PATH="$RUNTIME_ROOT/usr/bin:$PATH"
    export LD_LIBRARY_PATH="$RUNTIME_ROOT/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export GI_TYPELIB_PATH="$RUNTIME_ROOT/usr/lib/girepository-1.0${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
    export XDG_DATA_DIRS="$RUNTIME_ROOT/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
fi

cd "$CAFFYNE_DIR"
mkdir -p "$HOME/.cache/caffyne-shell"
exec "$PYTHON" "$CAFFYNE_DIR/main.py" "$@" \
    >"$HOME/.cache/caffyne-shell/session.log" 2>&1
WRAPPER
    chmod +x "$HOME/.local/bin/caffyne-shell-local"
}

enable_user_services() {
    if ! have systemctl; then
        return 0
    fi

    log "Reloading and enabling user services"
    systemctl --user daemon-reload || true
    systemctl --user enable caffyne-shell.service || true
    systemctl --user enable startpage-media.service startpage-stats.service || true
}

main() {
    install_pacman_packages
    install_aur_packages
    install_flatpaks
    restore_dotfiles
    restore_local_files
    restore_caffyne_shell
    enable_user_services

    log "Done. Backups, if any, were saved under $backup_dir"
    log "Reboot or log out/in to let Hyprland, portals, fonts, services, and shell state settle."
}

main "$@"
