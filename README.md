# config-backup

Personal Arch/Hyprland desktop backup for this machine: Hyprland, quickshell,
waybar, rofi, swaync, wlogout, kitty, fastfetch, cava, nvim, fcitx5, systemd
user services, package manifests, and a restore path for the local caffyne-shell
customization.

## Restore on a new Arch machine

```bash
git clone https://github.com/realSPectr0/config-backup.git ~/.config-restore
cd ~/.config-restore
./bootstrap/install.sh
```

The installer backs up any existing destination paths into
`~/.config-backup-before-restore/<timestamp>` before copying files.

## What is included

- `bootstrap/packages/pacman-native.txt`: native repo package manifest.
- `bootstrap/packages/aur.txt`: AUR/foreign package manifest.
- `bootstrap/packages/flatpak.txt`: Flatpak app manifest.
- `bootstrap/home-dotfiles/`: sanitized home-level shell files.
- `bootstrap/local-bin/`: small local helper scripts.
- `bootstrap/local-share/startpage/`: the local startpage used by the user
  services.
- `bootstrap/caffyne-shell.patch`: local edits over upstream caffyne-shell.
- `bootstrap/caffyne-shell-overlay/`: local caffyne-shell files that are not in
  upstream Git.

## Private state

Secrets and machine-local state are intentionally not committed. Put API keys or
private exports in:

```bash
~/.config/shell/private.env
```

The restored `.zshrc` sources that file if it exists.
