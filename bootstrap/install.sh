#!/usr/bin/env bash
# Restore this Arch + Hyprland desktop onto a fresh machine.
#
#   git clone https://github.com/realSPectr0/config-backup.git ~/.config-restore
#   ~/.config-restore/bootstrap/install.sh
#
# Options:
#   --core-only       only install the desktop-critical AUR packages, skip the
#                     rest of the AUR list and Flatpaks (much faster)
#   --skip-packages   restore files/services only, install nothing
#   --no-system       skip everything that needs sudo (packages, /etc, services)
#   -y, --yes         don't ask for confirmation before starting
#
# BUILD_JOBS=N overrides the parallel AUR build jobs (default: ~3 GB RAM each).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
boot="$repo_root/bootstrap"
pkgdir="$boot/packages"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="$HOME/.config-backup-before-restore/$timestamp"
# The machine the snapshot was taken on; paths get rewritten to this $HOME.
source_home="/home/arch"

core_only=0
skip_packages=0
no_system=0
assume_yes=0
failed=()

# AUR packages the desktop does not work without; failures here are fatal.
aur_core=(quickshell-git waybar-cava python-pywal wlogout grimblast-git waypaper hyprshade wallust)

for arg in "$@"; do
    case "$arg" in
        --core-only) core_only=1 ;;
        --skip-packages) skip_packages=1 ;;
        --no-system) no_system=1; skip_packages=1 ;;
        -y|--yes) assume_yes=1 ;;
        -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

log() {
    printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"
}

warn() {
    printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2
}

have() {
    command -v "$1" >/dev/null 2>&1
}

read_list() {
    [[ -f "$1" ]] && grep -Ev '^\s*(#|$)' "$1" || true
}

