import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupPanel {
    id: root

    title: "System"
    subtitle: root.cpuUsage + "% CPU · " + root.memoryPercent + "% RAM · " + (root.gpuAvailable ? root.gpuUsage + "% GPU" : "GPU off")
    panelWidth: 740
    keyboardFocus: true

    property int cpuUsage: 0
    property int cpuTemp: 0
    property real cpuFreq: 0
    property string load1: "0"
    property string load5: "0"
    property bool gpuAvailable: false
    property string gpuName: "GPU unavailable"
    property int gpuUsage: 0
    property int gpuTemp: 0
    property int gpuMemPercent: 0
    property int gpuMemUsed: 0
    property int gpuMemTotal: 0
    property real gpuPower: 0
    property int memoryPercent: 0
    property real memoryUsed: 0
    property real memoryTotal: 0
    property int swapPercent: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property int processCount: 0
    property string updated: ""
    property string filterText: ""
    property string killStatus: ""
    readonly property string monitorScript: "/home/arch/.config/quickshell/bar/scripts/system-monitor.py"

    ListModel { id: tempsModel }
    ListModel { id: fansModel }
    ListModel { id: processesModel }

    function tempColor(t) {
        if (t >= 85) return "#f87171"
        if (t >= 70) return "#fbbf24"
        return root.cAccent
    }

    function usageColor(pct) {
        if (pct >= 90) return "#f87171"
        if (pct >= 75) return "#fbbf24"
        return root.cAccent
    }

    function refreshStats() {
        statsProc.running = false
        statsProc.running = true
    }

    function refreshProcesses() {
        processProc.command = ["python3", root.monitorScript, "processes", root.filterText]
        processProc.running = false
        processProc.running = true
    }

    function refreshAll() {
        root.refreshStats()
        root.refreshProcesses()
    }

    function killProcess(pid, mode) {
        root.killStatus = "Stopping PID " + pid + "..."
        killProc.command = ["python3", root.monitorScript, "kill", String(pid), mode]
        killProc.running = false
        killProc.running = true
    }

    onShowingChanged: if (showing) {
        root.refreshAll()
        Qt.callLater(function() { processSearch.forceActiveFocus() })
    }

    Timer {
        interval: 2500
        repeat: true
        running: root.showing
        onTriggered: root.refreshStats()
    }

    Timer {
        interval: 4500
        repeat: true
        running: root.showing
        onTriggered: root.refreshProcesses()
    }

    Process {
        id: statsProc
        command: ["python3", root.monitorScript, "stats"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.cpuUsage = data.cpu?.usage ?? 0
                    root.cpuTemp = data.cpu?.temp ?? 0
                    root.cpuFreq = data.cpu?.freq_ghz ?? 0
                    root.load1 = data.cpu?.load1 ?? "0"
                    root.load5 = data.cpu?.load5 ?? "0"
                    root.gpuAvailable = data.gpu?.available ?? false
                    root.gpuName = data.gpu?.name ?? "GPU unavailable"
                    root.gpuUsage = data.gpu?.usage ?? 0
                    root.gpuTemp = data.gpu?.temp ?? 0
                    root.gpuMemPercent = data.gpu?.mem_percent ?? 0
                    root.gpuMemUsed = data.gpu?.mem_used_mb ?? 0
                    root.gpuMemTotal = data.gpu?.mem_total_mb ?? 0
                    root.gpuPower = data.gpu?.power_w ?? 0
                    root.memoryPercent = data.memory?.percent ?? 0
                    root.memoryUsed = data.memory?.used_gb ?? 0
                    root.memoryTotal = data.memory?.total_gb ?? 0
                    root.swapPercent = data.memory?.swap_percent ?? 0
                    root.swapUsed = data.memory?.swap_used_gb ?? 0
                    root.swapTotal = data.memory?.swap_total_gb ?? 0
                    root.processCount = data.process_count ?? 0
                    root.updated = data.updated ?? ""

                    tempsModel.clear()
                    const temps = data.temps ?? []
                    for (let i = 0; i < temps.length; i++)
                        tempsModel.append({
                            "label": temps[i].label ?? "sensor",
                            "temp": temps[i].temp ?? 0,
                            "source": temps[i].source ?? ""
                        })

                    fansModel.clear()
                    const fans = data.fans ?? []
                    for (let f = 0; f < fans.length; f++)
                        fansModel.append({
                            "label": fans[f].label ?? "fan",
                            "rpm": fans[f].rpm ?? 0
                        })
                } catch(e) {}
            }
        }
    }

    Process {
        id: processProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    processesModel.clear()
                    const rows = data.processes ?? []
                    for (let i = 0; i < rows.length; i++)
                        processesModel.append({
                            "pid": rows[i].pid ?? 0,
                            "user": rows[i].user ?? "",
                            "cpu": rows[i].cpu ?? 0,
                            "mem": rows[i].mem ?? 0,
                            "rss": rows[i].rss_mb ?? 0,
                            "name": rows[i].name ?? "",
                            "command": rows[i].command ?? ""
                        })
                } catch(e) {}
            }
        }
    }

    Process {
        id: killProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.killStatus = data.ok
                        ? "Sent " + data.signal + " to PID " + data.pid
                        : "Kill failed: " + (data.error ?? "unknown")
                } catch(e) {
                    root.killStatus = "Kill failed"
                }
                root.refreshProcesses()
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
                {
                    icon: "󰍛",
                    label: "CPU",
                    value: root.cpuUsage + "%",
                    sub: (root.cpuTemp > 0 ? root.cpuTemp + "°C · " : "") + root.cpuFreq.toFixed(2) + " GHz",
                    progress: root.cpuUsage,
                    color: root.usageColor(root.cpuUsage)
                },
                {
                    icon: "󰢮",
                    label: "GPU",
                    value: root.gpuAvailable ? root.gpuUsage + "%" : "off",
                    sub: root.gpuAvailable ? root.gpuTemp + "°C · " + root.gpuPower.toFixed(1) + " W" : root.gpuName,
                    progress: root.gpuAvailable ? root.gpuUsage : 0,
                    color: root.gpuAvailable ? root.usageColor(root.gpuUsage) : root.cDim
                },
                {
                    icon: "󰘚",
                    label: "RAM",
                    value: root.memoryPercent + "%",
                    sub: root.memoryUsed.toFixed(1) + " / " + root.memoryTotal.toFixed(1) + " GB",
                    progress: root.memoryPercent,
                    color: root.usageColor(root.memoryPercent)
                }
            ]

            Rectangle {
                id: metricCard

                readonly property color metricColor: modelData.color

                Layout.fillWidth: true
                Layout.preferredHeight: 112
                radius: 12
                color: root.cCard
                border.width: 1
                border.color: Qt.rgba(metricCard.metricColor.r, metricCard.metricColor.g, metricCard.metricColor.b, 0.38)
                clip: true

                Rectangle {
                    anchors.fill: parent
                    opacity: 0.12
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: metricCard.metricColor }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 12
                    }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: modelData.icon
                            color: metricCard.metricColor
                            font { pixelSize: 20; family: root.cFont }
                        }

                        Text {
                            text: modelData.label
                            color: root.cDim
                            font { pixelSize: 10; family: root.cFont }
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: modelData.value
                        color: root.cFg
                        font { pixelSize: 28; family: root.cFont }
                        Layout.fillWidth: true
                    }

                    Text {
                        text: modelData.sub
                        color: root.cDim
                        font { pixelSize: 9; family: root.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        radius: 3
                        color: Qt.rgba(root.cBord.r, root.cBord.g, root.cBord.b, 0.52)
                        clip: true

                        Rectangle {
                            height: parent.height
                            width: Math.max(3, parent.width * Math.min(modelData.progress, 100) / 100)
                            radius: parent.radius
                            color: metricCard.metricColor
                            Behavior on width { NumberAnimation { duration: 180 } }
                        }
                    }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 4
        rowSpacing: 8
        columnSpacing: 8

        Repeater {
            model: [
                { icon: "󰓅", label: "Load", value: root.load1 + " / " + root.load5 },
                { icon: "󰣇", label: "Processes", value: root.processCount },
                { icon: "󰾴", label: "Swap", value: root.swapTotal > 0 ? root.swapPercent + "%" : "off" },
                { icon: "󰥔", label: "Updated", value: root.updated }
            ]

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: 9
                color: root.cCard
                border.width: 1
                border.color: root.cBord

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 8
                    }
                    spacing: 1

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
                        font { pixelSize: 11; family: root.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 148
            radius: 10
            color: root.cCard
            border.width: 1
            border.color: root.cBord
            clip: true

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 10
                }
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "󰔏"
                        color: root.tempColor(root.cpuTemp)
                        font { pixelSize: 14; family: root.cFont }
                    }

                    Text {
                        text: "Sensors"
                        color: root.cFg
                        font { pixelSize: 12; family: root.cFont }
                        Layout.fillWidth: true
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: tempsModel
                    spacing: 4

                    delegate: RowLayout {
                        width: ListView.view.width
                        height: 22
                        spacing: 6

                        Text {
                            text: label
                            color: root.cFg
                            font { pixelSize: 10; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }

                        Text {
                            text: temp + "°C"
                            color: root.tempColor(temp)
                            font { pixelSize: 10; family: root.cFont }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 220
            Layout.preferredHeight: 148
            radius: 10
            color: root.cCard
            border.width: 1
            border.color: root.cBord

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 10
                }
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "󰈐"
                        color: root.cAccent
                        font { pixelSize: 14; family: root.cFont }
                    }

                    Text {
                        text: "Fans"
                        color: root.cFg
                        font { pixelSize: 12; family: root.cFont }
                        Layout.fillWidth: true
                    }
                }

                Repeater {
                    model: fansModel

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: label
                            color: root.cFg
                            font { pixelSize: 10; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }

                        Text {
                            text: rpm + " RPM"
                            color: root.cAccent
                            font { pixelSize: 10; family: root.cFont }
                        }
                    }
                }

                Text {
                    visible: fansModel.count === 0
                    text: "No fan sensors"
                    color: root.cDim
                    font { pixelSize: 10; family: root.cFont }
                    Layout.fillWidth: true
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 7
        color: root.cCard
        border.width: 1
        border.color: processSearch.activeFocus ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.75) : root.cBord

        Text {
            anchors {
                left: parent.left
                leftMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: "󰍉"
            color: root.cDim
            font { pixelSize: 14; family: root.cFont }
        }

        Text {
            anchors {
                left: parent.left
                leftMargin: 38
                verticalCenter: parent.verticalCenter
            }
            visible: processSearch.text.length === 0
            text: "Find process by name, command, user, or PID"
            color: root.cDim
            font { pixelSize: 11; family: root.cFont }
        }

        TextInput {
            id: processSearch
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                leftMargin: 38
                rightMargin: 12
            }
            text: root.filterText
            color: root.cFg
            selectionColor: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.35)
            selectedTextColor: root.cFg
            verticalAlignment: TextInput.AlignVCenter
            font { pixelSize: 11; family: root.cFont }
            clip: true
            onTextChanged: {
                if (root.filterText !== text) {
                    root.filterText = text
                    root.refreshProcesses()
                }
            }
            onAccepted: root.refreshProcesses()
            Keys.onEscapePressed: root.dismissRequested()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 250
        radius: 9
        color: "transparent"
        border.width: 1
        border.color: root.cBord
        clip: true

        ListView {
            id: processList
            anchors {
                fill: parent
                margins: 6
            }
            clip: true
            model: processesModel
            spacing: 6

            delegate: Rectangle {
                width: processList.width
                height: 42
                radius: 7
                color: killArea.containsMouse ? Qt.lighter(root.cCard, 1.12) : root.cCard
                border.width: 1
                border.color: root.cBord

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 9
                        rightMargin: 7
                    }
                    spacing: 8

                    Text {
                        text: pid
                        color: root.cDim
                        font { pixelSize: 9; family: root.cFont }
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 48
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        Text {
                            text: name + "  ·  " + user
                            color: root.cFg
                            font { pixelSize: 11; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }

                        Text {
                            text: command
                            color: root.cDim
                            font { pixelSize: 9; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: cpu.toFixed(1) + "%"
                        color: root.usageColor(cpu)
                        font { pixelSize: 10; family: root.cFont }
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 44
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: rss + "M"
                        color: root.cDim
                        font { pixelSize: 10; family: root.cFont }
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 48
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        radius: 7
                        color: killArea.pressed
                            ? Qt.rgba(248, 113, 113, 0.24)
                            : killArea.containsMouse
                                ? Qt.rgba(248, 113, 113, 0.16)
                                : "transparent"
                        border.width: 1
                        border.color: killArea.containsMouse ? Qt.rgba(248, 113, 113, 0.62) : Qt.rgba(248, 113, 113, 0.30)

                        Text {
                            anchors.centerIn: parent
                            text: "TERM"
                            color: "#f87171"
                            font { pixelSize: 9; family: root.cFont }
                        }

                        MouseArea {
                            id: killArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.killProcess(pid, "term")
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: processesModel.count === 0
            text: "No matching processes"
            color: root.cDim
            font { pixelSize: 12; family: root.cFont }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: root.killStatus
            color: root.killStatus.indexOf("failed") >= 0 ? "#f87171" : root.cDim
            font { pixelSize: 10; family: root.cFont }
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        ActionButton {
            icon: "󰑐"
            label: "Refresh"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.refreshAll()
        }

        ActionButton {
            icon: "󰓅"
            label: "btop"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: {
                root.dismissRequested()
                btopProc.running = false
                btopProc.running = true
            }
            Process {
                id: btopProc
                command: ["bash", "-c", "kitty --class btop -e btop 2>/dev/null || foot -e btop 2>/dev/null || alacritty -e btop"]
            }
        }
    }
}
