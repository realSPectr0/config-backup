# config-backup

Personal Arch/Hyprland desktop backup: Hyprland, waybar, quickshell, rofi,
swaync, wlogout, kitty, fastfetch, cava, nvim, fcitx5, systemd user services,
package manifests, and everything needed to rebuild the desktop on a new
machine.

## Restore on a new Arch machine

Start from a fresh Arch install with a normal user that can `sudo`, then:

```bash
sudo pacman -S --needed git
git clone https://github.com/realSPectr0/config-backup.git ~/.config-restore
~/.config-restore/bootstrap/install.sh
```

Run it as your user, not root. Options:

| flag              | effect                                                    |
|-------------------|-----------------------------------------------------------|
| `--core-only`     | repo packages + desktop-critical AUR only (much faster)   |
| `--skip-packages` | restore files and services only                           |
| `--no-system`     | no sudo at all (no packages, `/etc`, services)            |
| `-y`              | don't ask before starting                                 |

What it does:

1. Enables `[multilib]`, installs every repo package from the manifests, plus
   NVIDIA / ASUS / CPU-microcode packages only if that hardware is present.
2. Installs `yay` if needed, then the AUR packages (core desktop ones first;
   any other failures are listed at the end instead of aborting).
3. Installs the Flatpak apps.
4. Restores `~/.config`, home dotfiles, `~/.local/bin` helpers, the startpage,
   the qylock lockscreen + SDDM theme, wallpapers, the patched adi1090x rofi
   launchers (`~/rofi`) and the patched caffyne-shell.
5. Rewrites hardcoded `/home/arch` paths if your username differs.
6. Re-pins Hyprland to the Intel+NVIDIA GPUs if both exist, otherwise removes
   the pin so Hyprland can start on any GPU.
7. Restores `/etc` bits (NetworkManager iwd backend, SDDM theme, zram),
   enables system and user services, adds you to `docker`/`wireshark`/... and
   sets zsh as your shell.
8. Seeds pywal colours from the first wallpaper so the first login is themed.

Anything replaced is backed up to `~/.config-backup-before-restore/<timestamp>`.
Reboot when it finishes.

## Updating the backup (on the main machine)

```bash
cd ~/.config
./bootstrap/snapshot.sh   # refresh packages, patches, helpers, wallpapers, /etc
git add -A && git commit -m "Update backup" && git push
```

## Layout

- `bootstrap/install.sh`, `bootstrap/snapshot.sh`: restore / refresh.
- `bootstrap/packages/`: `pacman-native.txt`, `aur.txt`, `flatpak.txt`,
  `extra-required.txt` (deps the configs rely on), `hardware-*.txt`.
- `bootstrap/home-dotfiles/`: sanitized shell/GTK dotfiles.
- `bootstrap/local-bin/`, `bootstrap/local-share/`: `~/.local` content.
- `bootstrap/wallpapers/`: `~/Pictures/Wallpapers`.
- `bootstrap/etc/`: system config files.
- `bootstrap/*.patch` + `*.base`: local edits over upstream caffyne-shell and
  adi1090x/rofi, applied on top of the recorded upstream commit.

## Private state

Secrets are intentionally not committed (`.zshrc` here is a sanitized copy).
Put API keys or private exports in `~/.config/shell/private.env`; the restored
`.zshrc` sources it if it exists.