backup_path() {
    local path="$1"
    if [[ -e "$path" || -L "$path" ]]; then
        mkdir -p "$backup_dir/$(dirname "${path#"$HOME"/}")"
        cp -a "$path" "$backup_dir/${path#"$HOME"/}"
    fi
}

# Replace $dst with $src (a file or directory), keeping a backup of $dst.
restore() {
    local src="$1" dst="$2"
    [[ -e "$src" ]] || return 0
    backup_path "$dst"
    rm -rf "$dst"
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
}

# Rewrite hardcoded /home/arch paths when restoring as a different user.
fix_home_paths() {
    [[ "$HOME" == "$source_home" ]] && return 0
    local path
    for path in "$@"; do
        [[ -e "$path" ]] || continue
        grep -rlI --exclude-dir=.git --exclude-dir=venv -- "$source_home" "$path" 2>/dev/null \
            | while IFS= read -r file; do
                sed -i "s|$source_home|$HOME|g" "$file"
            done || true
    done
}

preflight() {
    if [[ $EUID -eq 0 ]]; then
        echo "Run this as your normal user, not root (it uses sudo where needed)." >&2
        exit 1
    fi
    if (( ! no_system )) && ! have pacman; then
        echo "This installer targets Arch Linux (pacman not found)." >&2
        exit 1
    fi

    log "Restoring desktop setup from $repo_root"
    echo "  user:      $USER ($HOME)"
    echo "  backups:   $backup_dir"
    (( skip_packages )) && echo "  packages:  skipped" || echo "  packages:  $( ((core_only)) && echo 'native + core AUR' || echo 'everything' )"
    if (( ! assume_yes )) && [[ -t 0 ]]; then
        read -rp $'\nContinue? [Y/n] ' reply
        [[ -z "$reply" || "$reply" =~ ^[Yy] ]] || exit 0
    fi

    if (( ! no_system )); then
        sudo -v
        # Keep sudo alive for the long package builds.
        while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
    fi
}

enable_multilib() {
    # steam, wine and friends live in [multilib].
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        log "Enabling [multilib] in /etc/pacman.conf"
        sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    fi
}

hardware_packages() {
    local cpu
    cpu="$(grep -m1 '^vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}')"
    case "$cpu" in
        GenuineIntel) echo intel-ucode ;;
        AuthenticAMD) echo amd-ucode ;;
    esac
    local dev
    for dev in /sys/bus/pci/devices/*; do
        # NVIDIA vendor id + display controller class (0x03xxxx).
        if [[ "$(cat "$dev/vendor" 2>/dev/null)" == 0x10de && "$(cat "$dev/class" 2>/dev/null)" == 0x03* ]]; then
            read_list "$pkgdir/hardware-nvidia.txt"
            break
        fi
    done
    if grep -qsi 'asus' /sys/class/dmi/id/sys_vendor; then
        read_list "$pkgdir/hardware-asus.txt"
    fi
}

install_native_packages() {
    enable_multilib
    log "Syncing package databases and upgrading"
    # An install from an older ISO can have a stale keyring, which makes every
    # newer package fail with "signature ... is unknown trust".
    sudo pacman -Sy --noconfirm --needed archlinux-keyring
    sudo pacman -Su --noconfirm

    # Only ask pacman for packages the repos actually have, so one renamed or
    # dropped package doesn't abort the whole transaction.
    local available wanted=() missing=() pkg
    available="$(pacman -Slq; pacman -Sgq)"
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if grep -qxF -- "$pkg" <<<"$available"; then
            wanted+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done < <(read_list "$pkgdir/pacman-native.txt"; read_list "$pkgdir/extra-required.txt"; hardware_packages | grep -v '^supergfxctl$')

    log "Installing ${#wanted[@]} repo packages"
    if ! sudo pacman -S --needed --noconfirm "${wanted[@]}"; then
        warn "Bulk install failed; retrying one by one"
        for pkg in "${wanted[@]}"; do
            sudo pacman -S --needed --noconfirm "$pkg" >/dev/null 2>&1 || failed+=("$pkg")
        done
    fi
    # Anything not in the repos is probably in the AUR now.
    printf '%s\n' "${missing[@]}" > "${TMPDIR:-/tmp}/restore-repo-missing.$$"
}

aur_helper=""
ensure_aur_helper() {
    if have paru; then aur_helper=paru; return; fi
    if have yay; then aur_helper=yay; return; fi

    log "Installing yay (AUR helper)"
    sudo pacman -S --needed --noconfirm git base-devel
    local tmp
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    aur_helper=yay
}

aur_install() {
    local flags=(-S --needed --noconfirm)
    if [[ "$aur_helper" == paru ]]; then
        flags+=(--skipreview)
    else
        flags+=(--answerdiff None --answerclean None --answeredit None --removemake)
    fi
    # ninja/meson ignore MAKEFLAGS but size their job count from the CPUs
    # they can see, so pin the build to as many CPUs as we want jobs.
    local cpus="${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}"
    (( cpus > $(nproc) )) && cpus="$(nproc)"
    taskset -c "0-$(( cpus - 1 ))" "$aur_helper" "${flags[@]}" "$@"
}

# True if the package, or the repo version a -git package replaces (e.g.
# quickshell for quickshell-git, often pulled in as a dependency), is installed.
already_provided() {
    pacman -Qq "$1" >/dev/null 2>&1 || pacman -Qq "${1%-git}" >/dev/null 2>&1
}

# Parallel C++ builds (quickshell's precompiled headers especially) need ~3 GB
# per job; one job per core runs a 16 GB laptop out of memory.
limit_build_jobs() {
    local mem_kb cg jobs cores
    mem_kb="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)"
    cg="$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo max)"
    [[ "$cg" =~ ^[0-9]+$ ]] && (( cg / 1024 < mem_kb )) && mem_kb=$(( cg / 1024 ))
    cores="$(nproc)"
    jobs=$(( mem_kb / (3 * 1024 * 1024) ))
    (( jobs > cores )) && jobs=$cores
    (( jobs < 1 )) && jobs=1
    jobs="${BUILD_JOBS:-$jobs}"
    export MAKEFLAGS="-j$jobs" CMAKE_BUILD_PARALLEL_LEVEL="$jobs"
    echo "  building with $jobs parallel jobs"
}

install_aur_packages() {
    ensure_aur_helper
    limit_build_jobs

    log "Installing desktop-critical AUR packages"
    local pkg
    for pkg in "${aur_core[@]}"; do
        already_provided "$pkg" && continue
        aur_install "$pkg" || failed+=("$pkg (CORE)")
    done

    (( core_only )) && return 0

    log "Installing remaining AUR packages (failures are collected, not fatal)"
    local missing_file="${TMPDIR:-/tmp}/restore-repo-missing.$$"
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ " ${aur_core[*]} " == *" $pkg "* ]] && continue
        already_provided "$pkg" && continue
        aur_install "$pkg" || failed+=("$pkg")
    done < <(read_list "$pkgdir/aur.txt"; cat "$missing_file" 2>/dev/null; hardware_packages | grep -x supergfxctl || true)
    rm -f "$missing_file"
}

install_flatpaks() {
    (( core_only )) && return 0
    [[ -s "$pkgdir/flatpak.txt" ]] || return 0
    have flatpak || sudo pacman -S --needed --noconfirm flatpak

    log "Installing Flatpak apps"
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    local app
    while IFS= read -r app; do
        flatpak install -y --noninteractive flathub "$app" || failed+=("flatpak:$app")
    done < <(read_list "$pkgdir/flatpak.txt")
}

restore_dotfiles() {
    log "Restoring ~/.config"
    local config_paths=(
        btop cava easyeffects fastfetch fcitx5 gtk-3.0 gtk-4.0 hypr kitty mpd
        mpv nautilus nvim nwg-look quickshell ranger rofi swaync systemd wal
        waybar wlogout xfce4 xsettingsd starship.toml mimeapps.list user-dirs.dirs
    )
    mkdir -p "$HOME/.config"
    local rel
    for rel in "${config_paths[@]}"; do
        restore "$repo_root/$rel" "$HOME/.config/$rel"
        fix_home_paths "$HOME/.config/$rel"
    done
    # Machine-local leftovers that should never be restored.
    rm -f "$HOME/.config/hypr/modules/"*.bak "$HOME/.config/hypr/"*-card
    find "$HOME/.config/systemd/user" -maxdepth 1 -name '*.wants' -type d -exec rm -rf {} + 2>/dev/null || true

    log "Restoring home dotfiles"
    local file name
    for file in "$boot"/home-dotfiles/.*; do
        [[ -f "$file" ]] || continue
        name="$(basename "$file")"
        if [[ "$name" == ".gitconfig.example" ]]; then
            [[ -e "$HOME/.gitconfig" ]] || cp "$file" "$HOME/.gitconfig"
            continue
        fi
        restore "$file" "$HOME/$name"
        fix_home_paths "$HOME/$name"
    done

    mkdir -p "$HOME/.config/shell"
    [[ -e "$HOME/.config/shell/private.env" ]] || install -m 600 /dev/null "$HOME/.config/shell/private.env"
}

restore_local_files() {
    log "Restoring ~/.local helpers, startpage, lockscreen, wallpapers"
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share"
    local file dst
    for file in "$boot"/local-bin/*; do
        [[ -f "$file" ]] || continue
        dst="$HOME/.local/bin/$(basename "$file")"
        restore "$file" "$dst"
        chmod +x "$dst"
        fix_home_paths "$dst"
    done

    restore "$boot/local-share/startpage" "$HOME/.local/share/startpage"
    fix_home_paths "$HOME/.local/share/startpage"

    # qylock: quickshell lockscreen (Super+L) + its themes, also used by SDDM.
    local qylock="$HOME/QyLock/qylock"
    if [[ ! -d "$qylock/.git" ]]; then
        mkdir -p "$(dirname "$qylock")"
        git clone --depth 1 https://github.com/Darkkal44/qylock.git "$qylock" || failed+=("qylock clone")
    fi
    restore "$boot/local-share/quickshell-lockscreen" "$HOME/.local/share/quickshell-lockscreen"
    ln -sfn "$qylock/themes" "$HOME/.local/share/quickshell-lockscreen/themes_link"

    mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots"
    cp -an "$boot/wallpapers/." "$HOME/Pictures/Wallpapers/"
}

# Clone an upstream repo at the snapshot's base commit and apply local edits.
clone_and_patch() {
    local url="$1" dst="$2" base_file="$3" patch="$4"
    if [[ ! -d "$dst/.git" ]]; then
        backup_path "$dst"
        rm -rf "$dst"
        git clone "$url" "$dst"
        if [[ -s "$base_file" ]]; then
            git -C "$dst" checkout -q "$(cat "$base_file")" 2>/dev/null \
                || warn "base commit for $dst not found; patching upstream HEAD"
        fi
    fi
    if [[ -s "$patch" ]]; then
        if git -C "$dst" apply --check "$patch" 2>/dev/null; then
            git -C "$dst" apply --whitespace=nowarn "$patch"
        elif git -C "$dst" apply --reverse --check "$patch" 2>/dev/null; then
            : # already applied
        else
            warn "$(basename "$patch") did not apply cleanly to $dst"
            failed+=("$(basename "$patch")")
        fi
    fi
}

restore_rofi() {
    log "Restoring adi1090x rofi launchers (~/rofi)"
    clone_and_patch https://github.com/adi1090x/rofi.git "$HOME/rofi" \
        "$boot/rofi.base" "$boot/rofi.patch" || failed+=("rofi clone")
    fix_home_paths "$HOME/rofi/files/launchers/type-6"
}

restore_caffyne_shell() {
    log "Restoring caffyne-shell (alternate bar) with local patch"
    local dst="$HOME/.config/caffyne-shell"
    clone_and_patch https://github.com/caffyne-org/caffyne-shell.git "$dst" \
        "$boot/caffyne-shell.base" "$boot/caffyne-shell.patch" || { failed+=("caffyne-shell clone"); return 0; }
    [[ ! -d "$boot/caffyne-shell-overlay" ]] || cp -a "$boot"/caffyne-shell-overlay/. "$dst"/
    fix_home_paths "$dst"

    if [[ -f "$dst/requirements.txt" && ! -x "$dst/venv/bin/python" ]]; then
        python3 -m venv --system-site-packages "$dst/venv" \
            && "$dst/venv/bin/pip" install -q -r "$dst/requirements.txt" \
            || failed+=("caffyne-shell venv")
    fi

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

# Hyprland is pinned to this laptop's Intel+NVIDIA cards through symlinks that
# can't be committed. Recreate them for the new machine, or drop the pin.
configure_gpu() {
    log "Configuring Hyprland GPU selection"
    local env_conf="$HOME/.config/hypr/modules/environment.conf"
    local intel="" nvidia="" card vendor
    for card in /sys/class/drm/card[0-9]; do
        [[ -e "$card/device/vendor" ]] || continue
        vendor="$(cat "$card/device/vendor")"
        local by_path
        by_path="$(find /dev/dri/by-path -lname "*/$(basename "$card")" 2>/dev/null | head -n1)"
        [[ -n "$by_path" ]] || continue
        case "$vendor" in
            0x8086) intel="$by_path" ;;
            0x10de) nvidia="$by_path" ;;
        esac
    done

    if [[ -n "$intel" && -n "$nvidia" ]]; then
        ln -sfn "$intel" "$HOME/.config/hypr/intel-card"
        ln -sfn "$nvidia" "$HOME/.config/hypr/nvidia-card"
        echo "  Intel + NVIDIA found; keeping AQ_DRM_DEVICES (NVIDIA first)."
    else
        sed -i 's|^env = AQ_DRM_DEVICES|# (disabled by install.sh: no Intel+NVIDIA pair) env = AQ_DRM_DEVICES|' "$env_conf"
        echo "  No Intel+NVIDIA pair; letting Hyprland pick the GPU."
    fi

    # The NVIDIA proprietary driver needs DRM modesetting for Wayland.
    if [[ -n "$nvidia" ]] && (( ! no_system )); then
        echo 'options nvidia_drm modeset=1 fbdev=1' | sudo tee /etc/modprobe.d/nvidia-drm.conf >/dev/null
    fi
}

