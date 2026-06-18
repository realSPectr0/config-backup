import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar

    signal requestPopup(string name, real centerX)
    signal requestDismissPopup()
    property string openPopup: ""
    property int notificationCount: 0
    property bool notificationsDnd: false

    // ── Palette (mutable — auto-updated from wallpaper) ──────────────────────
    property color cBg:     "#080c12"
    property color cPill:   "#0e1828"
    property color cBord:   "#1d3450"
    property color cFg:     "#8ba4bc"
    property color cBtnFg:  "#d8e6f2"
    property color cDim:    "#415a75"
    property color cAccent: "#7c8ef0"
    property color cBlue:   "#5ba8d4"
    // Status semantic colors — kept fixed for legibility
    readonly property color cRed:    "#f87171"
    readonly property color cGreen:  "#86efac"
    readonly property color cYellow: "#fbbf24"
    readonly property string cFont:  "JetBrainsMono Nerd Font"
    readonly property int barHeight: 44
    readonly property int outerGap: 5
    readonly property int windowGap: 0
    readonly property int windowSideGap: 12
    readonly property int sideGroupPadding: 6
    readonly property int sideContentMargin: Math.max(0, windowSideGap - outerGap - sideGroupPadding)

    function popupCenterFor(item) {
        const point = item.mapToItem(null, item.width / 2, 0)
        return bar.outerGap + point.x
    }

    function showPopup(name, item) {
        bar.requestPopup(name, popupCenterFor(item))
    }

    function dismissPopup() {
        if (bar.openPopup.length > 0)
            bar.requestDismissPopup()
    }

    function addWorkspaceId(ids, id) {
        if (id > 0 && id <= 10 && ids.indexOf(id) === -1)
            ids.push(id)
    }

    function buildWorkspaceIds() {
        const ids = [1, 2, 3, 4, 5]
        addWorkspaceId(ids, bar.activeWorkspaceId)

        const workspaces = Hyprland.workspaces?.values || []
        for (let i = 0; i < workspaces.length; i++) {
            const ws = workspaces[i]
            const id = ws?.id ?? 0
            if (bar.workspaceOccupied(id) || ws?.focused || ws?.urgent)
                addWorkspaceId(ids, id)
        }

        return ids.sort((a, b) => a - b)
    }

    function workspaceById(id) {
        const workspaces = Hyprland.workspaces?.values || []
        for (let i = 0; i < workspaces.length; i++) {
            if (workspaces[i]?.id === id)
                return workspaces[i]
        }
        return null
    }

    function workspaceOccupied(id) {
        const ws = workspaceById(id)
        return (ws?.toplevels?.values || []).length > 0
    }

    function workspaceUrgent(id) {
        return workspaceById(id)?.urgent ?? false
    }

    function switchWorkspace(id) {
        Hyprland.dispatch("workspace " + id)
    }

    function normalizeAppName(value) {
        return (value ?? "").toString().trim().toLowerCase()
    }

    function appIconFor(name) {
        const app = bar.normalizeAppName(name)
        if (app.includes("firefox") || app.includes("librewolf") || app.includes("zen"))
            return "󰈹"
        if (app.includes("code") || app.includes("vscode") || app.includes("codium"))
            return "󰨞"
        if (app.includes("kitty") || app.includes("alacritty") || app.includes("wezterm") || app.includes("terminal") || app.includes("konsole"))
            return ""
        if (app.includes("discord"))
            return "󰙯"
        if (app.includes("steam"))
            return "󰓓"
        if (app.includes("spotify"))
            return "󰓇"
        if (app.includes("thunar") || app.includes("nautilus") || app.includes("dolphin") || app.includes("files"))
            return "󰉋"
        if (app.includes("obs"))
            return "󰻃"
        if (app.includes("vlc") || app.includes("mpv"))
            return "󰕼"
        if (app.includes("telegram"))
            return "󰍡"
        if (app.includes("vesktop"))
            return "󰙯"
        return "󰣆"
    }

    function updateWorkspaceLabel() {
        bar.workspace = Hyprland.focusedWorkspace?.name
            ?? Hyprland.focusedMonitor?.activeWorkspace?.name
            ?? "—"
    }

    // ── State ────────────────────────────────────────────────────────────────
    property string netLabel:    "..."
    property string cpuTemp:     "—"
    property string clockSec:    "12:00 AM"
    property bool   recording:   false
    property int    volPct:      0
    property int    batPct:      0
    property bool   batCharging: false
    property bool   micMuted:    false
    property string btState:     "unknown"
    property int    btCount:     0
    property string btLabel:     ""
    property int    winCount:    0
    property string activeAppClass: "—"
    property string activeAppTitle: "—"
    property string workspace:   "—"
    property string weatherTemp: "—"
    property string weatherIcon: "󰖐"
    readonly property int activeWorkspaceId: Hyprland.focusedWorkspace?.id ?? 1
    readonly property var workspaceIds: buildWorkspaceIds()

    // ── Window ───────────────────────────────────────────────────────────────
    anchors { top: true; left: true; right: true }
    margins { top: bar.outerGap; left: bar.outerGap; right: bar.outerGap }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: bar.outerGap + bar.barHeight + bar.windowGap
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-bar"
    implicitHeight: bar.barHeight
    color: "transparent"

    // ────────────────────────────────────────────────────────────────────────
    // Data sources
    // ────────────────────────────────────────────────────────────────────────

    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: { clockProc.running = false; clockProc.running = true }
        Component.onCompleted: { clockProc.running = true }
    }
    Process {
        id: clockProc
        command: ["bash", "-c", "TZ=America/Los_Angeles date '+%-I:%M %p'"]
        stdout: SplitParser { onRead: d => bar.clockSec = d.trim() }
    }

    Timer {
        interval: 5000; repeat: true; running: true
        onTriggered: { netProc.running = false; netProc.running = true }
        Component.onCompleted: { netProc.running = true }
    }
    Process {
        id: netProc
        command: ["python3", "/home/arch/.config/quickshell/bar/scripts/wifi-nmcli.py", "bar"]
        stdout: SplitParser { onRead: d => bar.netLabel = d.trim() }
    }

    Timer {
        interval: 3000; repeat: true; running: true
        onTriggered: { tempProc.running = false; tempProc.running = true }
        Component.onCompleted: { tempProc.running = true }
    }
    Process {
        id: tempProc
        command: ["bash", "-c", "awk '{printf \"%.0f°C\",$1/1000}' /sys/class/thermal/thermal_zone4/temp 2>/dev/null || echo '—'"]
        stdout: SplitParser { onRead: d => bar.cpuTemp = d.trim() }
    }

    Timer {
        interval: 2000; repeat: true; running: true
        onTriggered: { volProc.running = false; volProc.running = true; micProc.running = false; micProc.running = true }
        Component.onCompleted: { volProc.running = true; micProc.running = true }
    }
    Process {
        id: volProc
        command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\\d+(?=%)' | head -1 || echo 0"]
        stdout: SplitParser { onRead: d => bar.volPct = parseInt(d.trim()) || 0 }
    }
    Process {
        id: micProc
        command: ["bash", "-c", "pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | grep -c yes || echo 0"]
        stdout: SplitParser { onRead: d => bar.micMuted = d.trim() === "1" }
    }

    Timer {
        interval: 6000; repeat: true; running: true
        onTriggered: { btProc.running = false; btProc.running = true }
        Component.onCompleted: { btProc.running = true }
    }
    Process {
        id: btProc
        command: ["python3", "/home/arch/.config/quickshell/bar/scripts/bluetoothctl-helper.py", "bar"]
        stdout: SplitParser {
            onRead: d => {
                const parts = d.trim().split("|")
                bar.btState = parts[0] && parts[0].length > 0 ? parts[0] : "unknown"
                bar.btCount = parseInt(parts[1]) || 0
                bar.btLabel = parts[2] || ""
            }
        }
    }

    Timer {
        interval: 10000; repeat: true; running: true
        onTriggered: { batCapProc.running = false; batCapProc.running = true; batStatusProc.running = false; batStatusProc.running = true }
        Component.onCompleted: { batCapProc.running = true; batStatusProc.running = true }
    }
    Process {
        id: batCapProc
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0"]
        stdout: SplitParser { onRead: d => bar.batPct = parseInt(d.trim()) || 0 }
    }
    Process {
        id: batStatusProc
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Unknown"]
        stdout: SplitParser { onRead: d => bar.batCharging = d.trim() === "Charging" }
    }

    Timer {
        interval: 2000; repeat: true; running: true
        onTriggered: { recProc.running = false; recProc.running = true; winProc.running = false; winProc.running = true }
        Component.onCompleted: { recProc.running = true; winProc.running = true }
    }
    Process {
        id: recProc
        command: ["bash", "-c", "pgrep -x gpu-screen-recorder >/dev/null && echo rec || echo idle"]
        stdout: SplitParser { onRead: d => bar.recording = d.trim() === "rec" }
    }
    Process {
        id: winProc
        command: ["bash", "-c", "hyprctl clients -j | python3 -c \"import sys,json;print(len(json.load(sys.stdin)))\""]
        stdout: SplitParser { onRead: d => bar.winCount = parseInt(d.trim()) || 0 }
    }

    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: { appProc.running = false; appProc.running = true }
        Component.onCompleted: { appProc.running = true }
    }
    Process {
        id: appProc
        command: ["bash", "-c",
            "hyprctl activewindow -j | python3 -c \"" +
            "import sys,json;" +
            "data=json.load(sys.stdin);" +
            "cls=(data.get('class') or data.get('initialClass') or '—').strip();" +
            "title=(data.get('title') or '—').strip();" +
            "print(cls + '|' + title)\""]
        stdout: SplitParser { onRead: d => {
            const parts = d.trim().split("|")
            bar.activeAppClass = parts[0] && parts[0].length > 0 ? parts[0] : "—"
            bar.activeAppTitle = parts[1] && parts[1].length > 0 ? parts[1] : "—"
        } }
    }

    Timer {
        interval: 900000; repeat: true; running: true
        onTriggered: { weatherProc.running = false; weatherProc.running = true }
        Component.onCompleted: { weatherProc.running = true }
    }
    Process {
        id: weatherProc
        command: ["curl", "-fsS", "--max-time", "8", "https://wttr.in/?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    const current = data.current_condition?.[0] || {}
                    const desc = (current.weatherDesc?.[0]?.value || "").toLowerCase()
                    bar.weatherTemp = (current.temp_F || "—") + "°"
                    if (desc.includes("thunder"))                          bar.weatherIcon = "󰙾"
                    else if (desc.includes("snow") || desc.includes("sleet")) bar.weatherIcon = "󰼶"
                    else if (desc.includes("rain") || desc.includes("shower") || desc.includes("drizzle")) bar.weatherIcon = "󰖗"
                    else if (desc.includes("fog") || desc.includes("mist"))   bar.weatherIcon = "󰖑"
                    else if (desc.includes("cloud") || desc.includes("overcast")) bar.weatherIcon = "󰖐"
                    else if (desc.includes("clear") || desc.includes("sun"))  bar.weatherIcon = "󰖙"
                    else bar.weatherIcon = "󰖐"
                } catch(e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            bar.updateWorkspaceLabel()
        }
        function onFocusedWorkspaceChanged() {
            bar.updateWorkspaceLabel()
        }
    }
    Component.onCompleted: bar.updateWorkspaceLabel()

    // ────────────────────────────────────────────────────────────────────────
    // Layout
    // ────────────────────────────────────────────────────────────────────────

    Item {
        anchors { fill: parent; leftMargin: bar.sideContentMargin; rightMargin: bar.sideContentMargin }

        Item {
            id: leftGroup
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            implicitHeight: 40
            implicitWidth: leftRow.implicitWidth + 12

            RowLayout {
                id: leftRow
                anchors.centerIn: parent
                spacing: 10

                Item {
                    id: statusModule
                    implicitHeight: 38
                    implicitWidth: statusRow.implicitWidth + 18

                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: bar.cPill
                        border.width: 4
                        border.color: Qt.rgba(bar.cBord.r, bar.cBord.g, bar.cBord.b, 0.45)
                    }

                    RowLayout {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            id: launchButton
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 6
                            color: launchArea.pressed
                                ? Qt.lighter(bar.cPill, 1.24)
                                : launchArea.containsMouse
                                    ? Qt.lighter(bar.cPill, 1.12)
                                    : Qt.lighter(bar.cPill, 1.04)
                            border.width: 1
                            border.color: launchArea.containsMouse
                                ? Qt.rgba(bar.cAccent.r, bar.cAccent.g, bar.cAccent.b, 0.38)
                                : Qt.rgba(bar.cBord.r, bar.cBord.g, bar.cBord.b, 0.22)

                            Text {
                                anchors.centerIn: parent
                                text: "󰣇"
                                color: bar.cAccent
                                font { pixelSize: 16; family: bar.cFont }
                            }

                            MouseArea {
                                id: launchArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    bar.dismissPopup()
                                    appLaunchProc.running = false
                                    appLaunchProc.running = true
                                }
                            }

                            Process { id: appLaunchProc; command: ["bash", "/home/arch/.config/waybar/Scripts/app-launcher.sh"] }
                        }

                        Rectangle {
                            width: 1; height: 18
                            color: Qt.rgba(bar.cAccent.r, bar.cAccent.g, bar.cAccent.b, 0.3)
                        }

                        Rectangle {
                            id: networkButton
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 6
                            scale: netArea.pressed ? 0.92 : netArea.containsMouse ? 1.07 : 1
                            color: netArea.pressed
                                ? Qt.lighter(bar.cPill, 1.24)
                                : netArea.containsMouse
                                    ? Qt.lighter(bar.cPill, 1.15)
                                    : bar.openPopup === "network"
                                        ? Qt.lighter(bar.cPill, 1.10)
                                        : Qt.lighter(bar.cPill, 1.04)
                            border.width: 1
                            border.color: netArea.containsMouse || bar.openPopup === "network"
                                ? Qt.rgba(bar.cBlue.r, bar.cBlue.g, bar.cBlue.b, 0.58)
                                : Qt.rgba(bar.cBord.r, bar.cBord.g, bar.cBord.b, 0.22)

                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: bar.netLabel === "offline" || bar.netLabel === "Wi-Fi off" ? "󰖪" : "󰖩"
                                color: bar.netLabel === "offline" || bar.netLabel === "Wi-Fi off" ? bar.cDim : bar.cBlue
                                font { pixelSize: 15; family: bar.cFont }
                            }

                            MouseArea {
                                id: netArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bar.showPopup("network", networkButton)
                            }
                        }

                        Rectangle {
                            id: volumeButton
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 6
                            scale: volArea.pressed ? 0.92 : volArea.containsMouse ? 1.07 : 1
                            color: volArea.pressed
                                ? Qt.lighter(bar.cPill, 1.24)
                                : volArea.containsMouse
                                    ? Qt.lighter(bar.cPill, 1.15)
                                    : bar.openPopup === "volume"
                                        ? Qt.lighter(bar.cPill, 1.10)
                                        : Qt.lighter(bar.cPill, 1.04)
                            border.width: 1
                            border.color: volArea.containsMouse || bar.openPopup === "volume"
                                ? Qt.rgba(bar.cAccent.r, bar.cAccent.g, bar.cAccent.b, 0.58)
                                : Qt.rgba(bar.cBord.r, bar.cBord.g, bar.cBord.b, 0.22)

                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: bar.volPct === 0 ? "󰟎" : "󰋋"
                                color: bar.volPct === 0 ? bar.cDim : bar.cAccent
                                font { pixelSize: 15; family: bar.cFont }
                            }

                            MouseArea {
                                id: volArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bar.showPopup("volume", volumeButton)
                                onWheel: wheel => {
                                    const delta = wheel.angleDelta.y > 0 ? 2 : -2
                                    bar.volPct = Math.max(0, Math.min(150, bar.volPct + delta))
                                    volScrollProc.command = ["bash", "-c", "pactl set-sink-volume @DEFAULT_SINK@ " + bar.volPct + "%"]
                                    volScrollProc.running = false
                                    volScrollProc.running = true
                                }
                            }

                            Process {
                                id: volScrollProc
                                onExited: { volProc.running = false; volProc.running = true }
                            }
                        }

                        Rectangle {
                            id: bluetoothButton
                            readonly property color bluetoothAccent: bar.btState === "connected" ? bar.cAccent
                                : bar.btState === "on" ? bar.cBlue
                                : bar.btState === "error" ? bar.cRed
                                : bar.cDim
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 6
                            scale: bluetoothArea.pressed ? 0.92 : bluetoothArea.containsMouse ? 1.07 : 1
                            color: bluetoothArea.pressed
                                ? Qt.lighter(bar.cPill, 1.24)
                                : bluetoothArea.containsMouse
                                    ? Qt.lighter(bar.cPill, 1.15)
                                    : bar.openPopup === "bluetooth"
                                        ? Qt.lighter(bar.cPill, 1.10)
                                        : Qt.lighter(bar.cPill, 1.04)
                            border.width: 1
                            border.color: bluetoothArea.containsMouse || bar.openPopup === "bluetooth"
                                ? Qt.rgba(bluetoothButton.bluetoothAccent.r, bluetoothButton.bluetoothAccent.g, bluetoothButton.bluetoothAccent.b, 0.58)
                                : Qt.rgba(bar.cBord.r, bar.cBord.g, bar.cBord.b, 0.22)

                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                color: bluetoothButton.bluetoothAccent
                                font { pixelSize: 15; family: bar.cFont }
                            }

                            MouseArea {
                                id: bluetoothArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bar.showPopup("bluetooth", bluetoothButton)
                            }
                        }

                        Rectangle {
                            id: micButton
                            readonly property color micAccent: bar.micMuted ? bar.cRed : bar.cGreen
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 6
                            scale: micArea.pressed ? 0.92 : micArea.containsMouse ? 1.07 : 1
                            color: micArea.pressed
                                ? Qt.lighter(bar.cPill, 1.24)
                                : micArea.containsMouse
                                    ? Qt.lighter(bar.cPill, 1.15)
                                    : Qt.lighter(bar.cPill, 1.04)
                            border.width: 1
                            border.color: micArea.containsMouse
                                ? Qt.rgba(micButton.micAccent.r, micButton.micAccent.g, micButton.micAccent.b, 0.58)
                                : Qt.rgba(bar.cBord.r, bar.cBord.g, bar.cBord.b, 0.22)

                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: bar.micMuted ? "󰍭" : "󰍬"
                                color: bar.micMuted ? bar.cRed : bar.cGreen
                                font { pixelSize: 15; family: bar.cFont }
                            }

                            MouseArea {
                                id: micArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    bar.dismissPopup()
                                    micToggleProc.running = false
                                    micToggleProc.running = true
                                }
                            }

                            Process {
                                id: micToggleProc
                                command: ["bash", "-c", "pactl set-source-mute @DEFAULT_SOURCE@ toggle"]
                                onExited: { micProc.running = false; micProc.running = true }
                            }
                        }

                    }
                }

                Pill {
                    id: weatherPill
                    label: bar.weatherIcon + "  " + bar.weatherTemp
                    fg: bar.cYellow; bg: bar.cPill; border_: bar.cBord; font_: bar.cFont
                    accent: bar.cYellow
                    clickable: true
                    active: bar.openPopup === "weather"
                    onClicked: bar.showPopup("weather", weatherPill)
                }

                Pill {
                    id: tempPill
                    label: "󰔏  " + bar.cpuTemp
                    fg: bar.cpuTemp === "—" ? bar.cDim
                        : parseInt(bar.cpuTemp) > 85 ? bar.cRed
                        : parseInt(bar.cpuTemp) > 70 ? bar.cYellow
                        : bar.cBlue
                    bg: bar.cPill; border_: bar.cBord; font_: bar.cFont
                    accent: bar.cBlue
                    clickable: true
                    active: bar.openPopup === "temp"
                    onClicked: bar.showPopup("temp", tempPill)
                }

                Pill {
                    id: leftClockPill
                    label: "  " + bar.clockSec
                    fg: bar.cBtnFg; bg: bar.cPill; border_: bar.cBord; font_: bar.cFont
                    accent: bar.cAccent
                    clickable: true
                    active: bar.openPopup === "clock"
                    onClicked: bar.showPopup("clock", leftClockPill)
                }

                Pill {
                    visible: bar.recording
                    label: "●  Rec"
                    fg: bar.cRed
                    bg: Qt.rgba(bar.cRed.r, bar.cRed.g, bar.cRed.b, 0.1)
                    border_: Qt.rgba(bar.cRed.r, bar.cRed.g, bar.cRed.b, 0.35)
                    font_: bar.cFont
                    accent: bar.cRed
                    clickable: true
                    active: true
                    onClicked: {
                        bar.dismissPopup()
                        stopRecProc.running = false
                        stopRecProc.running = true
                    }
                    Process {
                        id: stopRecProc
                        command: ["bash", "-c", "pkill -SIGINT gpu-screen-recorder"]
                        onExited: { recProc.running = false; recProc.running = true }
                    }
                }
            }
        }

        Item {
            id: centerGroup
            anchors.centerIn: parent
            implicitHeight: 40
            implicitWidth: centerRow.implicitWidth + 12

            RowLayout {
                id: centerRow
                anchors.centerIn: parent
                spacing: 14

                Rectangle {
                    implicitHeight: 38
                    implicitWidth: workspaceRow.implicitWidth + 14
                    radius: 9
                    color: bar.cPill
                    border.width: 4
                    border.color: Qt.rgba(bar.cBord.r, bar.cBord.g, bar.cBord.b, 0.45)

                    RowLayout {
                        id: workspaceRow
                        anchors.centerIn: parent
                        spacing: 4

                        Repeater {
                            model: bar.workspaceIds

                            WorkspaceButton {
                                workspaceId: modelData
                                active: modelData === bar.activeWorkspaceId
                                occupied: bar.workspaceOccupied(modelData)
                                urgent: bar.workspaceUrgent(modelData)
                                fg: bar.cBtnFg
                                dim: bar.cDim
                                bg: bar.cPill
                                border_: bar.cBord
                                accent: bar.cAccent
                                red: bar.cRed
                                font_: bar.cFont
                                onClicked: {
                                    bar.dismissPopup()
                                    bar.switchWorkspace(modelData)
                                }
                            }
                        }
                    }
                }

                Pill {
                    label: bar.appIconFor(bar.activeAppClass) + "  " + bar.activeAppClass
                    fg: bar.cBtnFg; bg: bar.cPill; border_: bar.cBord; font_: bar.cFont
                    maxW: mediaModule.visible ? 118 : 170
                }

                MediaModule {
                    id: mediaModule
                    fg: bar.cBtnFg
                    dim: bar.cFg
                    bg: bar.cPill
                    border_: bar.cBord
                    accent: bar.cAccent
                    blue: bar.cBlue
                    font_: bar.cFont
                    active: bar.openPopup === "media"
                    onOpenRequested: bar.showPopup("media", mediaModule)
                }
            }
        }

        Item {
            id: rightGroup
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            implicitHeight: 40
            implicitWidth: rightRow.implicitWidth + 12

            RowLayout {
                id: rightRow
                anchors.centerIn: parent
                spacing: 10

                Tray {
                    parentWindow: bar
                    fg: bar.cBtnFg
                    dim: bar.cDim
                    bg: bar.cPill
                    border_: bar.cBord
                    accent: bar.cAccent
                    blue: bar.cBlue
                    green: bar.cGreen
                    yellow: bar.cYellow
                    red: bar.cRed
                    font_: bar.cFont
                    onActivated: bar.dismissPopup()
                }

                Pill {
                    id: notificationsPill
                    label: (bar.notificationsDnd ? "󰂛" : "󰂚") + (bar.notificationCount > 0 ? "  " + Math.min(99, bar.notificationCount) : "")
                    fg: bar.notificationsDnd ? bar.cRed : bar.notificationCount > 0 ? bar.cAccent : bar.cBtnFg
                    bg: bar.cPill; border_: bar.cBord; font_: bar.cFont; fontSize: 15
                    accent: bar.cAccent
                    clickable: true
                    active: bar.openPopup === "notifications"
                    onClicked: bar.showPopup("notifications", notificationsPill)
                }

                Pill {
                    id: batteryPill
                    label: (bar.batCharging ? "󰂄" :
                            bar.batPct > 90 ? "󰁹" : bar.batPct > 70 ? "󰂂" :
                            bar.batPct > 50 ? "󰂀" : bar.batPct > 30 ? "󰁾" :
                            bar.batPct > 15 ? "󰁼" : "󰁺") + "  " + bar.batPct + "%"
                    fg: bar.batPct < 15 ? bar.cRed : bar.cBtnFg
                    bg: bar.cPill; border_: bar.cBord; font_: bar.cFont
                    accent: bar.batPct < 15 ? bar.cRed : bar.cAccent
                    clickable: true
                    active: bar.openPopup === "battery"
                    onClicked: bar.showPopup("battery", batteryPill)
                }

                Pill {
                    id: powerPill
                    label: "󰐥"
                    fg: bar.cRed; bg: bar.cPill; border_: bar.cBord; font_: bar.cFont; fontSize: 15
                    accent: bar.cRed
                    clickable: true
                    active: bar.openPopup === "power"
                    onClicked: bar.showPopup("power", powerPill)
                }
            }
        }
    }
}
