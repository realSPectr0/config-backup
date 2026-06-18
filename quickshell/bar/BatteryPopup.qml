import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupPanel {
    id: root

    title: "Battery"
    subtitle: root.status + " · " + root.profileLabel(root.profile)
    panelWidth: 460

    property bool present: true
    property bool acOnline: false
    property int pct: 0
    property int health: 0
    property int cycles: -1
    property int threshold: 0
    property real drawW: 0
    property real voltageV: 0
    property real energyNow: 0
    property real energyFull: 0
    property string status: "Unknown"
    property string profile: "unknown"
    property string timeLeft: "unknown"
    property string model: ""
    property string manufacturer: ""
    readonly property string monitorScript: "/home/arch/.config/quickshell/bar/scripts/system-monitor.py"
    readonly property color levelColor: !root.present ? root.cDim
        : root.pct < 15 ? "#f87171"
        : root.pct < 30 ? "#fbbf24"
        : root.status === "Charging" ? "#86efac"
        : root.cAccent

    function profileLabel(value) {
        if (value === "power-saver") return "Power saver"
        if (value === "balanced") return "Balanced"
        if (value === "performance") return "Performance"
        return value || "Unknown"
    }

    function batteryIcon() {
        if (root.acOnline && root.status !== "Full") return "󰂄"
        if (root.pct > 90) return "󰁹"
        if (root.pct > 70) return "󰂂"
        if (root.pct > 50) return "󰂀"
        if (root.pct > 30) return "󰁾"
        if (root.pct > 15) return "󰁼"
        return "󰁺"
    }

    function refresh() {
        queryProc.running = false
        queryProc.running = true
    }

    function run(command) {
        actionProc.command = command
        actionProc.running = false
        actionProc.running = true
    }

    onShowingChanged: if (showing) refresh()

    Timer {
        interval: 10000
        repeat: true
        running: root.showing
        onTriggered: root.refresh()
    }

    Process {
        id: queryProc
        command: ["python3", root.monitorScript, "battery"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.present = data.present ?? true
                    root.pct = data.percent ?? 0
                    root.status = data.status ?? "Unknown"
                    root.profile = data.profile ?? "unknown"
                    root.acOnline = data.ac_online ?? false
                    root.energyNow = data.energy_now_wh ?? 0
                    root.energyFull = data.energy_full_wh ?? 0
                    root.drawW = data.power_w ?? 0
                    root.voltageV = data.voltage_v ?? 0
                    root.health = data.health ?? 0
                    root.cycles = data.cycle_count ?? -1
                    root.threshold = data.threshold ?? 0
                    root.timeLeft = data.time_left ?? "unknown"
                    root.model = data.model ?? ""
                    root.manufacturer = data.manufacturer ?? ""
                } catch(e) {}
            }
        }
    }

    Process {
        id: actionProc
        onExited: root.refresh()
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 150
        radius: 14
        color: root.cCard
        border.width: 1
        border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.38)
        clip: true

        Rectangle {
            anchors.fill: parent
            opacity: 0.20
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.72) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        RowLayout {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                Layout.alignment: Qt.AlignVCenter
                radius: 26
                color: Qt.rgba(root.levelColor.r, root.levelColor.g, root.levelColor.b, 0.16)
                border.width: 1
                border.color: Qt.rgba(root.levelColor.r, root.levelColor.g, root.levelColor.b, 0.52)

                Text {
                    anchors.centerIn: parent
                    text: root.batteryIcon()
                    color: root.levelColor
                    font { pixelSize: 42; family: root.cFont }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: root.present ? root.pct + "%" : "N/A"
                        color: root.cFg
                        font { pixelSize: 40; family: root.cFont }
                        Layout.alignment: Qt.AlignBottom
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBottom
                        spacing: 0

                        Text {
                            text: root.status
                            color: root.levelColor
                            font { pixelSize: 13; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.acOnline ? "AC connected" : "On battery"
                            color: root.cDim
                            font { pixelSize: 10; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 12
                    radius: 6
                    color: Qt.rgba(root.cBord.r, root.cBord.g, root.cBord.b, 0.58)
                    clip: true

                    Rectangle {
                        height: parent.height
                        width: Math.max(8, parent.width * Math.min(root.pct, 100) / 100)
                        radius: parent.radius
                        color: root.levelColor
                        Behavior on width { NumberAnimation { duration: 180 } }
                    }
                }

                Text {
                    text: root.model.length > 0 ? root.manufacturer + " " + root.model : "Battery pack"
                    color: root.cDim
                    font { pixelSize: 10; family: root.cFont }
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 8
        columnSpacing: 8

        Repeater {
            model: [
                { icon: "󰔏", label: "Draw", value: root.drawW.toFixed(1) + " W" },
                { icon: "󰋼", label: "Time", value: root.timeLeft },
                { icon: "󰁹", label: "Health", value: root.health > 0 ? root.health + "%" : "N/A" },
                { icon: "󰔄", label: "Stored", value: root.energyNow.toFixed(1) + " Wh" },
                { icon: "󰚥", label: "Voltage", value: root.voltageV.toFixed(1) + " V" },
                { icon: "󰁿", label: "Cycles", value: root.cycles >= 0 ? root.cycles : "N/A" }
            ]

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: 9
                color: root.cCard
                border.width: 1
                border.color: root.cBord

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 9
                    }
                    spacing: 2

                    Text {
                        text: modelData.icon + "  " + modelData.label
                        color: root.cDim
                        font { pixelSize: 9; family: root.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }

                    Text {
                        text: modelData.value
                        color: root.cFg
                        font { pixelSize: 12; family: root.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 8
        columnSpacing: 8

        ActionButton {
            icon: "󰾅"
            label: "Saver"
            sublabel: "Cool"
            active: root.profile === "power-saver"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.run(["powerprofilesctl", "set", "power-saver"])
        }

        ActionButton {
            icon: "󰾆"
            label: "Balanced"
            sublabel: "Default"
            active: root.profile === "balanced"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.run(["powerprofilesctl", "set", "balanced"])
        }

        ActionButton {
            icon: "󰓅"
            label: "Perf"
            sublabel: "Fast"
            active: root.profile === "performance"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.run(["powerprofilesctl", "set", "performance"])
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ActionButton {
            icon: "󰑐"
            label: "Refresh"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.refresh()
        }

        ActionButton {
            icon: "󰂑"
            label: "Battery menu"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: Quickshell.execDetached(["bash", "/home/arch/.config/waybar/Scripts/battery-menu-user.sh"])
        }
    }
}