configure_system() {
    log "Restoring system config (/etc)"
    local f
    while IFS= read -r -d '' f; do
        sudo install -D -m 644 "$f" "/etc/${f#"$boot"/etc/}"
    done < <(find "$boot/etc" -type f -print0)

    # SDDM theme referenced by /etc/sddm.conf.d/theme.conf comes from qylock.
    local theme
    theme="$(awk -F= '/^Current=/{print $2}' "$boot/etc/sddm.conf.d/theme.conf" 2>/dev/null)"
    if [[ -n "$theme" && -d "$HOME/QyLock/qylock/themes/$theme" ]]; then
        sudo mkdir -p /usr/share/sddm/themes
        sudo cp -r "$HOME/QyLock/qylock/themes/$theme" /usr/share/sddm/themes/
        [[ -d "$HOME/QyLock/qylock/themes/tui-fonts" ]] && sudo cp -r "$HOME/QyLock/qylock/themes/tui-fonts" /usr/share/sddm/themes/
    else
        warn "SDDM theme '$theme' not available; removing theme override"
        sudo rm -f /etc/sddm.conf.d/theme.conf
    fi

    log "Enabling system services"
    local services=(
        NetworkManager bluetooth sddm docker cups avahi-daemon
        power-profiles-daemon auto-cpufreq systemd-timesyncd fstrim.timer
        lm_sensors proton.VPN supergfxd
    )
    local svc
    for svc in "${services[@]}"; do
        if systemctl list-unit-files "$svc" "$svc.service" --no-legend 2>/dev/null | grep -q .; then
            sudo systemctl enable "$svc" >/dev/null 2>&1 || warn "could not enable $svc"
        fi
    done

    log "Adding $USER to groups"
    local group
    for group in docker wireshark vboxusers video input; do
        getent group "$group" >/dev/null && sudo usermod -aG "$group" "$USER"
    done
    return 0

    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != */zsh ]] && have zsh; then
        log "Setting zsh as login shell"
        sudo chsh -s "$(command -v zsh)" "$USER"
    fi
}

