import Quickshell
import Quickshell.Io
import "components" as C

ShellRoot {
  id: root

  C.WallpaperPicker {
    id: wallpaperPicker
  }

  FileView {
    path: "file:///tmp/qs-wallpaper-picker"
    watchChanges: true
    onFileChanged: {
      wallpaperPicker.showing = !wallpaperPicker.showing
    }
  }
}
