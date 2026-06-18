import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupPanel {
    id: root

    title: "Bluetooth"
    subtitle: busyMessage.length > 0 ? busyMessage : summary
    panelWidth: 560
    keyboardFocus: true

    property string helper: "/home/arch/.config/quickshell/bar/scripts/bluetoothctl-helper.py"
    property string summary: "Loading..."
    property string statusText: "Loading Bluetooth state..."
    property string busyMessage: ""
    property string scanErrorText: ""
    property string actionErrorText: ""
    readonly property string errorText: actionErrorText.length > 0 ? actionErrorText : scanErrorText
    property bool powered: false
    property bool discovering: false
    property bool discoverable: false
    property bool pairable: false
    property int connectedCount: 0
    property int pairedCount: 0
    property string filterText: ""

    property string selectedAddress: ""
    property string selectedName: ""
    property string selectedIcon: "󰂯"
    property string selectedSublabel: ""
    property bool selectedPaired: false
    property bool selectedTrusted: false
    property bool selectedConnected: false
    property bool selectedBlocked: false
    property color warmAccent: "#ffb3a4"

    signal networkRequested()

    function refresh(discover) {
        root.busyMessage = discover ? "Scanning..." : ""
        queryProc.command = ["python3", root.helper, discover ? "discover" : "scan"]
        queryProc.running = false
        queryProc.running = true
    }

    function runAction(args, label) {
        root.busyMessage = label
        root.actionErrorText = ""
        actionProc.command = ["python3", root.helper].concat(args)
        actionProc.running = false
        actionProc.running = true
    }

    function selectDevice(address, deviceName, icon, sublabel, paired, trusted, connected, blocked) {
        root.selectedAddress = address
        root.selectedName = deviceName
        root.selectedIcon = icon
        root.selectedSublabel = sublabel
        root.selectedPaired = paired
        root.selectedTrusted = trusted
        root.selectedConnected = connected
        root.selectedBlocked = blocked
        root.actionErrorText = ""
    }

    function resetSelection() {
        root.selectedAddress = ""
        root.selectedName = ""
        root.selectedIcon = "󰂯"
        root.selectedSublabel = ""
        root.selectedPaired = false
        root.selectedTrusted = false
        root.selectedConnected = false
        root.selectedBlocked = false
        root.actionErrorText = ""
    }

    function selectedAction(action, label) {
        if (root.selectedAddress.length === 0)
            return
        root.runAction([action, root.selectedAddress], label + " " + root.selectedName + "...")
    }

    function parseJsonPayload(text) {
        const raw = (text || "").trim()
        const start = raw.indexOf("{")
        const end = raw.lastIndexOf("}")
        if (start < 0 || end < start)
            throw new Error("No JSON payload")
        return JSON.parse(raw.slice(start, end + 1))
    }

    function handleQuery(text) {
        const raw = (text || "").trim()
        let data = null
        try {
            data = root.parseJsonPayload(raw)
        } catch (e) {
            root.scanErrorText = raw.length > 0
                ? "Could not parse Bluetooth state:\n" + raw
                : "Bluetooth helper returned no state."
            return
        }

        devicesModel.clear()

        root.summary = data.summary || "Bluetooth"
        root.statusText = data.statusText || "Bluetooth"
        root.powered = data.powered === true
        root.discovering = data.discovering === true
        root.discoverable = data.discoverable === true
        root.pairable = data.pairable === true
        root.connectedCount = data.connectedCount || 0
        root.pairedCount = data.pairedCount || 0
        root.scanErrorText = data.error || ""

        const devices = data.devices || []
        for (let i = 0; i < devices.length; i++) {
            devicesModel.append({
                address: devices[i].address || "",
                deviceName: devices[i].name || devices[i].address || "Bluetooth device",
                icon: devices[i].icon || "󰂯",
                sublabel: devices[i].sublabel || "",
                status: devices[i].status || "Available",
                paired: devices[i].paired === true,
                trusted: devices[i].trusted === true,
                connected: devices[i].connected === true,
                blocked: devices[i].blocked === true,
                battery: devices[i].battery !== undefined ? devices[i].battery : -1,
                rssi: devices[i].rssi !== undefined ? devices[i].rssi : -999
            })
        }
    }

    function handleAction(text) {
        const raw = (text || "").trim()
        try {
            const result = root.parseJsonPayload(raw)
            if (!result.ok)
                root.actionErrorText = result.message || "Bluetooth action failed."
        } catch (e) {
            if (raw.length > 0)
                root.actionErrorText = raw
        }
    }

    onShowingChanged: {
        if (showing) {
            root.refresh(false)
        } else {
            root.filterText = ""
            root.resetSelection()
        }
    }

    Timer {
        interval: 8000
        repeat: true
        running: root.showing
        onTriggered: if (!queryProc.running && !actionProc.running) root.refresh(false)
    }

    ListModel { id: devicesModel }

    Process {
        id: queryProc
        command: ["python3", root.helper, "scan"]
        stdout: StdioCollector {
            onStreamFinished: root.handleQuery(text)
        }
        onExited: root.busyMessage = ""
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
        border.color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.24)
        clip: true

        Rectangle {
            width: 430
            height: 430
            radius: 215
            anchors.centerIn: parent
            color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.048)
        }

        Rectangle {
            width: 270
            height: 270
            radius: 135
            anchors.centerIn: parent
            color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.060)
        }

        Rectangle {
            width: 154
            height: 154
            radius: 77
            anchors.centerIn: parent
            color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.14)
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
            color: root.powered ? root.warmAccent : Qt.rgba(root.cDim.r, root.cDim.g, root.cDim.b, 0.42)
            scale: root.showing ? 1 : 0.88
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

            Column {
                anchors.centerIn: parent
                width: parent.width - 20
                spacing: 4

                Text {
                    width: parent.width
                    text: root.powered ? "󰋋" : "󰂲"
                    color: "#160f0d"
                    horizontalAlignment: Text.AlignHCenter
                    font { pixelSize: 30; family: root.cFont }
                }

                Text {
                    width: parent.width
                    text: root.selectedName.length > 0 ? root.selectedName : root.summary
                    color: "#160f0d"
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font { pixelSize: 12; family: root.cFont; bold: true }
                }

                Text {
                    width: parent.width
                    text: root.powered ? root.connectedCount + " connected" : "Disabled"
                    color: Qt.rgba(22 / 255, 15 / 255, 13 / 255, 0.76)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font { pixelSize: 9; family: root.cFont }
                }
            }
        }

        Rectangle {
            x: 34; y: 138; width: 150; height: 48; radius: 10
            color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.74)
            border.width: 1; border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.11)

            Text { x: 12; y: 9; text: "󰌘"; color: root.warmAccent; font { pixelSize: 13; family: root.cFont } }
            Text { x: 34; y: 8; width: 104; text: root.selectedAddress.length > 0 ? root.selectedAddress : "No device"; color: root.cFg; elide: Text.ElideRight; font { pixelSize: 10; family: root.cFont; bold: true } }
            Text { x: 34; y: 25; width: 104; text: "MAC Address"; color: root.cDim; elide: Text.ElideRight; font { pixelSize: 9; family: root.cFont } }
        }

        Rectangle {
            x: 374; y: 42; width: 150; height: 52; radius: 10
            color: scanArea.containsMouse ? Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.14) : Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.74)
            border.width: 1; border.color: scanArea.containsMouse ? Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.42) : Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.11)

            Text { x: 12; y: 11; text: "󰍉"; color: root.warmAccent; font { pixelSize: 13; family: root.cFont } }
            Text { x: 34; y: 9; width: 104; text: "Scan Devices"; color: root.cFg; elide: Text.ElideRight; font { pixelSize: 10; family: root.cFont; bold: true } }
            Text { x: 34; y: 27; width: 104; text: devicesModel.count + " found"; color: root.cDim; elide: Text.ElideRight; font { pixelSize: 9; family: root.cFont } }

            MouseArea {
                id: scanArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refresh(true)
            }
        }

        Rectangle {
            x: 404; y: 138; width: 126; height: 48; radius: 10
            color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.74)
            border.width: 1; border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.11)

            Text { x: 12; y: 9; text: "󰁹"; color: root.warmAccent; font { pixelSize: 13; family: root.cFont } }
            Text { x: 34; y: 8; width: 80; text: root.connectedCount > 0 ? root.connectedCount + " linked" : "None"; color: root.cFg; elide: Text.ElideRight; font { pixelSize: 10; family: root.cFont; bold: true } }
            Text { x: 34; y: 25; width: 80; text: "Battery"; color: root.cDim; elide: Text.ElideRight; font { pixelSize: 9; family: root.cFont } }
        }

        Rectangle {
            x: 214; y: 176; width: 128; height: 40; radius: 10
            color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.74)
            border.width: 1; border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.11)

            Text { x: 12; y: 8; text: "󰋋"; color: root.warmAccent; font { pixelSize: 12; family: root.cFont } }
            Text { x: 34; y: 7; width: 82; text: root.selectedSublabel.length > 0 ? root.selectedSublabel : "None"; color: root.cFg; elide: Text.ElideRight; font { pixelSize: 10; family: root.cFont; bold: true } }
            Text { x: 34; y: 23; width: 82; text: "Audio Profile"; color: root.cDim; elide: Text.ElideRight; font { pixelSize: 9; family: root.cFont } }
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
                    color: wifiTabArea.containsMouse ? Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.10) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰖩  Wi-Fi"
                        color: root.cFg
                        font { pixelSize: 10; family: root.cFont; bold: true }
                    }

                    MouseArea {
                        id: wifiTabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.networkRequested()
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
                    color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.82)

                    Text {
                        anchors.centerIn: parent
                        text: "  Bluetooth"
                        color: "#160f0d"
                        font { pixelSize: 10; family: root.cFont; bold: true }
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
                onClicked: root.runAction(["toggle-power"], root.powered ? "Turning Bluetooth off..." : "Turning Bluetooth on...")
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        ActionButton {
            icon: root.powered ? "󰂲" : "󰂯"
            label: root.powered ? "Off" : "On"
            sublabel: "Power"
            active: root.powered
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.runAction(["toggle-power"], root.powered ? "Turning Bluetooth off..." : "Turning Bluetooth on...")
        }

        ActionButton {
            icon: "󰑐"
            label: "Scan"
            sublabel: devicesModel.count + " device" + (devicesModel.count === 1 ? "" : "s")
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.refresh(true)
        }

        ActionButton {
            icon: root.discoverable ? "󰟎" : "󰍉"
            label: root.discoverable ? "Show" : "Hide"
            sublabel: "Discover"
            active: root.discoverable
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.runAction(["toggle-discoverable"], root.discoverable ? "Hiding adapter..." : "Making adapter visible...")
        }

        ActionButton {
            icon: root.pairable ? "󰄬" : "󰌾"
            label: root.pairable ? "Open" : "Locked"
            sublabel: "Pairs"
            active: root.pairable
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.runAction(["toggle-pairable"], root.pairable ? "Closing pairing..." : "Opening pairing...")
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 7
        color: Qt.darker(root.cCard, 1.03)
        border.width: 1
        border.color: searchInput.activeFocus ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.55) : root.cBord

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
            text: "Search devices"
            color: root.cDim
            font { pixelSize: 10; family: root.cFont }
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
            font { pixelSize: 10; family: root.cFont }
            clip: true
            onTextChanged: if (root.filterText !== text) root.filterText = text
            Keys.onEscapePressed: root.dismissRequested()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 292
        radius: 7
        color: "transparent"
        border.width: 1
        border.color: root.cBord
        clip: true

        ListView {
            id: deviceList
            anchors {
                fill: parent
                margins: 6
            }
            clip: true
            model: devicesModel
            spacing: 6
            interactive: contentHeight > height

            delegate: Rectangle {
                id: deviceRow

                readonly property bool matchesFilter: root.filterText.length === 0
                    || model.deviceName.toLowerCase().indexOf(root.filterText.toLowerCase()) !== -1
                    || model.address.toLowerCase().indexOf(root.filterText.toLowerCase()) !== -1
                    || model.status.toLowerCase().indexOf(root.filterText.toLowerCase()) !== -1
                readonly property bool isSelected: root.selectedAddress === model.address

                width: deviceList.width
                height: matchesFilter ? 58 : 0
                visible: matchesFilter
                radius: 7
                opacity: model.blocked ? 0.58 : 1
                color: model.connected || isSelected
                    ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18)
                    : rowArea.pressed
                        ? Qt.lighter(root.cCard, 1.24)
                        : rowArea.containsMouse
                            ? Qt.lighter(root.cCard, 1.13)
                            : root.cCard
                border.width: 1
                border.color: model.connected || isSelected
                    ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.68)
                    : model.blocked
                        ? Qt.rgba(1, 0.35, 0.35, 0.36)
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
                        text: model.icon
                        color: model.connected ? root.cAccent : model.blocked ? "#fca5a5" : root.cFg
                        font { pixelSize: 18; family: root.cFont }
                        horizontalAlignment: Text.AlignHCenter
                        Layout.preferredWidth: 25
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            text: model.deviceName
                            color: root.cFg
                            font { pixelSize: 12; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }

                        Text {
                            text: model.sublabel.length > 0 ? model.sublabel : model.address
                            color: root.cDim
                            font { pixelSize: 10; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 70
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            text: model.connected ? "linked" : model.paired ? "paired" : "seen"
                            color: model.connected ? root.cAccent : root.cDim
                            font { pixelSize: 10; family: root.cFont }
                            horizontalAlignment: Text.AlignRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: model.battery >= 0 ? model.battery + "%" : model.address.slice(-5)
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
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectDevice(
                        model.address,
                        model.deviceName,
                        model.icon,
                        model.sublabel,
                        model.paired,
                        model.trusted,
                        model.connected,
                        model.blocked
                    )
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: devicesModel.count === 0
            text: root.powered ? "No devices found" : "Bluetooth is off"
            color: root.cDim
            font { pixelSize: 11; family: root.cFont }
        }
    }

    Rectangle {
        visible: root.selectedAddress.length > 0
        Layout.fillWidth: true
        implicitHeight: visible ? selectedColumn.implicitHeight + 20 : 0
        radius: 7
        color: root.cCard
        border.width: 1
        border.color: root.selectedConnected
            ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.65)
            : root.cBord

        ColumnLayout {
            id: selectedColumn
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

                Text {
                    text: root.selectedIcon
                    color: root.selectedConnected ? root.cAccent : root.cFg
                    font { pixelSize: 18; family: root.cFont }
                    horizontalAlignment: Text.AlignHCenter
                    Layout.preferredWidth: 28
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: root.selectedName
                        color: root.cFg
                        font { pixelSize: 12; family: root.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.selectedSublabel.length > 0 ? root.selectedSublabel : root.selectedAddress
                        color: root.cDim
                        font { pixelSize: 10; family: root.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }
                }

                Text {
                    text: root.selectedConnected ? "󰄬" : root.selectedPaired ? "󰌾" : "󰂯"
                    color: root.selectedConnected ? root.cAccent : root.cDim
                    font { pixelSize: 16; family: root.cFont }
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    icon: root.selectedConnected ? "󰂲" : "󰂱"
                    label: root.selectedConnected ? "Disconnect" : "Connect"
                    fg: root.cFg; dim: root.cDim; bg: Qt.darker(root.cCard, 1.08); border_: root.cBord; accent: root.cAccent; font_: root.cFont
                    onClicked: root.selectedAction(root.selectedConnected ? "disconnect" : "connect", root.selectedConnected ? "Disconnecting" : "Connecting")
                }

                ActionButton {
                    visible: !root.selectedPaired
                    icon: "󰌾"
                    label: "Pair"
                    fg: root.cFg; dim: root.cDim; bg: Qt.darker(root.cCard, 1.08); border_: root.cBord; accent: root.cAccent; font_: root.cFont
                    onClicked: root.selectedAction("pair", "Pairing")
                }

                ActionButton {
                    icon: root.selectedTrusted ? "󰆴" : "󰄬"
                    label: root.selectedTrusted ? "Untrust" : "Trust"
                    fg: root.cFg; dim: root.cDim; bg: Qt.darker(root.cCard, 1.08); border_: root.cBord; accent: root.cAccent; font_: root.cFont
                    onClicked: root.selectedAction(root.selectedTrusted ? "untrust" : "trust", root.selectedTrusted ? "Untrusting" : "Trusting")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    icon: root.selectedBlocked ? "󰃤" : "󰅖"
                    label: root.selectedBlocked ? "Unblock" : "Block"
                    danger: !root.selectedBlocked
                    fg: root.cFg; dim: root.cDim; bg: Qt.darker(root.cCard, 1.08); border_: root.cBord; accent: root.cAccent; font_: root.cFont
                    onClicked: root.selectedAction(root.selectedBlocked ? "unblock" : "block", root.selectedBlocked ? "Unblocking" : "Blocking")
                }

                ActionButton {
                    icon: "󰆴"
                    label: "Forget"
                    danger: true
                    fg: root.cFg; dim: root.cDim; bg: Qt.darker(root.cCard, 1.08); border_: root.cBord; accent: root.cAccent; font_: root.cFont
                    onClicked: root.selectedAction("remove", "Forgetting")
                }

                ActionButton {
                    icon: "󰜺"
                    label: "Cancel"
                    fg: root.cFg; dim: root.cDim; bg: Qt.darker(root.cCard, 1.08); border_: root.cBord; accent: root.cAccent; font_: root.cFont
                    onClicked: root.resetSelection()
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
        spacing: 6

        ActionButton {
            icon: "󰒓"
            label: "Bluetooth manager"
            sublabel: "blueman"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: Quickshell.execDetached(["blueman-manager"])
        }

        ActionButton {
            icon: "󰆍"
            label: "Terminal agent"
            sublabel: "bluetoothctl"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: Quickshell.execDetached(["kitty", "-e", "bluetoothctl"])
        }
    }
}