configure_user_session() {
    log "Generating initial colour scheme and theme settings"
    # Many configs import ~/.cache/wal/*; seed it from the first wallpaper so
    # the first login isn't unstyled. Super+W picks a different wallpaper.
    local wall
    wall="$(find "$HOME/Pictures/Wallpapers" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | sort | head -n1)"
    if [[ -n "$wall" ]]; then
        mkdir -p "$HOME/.cache/wallpaper-colors"
        echo "$wall" > "$HOME/.cache/wallpaper-colors/current"
        if have wal; then
            wal -q -n -s -t -e -i "$wall" >/dev/null 2>&1 || warn "pywal could not generate colours"
        fi
    fi

    if have gsettings; then
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme 'breeze' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-theme 'default' 2>/dev/null || true
    fi
    # Create the folders user-dirs.dirs points at, or xdg-user-dirs-update
    # resets them all to $HOME.
    local dir
    while IFS= read -r dir; do
        mkdir -p "${dir/\$HOME/$HOME}"
    done < <(sed -n 's/^XDG_[A-Z]*_DIR="\(.*\)"$/\1/p' "$HOME/.config/user-dirs.dirs" 2>/dev/null)
    have xdg-user-dirs-update && xdg-user-dirs-update || true

    have systemctl || return 0
    log "Enabling user services"
    # A running user manager exists on a normal login; fall back to plain
    # symlinks when there isn't one (e.g. installing over SSH or in a chroot).
    local svc units=(memguard.service mpd.service startpage-media.service startpage-stats.service)
    if systemctl --user daemon-reload 2>/dev/null; then
        for svc in "${units[@]}"; do
            systemctl --user enable "$svc" >/dev/null 2>&1 || warn "could not enable $svc"
        done
    else
        mkdir -p "$HOME/.config/systemd/user/default.target.wants"
        for svc in "${units[@]}"; do
            local unit="$HOME/.config/systemd/user/$svc"
            [[ -f "$unit" ]] || unit="/usr/lib/systemd/user/$svc"
            [[ -f "$unit" ]] && ln -sfn "$unit" "$HOME/.config/systemd/user/default.target.wants/$svc"
        done
        return 0
    fi
}

summary() {
    log "Done"
    [[ -d "$backup_dir" ]] && echo "  Previous files were backed up to $backup_dir"
    if (( ${#failed[@]} )); then
        warn "these items failed and need a manual look:"
        printf '    - %s\n' "${failed[@]}"
    fi
    cat <<EOF

  Next steps:
    * Reboot, then log in to Hyprland from SDDM.
    * Put API keys / private exports in ~/.config/shell/private.env
    * Edit ~/.gitconfig with your name/email.
    * Monitor layout lives in ~/.config/hypr/modules/monitors.conf
      (it targets the original laptop's screens; unknown screens fall back
      to auto placement).
EOF
}

main() {
    preflight
    if (( ! skip_packages )); then
        install_native_packages
        install_aur_packages
        install_flatpaks
    fi
    restore_dotfiles
    restore_local_files
    restore_rofi
    restore_caffyne_shell
    configure_gpu
    (( no_system )) || configure_system
    configure_user_session
    summary
    (( ${#failed[@]} == 0 ))
}

main "$@"
