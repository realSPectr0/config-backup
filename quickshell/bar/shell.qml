import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "."

ShellRoot {
    id: root

    property string openPopup: ""
    property real   popupCenterX: 960

    // ── Palette — single source of truth for bar + all popups ────────────────
    property color cBg:     "#080c12"
    property color cPill:   "#0e1828"
    property color cBord:   "#1d3450"
    property color cFg:     "#8ba4bc"
    property color cBtnFg:  "#d8e6f2"
    property color cDim:    "#415a75"
    property color cAccent: "#7c8ef0"
    property color cBlue:   "#5ba8d4"
    readonly property color cRed:    "#f87171"
    readonly property color cGreen:  "#86efac"
    readonly property color cYellow: "#fbbf24"
    readonly property string cFont:  "JetBrainsMono Nerd Font"
    readonly property int barHeight: 44
    readonly property int outerGap: 5
    readonly property int windowGap: 0

    // Popup surfaces: slightly darker than pill for layered depth
    readonly property color cPopupBg:   Qt.darker(root.cPill, 1.18)
    readonly property color cPopupCard: root.cPill

    // ── Wallpaper / theme derivation ─────────────────────────────────────────
    property string _lastWallpaper: ""

    Timer {
        interval: 8000; repeat: true; running: true
        onTriggered: { wallpaperPollProc.running = false; wallpaperPollProc.running = true }
    }

    Process {
        id: wallpaperPollProc
        command: ["bash", "-c", "cat ~/.cache/wallpaper-colors/current 2>/dev/null | tr -d '\\n'"]
        stdout: SplitParser {
            onRead: d => {
                const wp = d.trim()
                if (wp.length > 0 && wp !== root._lastWallpaper) {
                    root._lastWallpaper = wp
                    themeGenProc.running = false
                    themeGenProc.running = true
                }
            }
        }
    }

    Process {
        id: themeGenProc
        command: ["python3", "/home/arch/.config/quickshell/bar/derive-theme.py"]
        stdout: SplitParser {
            onRead: d => {
                try {
                    const t = JSON.parse(d.trim())
                    if (t.cBg)     root.cBg     = t.cBg
                    if (t.cPill)   root.cPill   = t.cPill
                    if (t.cBord)   root.cBord   = t.cBord
                    if (t.cFg)     root.cFg     = t.cFg
                    if (t.cBtnFg)  root.cBtnFg  = t.cBtnFg
                    if (t.cDim)    root.cDim    = t.cDim
                    if (t.cAccent) root.cAccent = t.cAccent
                    if (t.cBlue)   root.cBlue   = t.cBlue
                } catch(e) {}
            }
        }
    }

    Component.onCompleted: wallpaperPollProc.running = true

    // ── Popup toggle ─────────────────────────────────────────────────────────
    function togglePopup(name, centerX) {
        if (openPopup === name && Math.abs(popupCenterX - centerX) < 2) {
            openPopup = ""; return
        }
        popupCenterX = centerX
        openPopup = name
    }

    IpcHandler {
        target: "qs-bar-notifications"

        function open(): string {
            root.popupCenterX = 99999
            root.openPopup = "notifications"
            return "NOTIFICATIONS_OPEN"
        }

        function notifications(): string {
            root.popupCenterX = 99999
            notificationsPopup.showTab(0)
            root.openPopup = "notifications"
            return "NOTIFICATIONS_TAB"
        }

        function clipboard(): string {
            root.popupCenterX = 99999
            notificationsPopup.showTab(1)
            root.openPopup = "notifications"
            return "CLIPBOARD_TAB"
        }

        function screenshots(): string {
            root.popupCenterX = 99999
            notificationsPopup.showTab(2)
            root.openPopup = "notifications"
            return "SCREENSHOTS_TAB"
        }

        function close(): string {
            if (root.openPopup === "notifications")
                root.openPopup = ""
            return "NOTIFICATIONS_CLOSE"
        }

        function toggle(): string {
            root.popupCenterX = 99999
            root.openPopup = root.openPopup === "notifications" ? "" : "notifications"
            return "NOTIFICATIONS_TOGGLE"
        }
    }

    // ── Bar ──────────────────────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        delegate: Bar {
            required property var modelData

            screen: modelData
            openPopup: root.openPopup
            notificationCount: notificationsPopup.unreadCount
            notificationsDnd: notificationsPopup.dnd
            onRequestPopup: (name, centerX) => root.togglePopup(name, centerX)
            onRequestDismissPopup: root.openPopup = ""
            cBg: root.cBg;     cPill:   root.cPill;   cBord:   root.cBord
            cFg: root.cFg;     cBtnFg:  root.cBtnFg;  cDim:    root.cDim
            cAccent: root.cAccent;      cBlue: root.cBlue
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: ClickAwayLayer {
            required property var modelData

            screen: modelData
            active: root.openPopup.length > 0
            onClickedAway: root.openPopup = ""
        }
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            if (root.openPopup.length > 0)
                root.openPopup = ""
        }
    }

    // ── Popups ───────────────────────────────────────────────────────────────
    VolumePopup {
        showing: root.openPopup === "volume";  anchorCenterX: root.popupCenterX
        onDismissRequested: root.openPopup = ""
        cBg: root.cPopupBg; cCard: root.cPopupCard; cBord: root.cBord
        cFg: root.cBtnFg;   cDim:  root.cFg;        cAccent: root.cAccent
    }

    NetworkPopup {
        showing: root.openPopup === "network"; anchorCenterX: root.popupCenterX
        onDismissRequested: root.openPopup = ""
        onBluetoothRequested: root.openPopup = "bluetooth"
        cBg: root.cPopupBg; cCard: root.cPopupCard; cBord: root.cBord
        cFg: root.cBtnFg;   cDim:  root.cFg;        cAccent: root.cAccent
    }

    BluetoothPopup {
        showing: root.openPopup === "bluetooth"; anchorCenterX: root.popupCenterX
        onDismissRequested: root.openPopup = ""
        onNetworkRequested: root.openPopup = "network"
        cBg: root.cPopupBg; cCard: root.cPopupCard; cBord: root.cBord
        cFg: root.cBtnFg;   cDim:  root.cFg;        cAccent: root.cAccent
    }

    WeatherPopup {
        showing: root.openPopup === "weather"; anchorCenterX: root.popupCenterX
        onDismissRequested: root.openPopup = ""
        cBg: root.cPopupBg; cCard: root.cPopupCard; cBord: root.cBord
        cFg: root.cBtnFg;   cDim:  root.cFg;        cAccent: root.cAccent
    }

    MediaPopup {
        showing: root.openPopup === "media"; anchorCenterX: root.popupCenterX
        onDismissRequested: root.openPopup = ""
        cBg: root.cBg;      cCard: root.cPill;      cBord: root.cBord
        cFg: root.cBtnFg;   cDim:  root.cFg;        cAccent: root.cAccent
        cBlue: root.cBlue;  cGreen: root.cGreen;    cYellow: root.cYellow; cRed: root.cRed
    }

    NotificationsPopup {
        id: notificationsPopup
        showing: root.openPopup === "notifications"; anchorCenterX: root.popupCenterX
        onDismissRequested: root.openPopup = ""
        onNotificationReceived: item => notificationToast.addToast(item)
        cBg: root.cBg;      cCard: root.cPill;      cBord: root.cBord
        cFg: root.cBtnFg;   cDim:  root.cFg;        cAccent: root.cAccent
        cBlue: root.cBlue;  cGreen: root.cGreen;    cYellow: root.cYellow; cRed: root.cRed
    }

    NotificationToast {
        id: notificationToast
        cBg: root.cBg;      cCard: root.cPill;      cBord: root.cBord
        cFg: root.cBtnFg;   cDim:  root.cFg;        cAccent: root.cAccent; cRed: root.cRed
    }

    BatteryPopup {
        showing: root.openPopup === "battery"; anchorCenterX: root.popupCenterX
        onDismissRequested: root.openPopup = ""
        cBg: root.cPopupBg; cCard: root.cPopupCard; cBord: root.cBord
        cFg: root.cBtnFg;   cDim:  root.cFg;        cAccent: root.cAccent
    }

    ClockPopup {
        showing: root.openPopup === "clock";   anchorCenterX: root.popupCenterX
        onDismissRequested: root.openPopup = ""
        cBg: root.cPopupBg; cCard: root.cPopupCard; cBord: root.cBord
        cFg: root.cBtnFg;   cDim:  root.cFg;        cAccent: root.cAccent
    }

    PowerPopup {
        showing: root.openPopup === "power";   anchorCenterX: root.popupCenterX
        onDismissRequested: root.openPopup = ""
        cBg: root.cPopupBg; cCard: root.cPopupCard; cBord: root.cBord
        cFg: root.cBtnFg;   cDim:  root.cFg;        cAccent: root.cAccent
    }

    TempPopup {
        showing: root.openPopup === "temp";    anchorCenterX: root.popupCenterX
        onDismissRequested: root.openPopup = ""
        cBg: root.cPopupBg; cCard: root.cPopupCard; cBord: root.cBord
        cFg: root.cBtnFg;   cDim:  root.cFg;        cAccent: root.cAccent
    }
}
