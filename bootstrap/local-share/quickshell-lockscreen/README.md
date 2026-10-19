# Quickshell Lockscreen Theme Adaptation

You can now use your SDDM themes as a lockscreen using Quickshell. All animations, backgrounds (including videos), and visual elements are preserved exactly as they are in SDDM.

## Project Structure

The project is located in `/home/achlys/sddm-themes/QuickShell`.

- **`shell.qml`**: The main entry point for the lockscreen.
- **`shim/`**: Contains `SddmShim.qml`, which emulates SDDM's global objects and handles authentication via PAM.
- **`imports/`**: Compatibility shims for `QtGraphicalEffects`, `QtMultimedia`, and `SddmComponents` to ensure SDDM themes work in the Quickshell environment.
- **`themes_link`**: A symbolic link to your original SDDM themes directory.
- **`lock.sh`**: Script to actually lock your screen with a chosen theme.
- **`run.sh`**: Script to test themes in a window without locking the session.

## Usage

### Testing a theme
To see how a theme looks and works without locking yourself out, use the `run.sh` script:

```bash
cd /home/achlys/sddm-themes/QuickShell
./run.sh Genshin
./run.sh cyberpunk
./run.sh nier-automata
```

### Locking the screen
To actually lock your screen, use the `lock.sh` script:

```bash
cd /home/achlys/sddm-themes/QuickShell
./lock.sh Genshin
```

> [!TIP]
> You can bind `./lock.sh` to a keyboard shortcut in your Qtile config to replace your current locker.

## How it works
1. **The Shim**: `SddmShim.qml` creates mock versions of `sddm`, `config`, `userModel`, and `sessionModel`. This allows the original SDDM `Main.qml` files to load without modification.
2. **PAM Integration**: When you "Login" in the theme, it actually calls a PAM context in Quickshell to verify your password against the system.
3. **Multi-screen support**: It uses Quickshell's `Variants` to automatically spawn the theme window on all connected monitors.
4. **Preserved Assets**: The `Loader` correctly resolves paths for background images, videos, and custom fonts within the theme folders.

## Compatibility
Supported modules (shimmed):
- `QtGraphicalEffects 1.15` (mapped to `Qt5Compat` in Qt6)
- `QtMultimedia 5.15` (mapped to Qt6 Multimedia with proxies for `MediaPlayer` and `VideoOutput`)
- `SddmComponents 2.0` (provides `TextConstants` and `LayoutMirroring`)
