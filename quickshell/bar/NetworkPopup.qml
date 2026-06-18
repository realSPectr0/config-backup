import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupPanel {
    id: root

    title: "Wi-Fi"
    subtitle: busyMessage.length > 0 ? busyMessage : wifiState
    panelWidth: 560
    keyboardFocus: true

    property string helper: "/home/arch/.config/quickshell/bar/scripts/wifi-nmcli.py"
    property string wifiState: "Loading..."
    property string statusText: "Loading network state..."
    property string scanErrorText: ""
    property string actionErrorText: ""
    readonly property string errorText: actionErrorText.length > 0 ? actionErrorText : scanErrorText
    property string busyMessage: ""
    property bool wifiEnabled: false
    property bool wifiStatusKnown: false
    property string deviceName: ""
    property string activeSsid: ""
    property string filterText: ""

    property string selectedSsid: ""
    property string selectedLabel: ""
    property string selectedSecurity: ""
    property bool selectedLocked: false
    property bool selectedSaved: false
    property bool selectedActive: false
    property bool passwordRequired: false
    property string password: ""
    property bool showPassword: false
    property color warmAccent: "#c96643"

    signal bluetoothRequested()

    function refresh(showBusy) {
        if (showBusy)
            root.busyMessage = "Scanning..."
        scanProc.running = false
        scanProc.running = true
    }

    function runAction(args, label) {
        root.busyMessage = label
        root.actionErrorText = ""
        actionProc.command = ["python3", root.helper].concat(args)
        actionProc.running = false
        actionProc.running = true
    }

    function selectNetwork(ssid, label, security, locked, saved, active, hidden) {
        if (hidden) {
            root.actionErrorText = "Hidden networks need the full connection editor."
            return
        }

        root.selectedSsid = ssid
        root.selectedLabel = label
        root.selectedSecurity = security
        root.selectedLocked = locked
        root.selectedSaved = saved
        root.selectedActive = active
        root.password = ""
        root.showPassword = false
        root.passwordRequired = false
        root.actionErrorText = ""

        if (active)
            return

        if (locked && !saved) {
            root.passwordRequired = true
            Qt.callLater(function() { passwordInput.forceActiveFocus() })
            return
        }

        connectSelected()
    }

    function connectSelected() {
        if (root.selectedSsid.length === 0)
            return

        if (root.passwordRequired && root.password.length === 0) {
            root.actionErrorText = "Enter the Wi-Fi password."
            passwordInput.forceActiveFocus()
            return
        }

        root.runAction(["connect", root.selectedSsid, root.password], "Connecting to " + root.selectedLabel + "...")
    }

    function resetSelection() {
        root.selectedSsid = ""
        root.selectedLabel = ""
        root.selectedSecurity = ""
        root.selectedLocked = false
        root.selectedSaved = false
        root.selectedActive = false
        root.passwordRequired = false
        root.password = ""
        root.showPassword = false
        root.actionErrorText = ""
    }

    function handleScan(text) {
        try {
            const data = JSON.parse(text.trim())
            networksModel.clear()

            root.wifiStatusKnown = data.wifi_enabled !== null
            root.wifiEnabled = data.wifi_enabled === true
            root.deviceName = data.device || ""
            root.activeSsid = data.active_ssid || ""
            root.wifiState = data.summary || "Wi-Fi"
            root.scanErrorText = data.error || ""

            const status = []
            status.push(data.summary || "Wi-Fi")
            if (data.device)
                status.push("Adapter  " + data.device + " (" + (data.device_state || "unknown") + ")")
            if (data.ipv4)
                status.push("IPv4     " + data.ipv4)
            if (data.default_route)
                status.push("Route    " + data.default_route)
            if (data.saved_count !== undefined)
                status.push("Saved    " + data.saved_count + " profile" + (data.saved_count === 1 ? "" : "s"))
            root.statusText = status.join("\n")

            const nets = data.networks || []
            for (let i = 0; i < nets.length; i++) {
                networksModel.append({
                    ssid: nets[i].ssid || "",
                    label: nets[i].display || nets[i].ssid || "Hidden network",
                    bssid: nets[i].bssid || "",
                    signal: nets[i].signal || 0,
                    bars: nets[i].bars || "",
                    security: nets[i].security || "",
                    locked: nets[i].locked === true,
                    saved: nets[i].saved === true,
                    active: nets[i].active === true,
                    hidden: nets[i].hidden === true
                })
            }
        } catch (e) {
            root.scanErrorText = "Could not parse network scan output."
            root.statusText = text.trim().length > 0 ? text.trim() : "No network data."
        }
    }

    function handleAction(text) {
        try {
            const result = JSON.parse(text.trim())
            if (result.ok) {
                root.actionErrorText = ""
                root.resetSelection()
            } else {
                root.actionErrorText = result.message || "Network action failed."
                if (result.require_password) {
                    root.passwordRequired = true
                    Qt.callLater(function() { passwordInput.forceActiveFocus() })
                }
            }
        } catch (e) {
            root.actionErrorText = text.trim().length > 0 ? text.trim() : "Network action failed."
        }
    }

    onShowingChanged: {
        if (showing) {
            root.refresh(false)
        } else {
            root.resetSelection()
            root.filterText = ""
        }
    }

    Timer {
        interval: 8000
        repeat: true
        running: root.showing
        onTriggered: root.refresh(false)
    }

    ListModel { id: networksModel }

    Process {
        id: scanProc
        command: ["python3", root.helper, "scan"]
        stdout: StdioCollector {
            onStreamFinished: root.handleScan(text)
        }
        onExited: {
            if (root.busyMessage === "Scanning...")
                root.busyMessage = ""
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: root.handleAction(text)
        }
        onExited: {
            root.busyMessage = ""
            root.refresh(false)
        }
    }

    Rectangle {
        visible: false
        Layout.fillWidth: true
        Layout.preferredHeight: 0
        radius: 18
        color: Qt.rgba(16 / 255, 10 / 255, 8 / 255, 0.82)
        border.width: 1
        border.color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.22)
        clip: true

        Rectangle {
            width: 430
            height: 430
            radius: 215
            anchors.centerIn: parent
            color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.045)
        }

        Rectangle {
            width: 270
            height: 270
            radius: 135
            anchors.centerIn: parent
            color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.050)
        }

        Rectangle {
            width: 154
            height: 154
            radius: 77
            anchors.centerIn: parent
            color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.13)
            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: root.showing
                NumberAnimation { to: 1.06; duration: 1600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.00; duration: 1600; easing.type: Easing.InOutSine }
            }
        }

        Rectangle { x: 158; y: 76; width: 82; height: 1; rotation: 26; color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.28) }
        Rectangle { x: 306; y: 76; width: 82; height: 1; rotation: -26; color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.28) }
        Rectangle { x: 148; y: 157; width: 90; height: 1; rotation: -24; color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.28) }
        Rectangle { x: 306; y: 158; width: 92; height: 1; rotation: 18; color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.28) }
        Rectangle { x: 270; y: 177; width: 1; height: 46; rotation: -10; color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.28) }

        Rectangle {
            width: 126
            height: 126
            radius: 63
            anchors.centerIn: parent
            color: root.wifiEnabled ? root.warmAccent : Qt.rgba(root.cDim.r, root.cDim.g, root.cDim.b, 0.42)
            scale: root.showing ? 1 : 0.88
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

            Column {
                anchors.centerIn: parent
                width: parent.width - 20
                spacing: 4

                Text {
                    width: parent.width
                    text: root.wifiEnabled ? "󰖩" : "󰖪"
                    color: "#160f0d"
                    horizontalAlignment: Text.AlignHCenter
                    font { pixelSize: 28; family: root.cFont }
                }

                Text {
                    width: parent.width
                    text: root.activeSsid.length > 0 ? root.activeSsid : "Wi-Fi"
                    color: "#160f0d"
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font { pixelSize: 12; family: root.cFont; bold: true }
                }

                Text {
                    width: parent.width
                    text: root.wifiState
                    color: Qt.rgba(22 / 255, 15 / 255, 13 / 255, 0.76)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font { pixelSize: 9; family: root.cFont }
                }
            }
        }

        Rectangle {
            x: 34; y: 48; width: 140; height: 48; radius: 10
            color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.74)
            border.width: 1; border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.11)

            Text { x: 12; y: 9; text: "󰤨"; color: root.warmAccent; font { pixelSize: 13; family: root.cFont } }
            Text { x: 34; y: 8; width: 94; text: root.deviceName.length > 0 ? root.deviceName : "Adapter"; color: root.cFg; elide: Text.ElideRight; font { pixelSize: 10; family: root.cFont; bold: true } }
            Text { x: 34; y: 25; width: 94; text: "Band"; color: root.cDim; elide: Text.ElideRight; font { pixelSize: 9; family: root.cFont } }
        }

        Rectangle {
            x: 382; y: 38; width: 140; height: 50; radius: 10
            color: scanArea.containsMouse ? Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.14) : Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.74)
            border.width: 1; border.color: scanArea.containsMouse ? Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.42) : Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.11)

            Text { x: 12; y: 10; text: "󰍉"; color: root.warmAccent; font { pixelSize: 13; family: root.cFont } }
            Text { x: 34; y: 8; width: 94; text: "Scan Devices"; color: root.cFg; elide: Text.ElideRight; font { pixelSize: 10; family: root.cFont; bold: true } }
            Text { x: 34; y: 25; width: 94; text: networksModel.count + " visible"; color: root.cDim; elide: Text.ElideRight; font { pixelSize: 9; family: root.cFont } }

            MouseArea {
                id: scanArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refresh(true)
            }
        }

        Rectangle {
            x: 34; y: 162; width: 150; height: 48; radius: 10
            color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.74)
            border.width: 1; border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.11)

            Text { x: 12; y: 9; text: "󰩟"; color: root.warmAccent; font { pixelSize: 13; family: root.cFont } }
            Text { x: 34; y: 8; width: 104; text: root.statusText.split("\n").find(line => line.indexOf("IPv4") === 0)?.replace("IPv4", "").trim() || "No IP"; color: root.cFg; elide: Text.ElideRight; font { pixelSize: 10; family: root.cFont; bold: true } }
            Text { x: 34; y: 25; width: 104; text: "IP Address"; color: root.cDim; elide: Text.ElideRight; font { pixelSize: 9; family: root.cFont } }
        }

        Rectangle {
            x: 406; y: 140; width: 126; height: 48; radius: 10
            color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.74)
            border.width: 1; border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.11)

            Text { x: 12; y: 9; text: "󰤨"; color: root.warmAccent; font { pixelSize: 13; family: root.cFont } }
            Text { x: 34; y: 8; width: 80; text: root.wifiEnabled ? "Online" : "Off"; color: root.cFg; elide: Text.ElideRight; font { pixelSize: 10; family: root.cFont; bold: true } }
            Text { x: 34; y: 25; width: 80; text: "Signal"; color: root.cDim; elide: Text.ElideRight; font { pixelSize: 9; family: root.cFont } }
        }

        Rectangle {
            x: 214; y: 176; width: 128; height: 40; radius: 10
            color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.74)
            border.width: 1; border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.11)

            Text { x: 12; y: 8; text: ""; color: root.warmAccent; font { pixelSize: 12; family: root.cFont } }
            Text { x: 34; y: 7; width: 82; text: "WPA2"; color: root.cFg; elide: Text.ElideRight; font { pixelSize: 10; family: root.cFont; bold: true } }
            Text { x: 34; y: 23; width: 82; text: "Security"; color: root.cDim; elide: Text.ElideRight; font { pixelSize: 9; family: root.cFont } }
        }

        Rectangle {
            width: 246
            height: 34
            radius: 10
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 8
            }
            color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.82)
            border.width: 1
            border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.10)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.82)

                    Text {
                        anchors.centerIn: parent
                        text: "󰖩  Wi-Fi"
                        color: "#160f0d"
                        font { pixelSize: 10; family: root.cFont; bold: true }
                    }
                }

                Rectangle {
                    width: 1
                    Layout.fillHeight: true
                    color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.16)
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: btTabArea.containsMouse ? Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.10) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "  Bluetooth"
                        color: root.cFg
                        font { pixelSize: 10; family: root.cFont; bold: true }
                    }

                    MouseArea {
                        id: btTabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.bluetoothRequested()
                    }
                }
            }
        }

        Rectangle {
            width: 42
            height: 42
            radius: 21
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: 16
                bottomMargin: 10
            }
            color: powerArea.pressed
                ? Qt.darker(root.warmAccent, 1.12)
                : powerArea.containsMouse
                    ? Qt.lighter(root.warmAccent, 1.08)
                    : root.warmAccent
            border.width: 1
            border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.16)

            Text {
                anchors.centerIn: parent
                text: "󰐥"
                color: "#160f0d"
                font { pixelSize: 17; family: root.cFont; bold: true }
            }

            MouseArea {
                id: powerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.runAction(["toggle"], root.wifiEnabled ? "Turning Wi-Fi off..." : "Turning Wi-Fi on...")
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ActionButton {
            icon: root.wifiEnabled ? "󰖩" : "󰖪"
            label: root.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"
            sublabel: root.deviceName.length > 0 ? root.deviceName : "Radio"
            active: root.wifiEnabled
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.runAction(["toggle"], root.wifiEnabled ? "Turning Wi-Fi off..." : "Turning Wi-Fi on...")
        }

        ActionButton {
            icon: "󰑐"
            label: "Scan"
            sublabel: networksModel.count + " network" + (networksModel.count === 1 ? "" : "s")
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.refresh(true)
        }

        ActionButton {
            icon: "󰤨"
            label: "Restart"
            sublabel: "NetworkManager"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.runAction(["restart"], "Restarting networking...")
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 7
        color: root.cCard
        border.width: 1
        border.color: searchInput.activeFocus ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.75) : root.cBord

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
            visible: searchInput.text.length === 0
            text: "Search networks"
            color: root.cDim
            font { pixelSize: 11; family: root.cFont }
        }

        TextInput {
            id: searchInput
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
            onTextChanged: if (root.filterText !== text) root.filterText = text
            Keys.onEscapePressed: root.dismissRequested()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 318
        radius: 7
        color: "transparent"
        border.width: 1
        border.color: root.cBord
        clip: true

        ListView {
            id: networkList
            anchors {
                fill: parent
                margins: 6
            }
            clip: true
            model: networksModel
            spacing: 6

            delegate: Rectangle {
                id: networkRow

                readonly property bool matchesFilter: root.filterText.length === 0
                    || label.toLowerCase().indexOf(root.filterText.toLowerCase()) !== -1
                    || security.toLowerCase().indexOf(root.filterText.toLowerCase()) !== -1
                readonly property bool isSelected: root.selectedSsid === ssid && root.selectedSsid.length > 0

                width: networkList.width
                height: matchesFilter ? 58 : 0
                visible: matchesFilter
                radius: 7
                opacity: hidden ? 0.55 : 1
                color: active || isSelected
                    ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18)
                    : rowArea.pressed
                        ? Qt.lighter(root.cCard, 1.24)
                        : rowArea.containsMouse
                            ? Qt.lighter(root.cCard, 1.13)
                            : root.cCard
                border.width: 1
                border.color: active || isSelected
                    ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.68)
                    : rowArea.containsMouse
                        ? Qt.lighter(root.cBord, 1.55)
                        : root.cBord

                Behavior on color { ColorAnimation { duration: 110 } }
                Behavior on border.color { ColorAnimation { duration: 110 } }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 10

                    Text {
                        text: active ? "󰖩" : locked ? "" : "󰤨"
                        color: active ? root.cAccent : root.cFg
                        font { pixelSize: 17; family: root.cFont }
                        horizontalAlignment: Text.AlignHCenter
                        Layout.preferredWidth: 24
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            text: label
                            color: root.cFg
                            font { pixelSize: 12; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }

                        Text {
                            text: (active ? "Connected" : saved ? "Saved" : locked ? "Secured" : "Open")
                                + (security.length > 0 ? " · " + security : "")
                            color: root.cDim
                            font { pixelSize: 10; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 72
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            text: bars.length > 0 ? bars : signal + "%"
                            color: active ? root.cAccent : root.cFg
                            font { pixelSize: 12; family: root.cFont }
                            horizontalAlignment: Text.AlignRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: signal + "%"
                            color: root.cDim
                            font { pixelSize: 9; family: root.cFont }
                            horizontalAlignment: Text.AlignRight
                            Layout.fillWidth: true
                        }
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: hidden ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.selectNetwork(ssid, label, security, locked, saved, active, hidden)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: networksModel.count === 0
            text: root.wifiEnabled ? "No networks found" : "Turn Wi-Fi on to scan"
            color: root.cDim
            font { pixelSize: 12; family: root.cFont }
        }
    }

    Rectangle {
        visible: root.selectedSsid.length > 0
        Layout.fillWidth: true
        implicitHeight: visible ? selectionColumn.implicitHeight + 20 : 0
        radius: 7
        color: root.cCard
        border.width: 1
        border.color: root.passwordRequired ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.65) : root.cBord

        ColumnLayout {
            id: selectionColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: root.selectedLabel
                        color: root.cFg
                        font { pixelSize: 12; family: root.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.selectedActive
                            ? "Connected network"
                            : root.passwordRequired
                                ? "Password required"
                                : root.selectedSaved
                                    ? "Saved network"
                                    : root.selectedLocked
                                        ? root.selectedSecurity
                                        : "Open network"
                        color: root.cDim
                        font { pixelSize: 10; family: root.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }
                }

                Text {
                    text: root.selectedActive ? "󰄬" : root.selectedLocked ? "" : "󰤨"
                    color: root.selectedActive ? root.cAccent : root.cFg
                    font { pixelSize: 16; family: root.cFont }
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Rectangle {
                visible: root.passwordRequired
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 7
                color: Qt.darker(root.cCard, 1.08)
                border.width: 1
                border.color: passwordInput.activeFocus ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.75) : root.cBord

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    visible: passwordInput.text.length === 0
                    text: "Password"
                    color: root.cDim
                    font { pixelSize: 11; family: root.cFont }
                }

                TextInput {
                    id: passwordInput
                    anchors {
                        left: parent.left
                        right: revealPassword.left
                        top: parent.top
                        bottom: parent.bottom
                        leftMargin: 12
                        rightMargin: 8
                    }
                    text: root.password
                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                    color: root.cFg
                    selectionColor: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.35)
                    selectedTextColor: root.cFg
                    verticalAlignment: TextInput.AlignVCenter
                    font { pixelSize: 11; family: root.cFont }
                    clip: true
                    onTextChanged: if (root.password !== text) root.password = text
                    onAccepted: root.connectSelected()
                    Keys.onEscapePressed: root.resetSelection()
                }

                Rectangle {
                    id: revealPassword
                    anchors {
                        right: parent.right
                        rightMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    width: 30
                    height: 28
                    radius: 6
                    color: revealArea.containsMouse ? Qt.lighter(root.cCard, 1.18) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: root.showPassword ? "󰈈" : "󰈉"
                        color: root.cDim
                        font { pixelSize: 13; family: root.cFont }
                    }

                    MouseArea {
                        id: revealArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showPassword = !root.showPassword
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    visible: root.passwordRequired
                    icon: "󰌋"
                    label: "Connect"
                    fg: root.cFg; dim: root.cDim; bg: Qt.darker(root.cCard, 1.08); border_: root.cBord; accent: root.cAccent; font_: root.cFont
                    onClicked: root.connectSelected()
                }

                ActionButton {
                    visible: root.passwordRequired
                    icon: "󰜺"
                    label: "Cancel"
                    fg: root.cFg; dim: root.cDim; bg: Qt.darker(root.cCard, 1.08); border_: root.cBord; accent: root.cAccent; font_: root.cFont
                    onClicked: root.resetSelection()
                }

                ActionButton {
                    visible: root.selectedActive
                    icon: "󰖪"
                    label: "Disconnect"
                    fg: root.cFg; dim: root.cDim; bg: Qt.darker(root.cCard, 1.08); border_: root.cBord; accent: root.cAccent; font_: root.cFont
                    onClicked: root.runAction(["disconnect"], "Disconnecting...")
                }

                ActionButton {
                    visible: root.selectedActive || root.selectedSaved
                    enabled: root.selectedSaved
                    icon: "󰆴"
                    label: "Forget"
                    fg: root.cFg; dim: root.cDim; bg: Qt.darker(root.cCard, 1.08); border_: root.cBord; accent: root.cAccent; font_: root.cFont
                    onClicked: root.runAction(["forget", root.selectedSsid], "Forgetting " + root.selectedLabel + "...")
                }
            }
        }
    }

    Rectangle {
        visible: root.errorText.length > 0
        Layout.fillWidth: true
        implicitHeight: visible ? errorTextItem.implicitHeight + 18 : 0
        radius: 7
        color: Qt.rgba(1, 0.35, 0.35, 0.10)
        border.width: 1
        border.color: Qt.rgba(1, 0.35, 0.35, 0.36)

        Text {
            id: errorTextItem
            anchors {
                fill: parent
                margins: 9
            }
            text: root.errorText
            color: "#fca5a5"
            font { pixelSize: 10; family: root.cFont }
            wrapMode: Text.Wrap
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ActionButton {
            icon: "󰒓"
            label: "Connection editor"
            sublabel: "Advanced"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: Quickshell.execDetached(["nm-connection-editor"])
        }

        ActionButton {
            icon: "󰆍"
            label: "Terminal UI"
            sublabel: "nmtui"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: Quickshell.execDetached(["kitty", "-e", "nmtui"])
        }
    }
}
