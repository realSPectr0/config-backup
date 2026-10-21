import "../"
import QtQuick
import Quickshell.Io

Item {
    id: page

    property bool wifiEnabled: true
    property var networks: []
    property string pendingSsid: ""
    property string busySsid: ""
    property string statusText: ""
    property bool showPassword: false
    property var ethernet: ({
        "device": "",
        "state": "disconnected",
        "connection": ""
    })
    property string monoFont: "Noto Sans"
    property real downSpeed: 0
    property real upSpeed: 0
    property real lastRx: -1
    property real lastTx: -1
    property real lastTs: 0
    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    readonly property string icDown: "\uf019"
    readonly property string icUp: "\uf093"
    readonly property string icWifi: "\uf1eb"
    readonly property string icLock: "\uf023"
    readonly property string icEth: "\uf6ff"

    function formatSpeed(bps) {
        if (bps < 1024)
            return bps.toFixed(0) + " B/s";

        if (bps < 1024 * 1024)
            return (bps / 1024).toFixed(1) + " KB/s";

        if (bps < 1024 * 1024 * 1024)
            return (bps / 1024 / 1024).toFixed(2) + " MB/s";

        return (bps / 1024 / 1024 / 1024).toFixed(2) + " GB/s";
    }

    function setWifiEnabled(on) {
        page.wifiEnabled = on;
        pRadioSet.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        pRadioSet.running = true;
    }

    function runConnect(mode, ssid, cmd) {
        if (pConnect.running)
            return ;

        pConnect.mode = mode;
        pConnect.ssid = ssid;
        page.busySsid = ssid;
        page.statusText = mode === "disconnect" ? "Disconnecting..." : "Connecting to " + ssid + "...";
        pConnect.command = cmd;
        pConnect.running = true;
    }

    function connectOpen(ssid) {
        page.runConnect("open", ssid, ["nmcli", "--wait", "20", "device", "wifi", "connect", ssid]);
    }

    // Bring up a saved profile for this SSID; exit 10 means none, so ask for the password.
    function connectSaved(ssid) {
        page.runConnect("saved", ssid, ["sh", "-c", "uuid=$(nmcli -t -f UUID,TYPE connection show | while IFS=: read -r u t; do [ \"$t\" = 802-11-wireless ] && [ \"$(nmcli -g 802-11-wireless.ssid connection show \"$u\")\" = \"$1\" ] && { echo \"$u\"; break; }; done); [ -n \"$uuid\" ] || exit 10; exec nmcli --wait 20 connection up uuid \"$uuid\"", "sh", ssid]);
    }

    // Drop any stale profile first; nmcli refuses a password for a broken one.
    function connectSecured(ssid, password) {
        page.runConnect("password", ssid, ["sh", "-c", "nmcli connection delete id \"$1\" >/dev/null 2>&1; nmcli --wait 30 device wifi connect \"$1\" password \"$2\"", "sh", ssid, password]);
    }

    function disconnect(ssid) {
        page.runConnect("disconnect", ssid, ["sh", "-c", "dev=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2==\"wifi\"{print $1; exit}'); nmcli device disconnect \"$dev\""]);
    }

    Component.onCompleted: {
        pRadioGet.running = true;
        pList.running = true;
        pEthernet.running = true;
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            pRadioGet.running = true;
        }
    }

    Timer {
        interval: 1500
        running: page.wifiEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (page.wifiEnabled && !pList.running)
                pList.running = true;

        }
    }

    Process {
        id: pNet

        command: ["cat", "/proc/net/dev"]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n");
                var rx = 0;
                var tx = 0;
                for (var i = 2; i < lines.length; ++i) {
                    var line = lines[i].trim();
                    if (!line)
                        continue;

                    var idx = line.indexOf(":");
                    if (idx < 0)
                        continue;

                    var name = line.slice(0, idx).trim();
                    if (name === "lo" || name.indexOf("veth") === 0 || name.indexOf("docker") === 0 || name.indexOf("br-") === 0 || name.indexOf("virbr") === 0)
                        continue;

                    var parts = line.slice(idx + 1).trim().split(/\s+/);
                    rx += parseFloat(parts[0]) || 0;
                    tx += parseFloat(parts[8]) || 0;
                }
                var now = Date.now();
                if (page.lastTs > 0) {
                    var dt = (now - page.lastTs) / 1000;
                    if (dt > 0) {
                        page.downSpeed = Math.max(0, (rx - page.lastRx) / dt);
                        page.upSpeed = Math.max(0, (tx - page.lastTx) / dt);
                    }
                }
                page.lastRx = rx;
                page.lastTx = tx;
                page.lastTs = now;
            }
        }

    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!pNet.running)
                pNet.running = true;

        }
    }

    Process {
        id: pEthernet

        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]

        stdout: StdioCollector {
            onStreamFinished: {
                var result = {
                    "device": "",
                    "state": "disconnected",
                    "connection": ""
                };
                var raw = text.trim();
                if (raw) {
                    var lines = raw.split("\n");
                    for (var i = 0; i < lines.length; ++i) {
                        var line = lines[i].trim();
                        if (!line)
                            continue;

                        var fields = line.split(":");
                        if (fields.length < 4)
                            continue;

                        if (fields[1] === "ethernet") {
                            result.device = fields[0];
                            result.state = fields[2];
                            result.connection = fields.slice(3).join(":");
                            break;
                        }
                    }
                }
                page.ethernet = result;
            }
        }

        stderr: StdioCollector {
        }

    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!pEthernet.running)
                pEthernet.running = true;

        }
    }

    Process {
        id: pRadioGet

        command: ["nmcli", "radio", "wifi"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                page.wifiEnabled = text.trim() === "enabled";
                if (page.wifiEnabled && !pList.running)
                    pList.running = true;

            }
        }

    }

    Process {
        id: pRadioSet

        stdout: StdioCollector {
            onStreamFinished: {
                pRadioGet.running = true;
            }
        }

    }

    Process {
        id: pList

        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var raw = text.trim();
                if (raw) {
                    var lines = raw.split("\n");
                    for (var i = 0; i < lines.length; ++i) {
                        var line = lines[i].trim();
                        if (!line)
                            continue;

                        var fields = [];
                        var current = "";
                        var escaped = false;
                        for (var j = 0; j < line.length; ++j) {
                            var ch = line[j];
                            if (escaped) {
                                current += ch;
                                escaped = false;
                            } else if (ch === "\\") {
                                escaped = true;
                            } else if (ch === ":" && fields.length < 3) {
                                fields.push(current);
                                current = "";
                            } else {
                                current += ch;
                            }
                        }
                        fields.push(current);
                        if (fields.length < 4 || !fields[1])
                            continue;

                        var signal = parseInt(fields[2]);
                        if (isNaN(signal))
                            signal = 0;

                        out.push({
                            "ssid": fields[1],
                            "signal": signal,
                            "secured": fields[3] !== "" && fields[3] !== "--",
                            "connected": fields[0] === "*"
                        });
                    }
                }
                page.networks = out;
            }
        }

        stderr: StdioCollector {
        }

    }

    Process {
        id: pConnect

        property string mode: ""
        property string ssid: ""

        function refresh() {
            pEthernet.running = true;
            if (page.wifiEnabled)
                pList.running = true;

        }

        onExited: (exitCode) => {
            page.busySsid = "";
            var err = connectErr.text.trim().replace(/^Error: /, "");
            if (exitCode === 0) {
                page.pendingSsid = "";
                page.showPassword = false;
                page.statusText = mode === "disconnect" ? "Disconnected" : "Connected to " + ssid;
            } else if (mode === "saved") {
                page.pendingSsid = ssid;
                page.statusText = exitCode === 10 ? "Enter the password for " + ssid : "Saved password for " + ssid + " didn't work, enter it again";
            } else if (mode === "password") {
                page.statusText = "Couldn't connect to " + ssid + " (wrong password?)" + (err ? ": " + err : "");
            } else {
                page.statusText = err || "Failed (exit " + exitCode + ")";
            }
            refresh();
        }

        stderr: StdioCollector {
            id: connectErr
        }

    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: page.marginLeft
        anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop
        anchors.bottomMargin: page.marginBottom
        spacing: 14

        Text {
            text: "NETWORK"
            color: Theme.text
            font.family: page.monoFont
            font.pixelSize: 19
            font.letterSpacing: 3
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Text {
            width: parent.width
            visible: page.statusText !== ""
            text: page.statusText
            color: /^Couldn't|Failed|Error/i.test(page.statusText) ? Theme.danger : Theme.accent
            font.family: page.monoFont
            font.pixelSize: 10
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        Column {
            id: statsRow

            width: parent.width
            spacing: 9

            Rectangle {
                id: wifiToggle

                width: parent.width
                height: 36
                radius: Theme.radius
                color: page.wifiEnabled ? Theme.alpha(Theme.accent, 0.1) : Theme.alpha(Theme.textFaint, 0.15)
                border.width: 1
                border.color: page.wifiEnabled ? Theme.accent : Theme.textFaint

                Text {
                    anchors.centerIn: parent
                    text: page.wifiEnabled ? "WI-FI ON" : "WI-FI OFF"
                    color: page.wifiEnabled ? Theme.accent : Theme.textFaint
                    font.family: page.monoFont
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.setWifiEnabled(!page.wifiEnabled)
                }

            }

            Row {
                id: statsInner

                width: parent.width
                height: 40
                spacing: 9

                Repeater {
                    model: [{
                        "icon": page.icDown,
                        "label": "DOWNLOAD",
                        "value": page.downSpeed,
                        "down": true
                    }, {
                        "icon": page.icUp,
                        "label": "UPLOAD",
                        "value": page.upSpeed,
                        "down": false
                    }]

                    delegate: Rectangle {
                        required property var modelData

                        width: (statsInner.width - statsInner.spacing) / 2
                        height: statsInner.height
                        radius: Theme.radius
                        color: "#00000000"
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            id: statIcon

                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.icon
                            color: modelData.down ? Theme.accent : Theme.accent2
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                        }

                        Text {
                            anchors.left: statIcon.right
                            anchors.leftMargin: 90
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Theme.textDim
                            font.family: page.monoFont
                            font.pixelSize: 12
                            font.letterSpacing: 1.5
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.formatSpeed(modelData.value)
                            color: Theme.text
                            font.family: page.monoFont
                            font.pixelSize: 12
                            font.bold: true
                        }

                    }

                }

            }

        }

        Rectangle {
            id: ethCard

            width: parent.width
            height: 46
            radius: Theme.radius
            color: page.ethernet.state === "connected" ? Theme.alpha(Theme.accent2, 0.1) : "#00000000"
            border.width: 1
            border.color: page.ethernet.state === "connected" ? Theme.accent2 : Theme.border

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9

                Text {
                    text: page.icEth
                    color: page.ethernet.state === "connected" ? Theme.accent2 : Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: 15
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Ethernet"
                        color: Theme.text
                        font.family: page.monoFont
                        font.pixelSize: 12
                    }

                    Text {
                        text: page.ethernet.state === "connected" ? (page.ethernet.connection || page.ethernet.device) : "Disconnected"
                        color: Theme.textDim
                        font.family: page.monoFont
                        font.pixelSize: 10
                    }

                }

            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: page.ethernet.state === "connected" ? "CONNECTED" : "DISCONNECTED"
                color: page.ethernet.state === "connected" ? Theme.accent2 : Theme.textDim
                font.family: page.monoFont
                font.pixelSize: 10
                font.letterSpacing: 1
            }

        }

        Item {
            id: listContainer

            width: parent.width
            height: parent.height - y

            Flickable {
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: list.height

                Column {
                    id: list

                    width: parent.width
                    spacing: 6

                    Text {
                        visible: !page.wifiEnabled
                        width: parent.width
                        text: "Wi-Fi is disabled"
                        color: Theme.textDim
                        font.family: page.monoFont
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        visible: page.wifiEnabled && !page.networks.length
                        width: parent.width
                        text: "Scanning Wi-Fi networks"
                        color: Theme.textDim
                        font.family: page.monoFont
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Repeater {
                        model: page.networks

                        delegate: Column {
                            required property var modelData

                            width: list.width
                            spacing: 6

                            Rectangle {
                                width: parent.width
                                height: 46
                                radius: Theme.radius
                                color: modelData.connected ? Theme.alpha(Theme.accent, 0.1) : "#00000000"
                                border.width: 1
                                border.color: modelData.connected ? Theme.accent : Theme.border

                                Text {
                                    id: connectBtn

                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 84
                                    text: page.busySsid === modelData.ssid ? "WORKING..." : (modelData.connected ? "DISCONNECT" : "CONNECT")
                                    color: modelData.connected ? Theme.danger : Theme.accent
                                    font.family: page.monoFont
                                    font.pixelSize: 10

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.connected)
                                                page.disconnect(modelData.ssid);
                                            else if (page.pendingSsid === modelData.ssid)
                                                page.pendingSsid = "";
                                            else if (modelData.secured)
                                                page.connectSaved(modelData.ssid);
                                            else
                                                page.connectOpen(modelData.ssid);
                                        }
                                    }

                                }

                                Row {
                                    anchors.left: connectBtn.right
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 9

                                    Text {
                                        text: page.icWifi
                                        color: modelData.connected ? Theme.accent : Theme.textDim
                                        font.family: Theme.iconFont
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        visible: modelData.secured
                                        text: page.icLock
                                        color: Theme.textFaint
                                        font.family: Theme.iconFont
                                        font.pixelSize: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.ssid
                                        color: Theme.text
                                        font.family: page.monoFont
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        width: Math.min(implicitWidth, list.width - 190)
                                    }

                                }

                            }

                            Row {
                                visible: page.pendingSsid === modelData.ssid
                                width: parent.width
                                height: 32
                                spacing: 10

                                Rectangle {
                                    width: 260
                                    height: 32
                                    color: Theme.bgCard
                                    border.color: Theme.accent
                                    border.width: 1
                                    radius: Theme.radius

                                    TextInput {
                                        id: pwField

                                        anchors.left: parent.left
                                        anchors.right: eyeBtn.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 6
                                        clip: true
                                        color: Theme.text
                                        font.family: page.monoFont
                                        font.pixelSize: 12
                                        echoMode: page.showPassword ? TextInput.Normal : TextInput.Password
                                        focus: page.pendingSsid === modelData.ssid
                                        Keys.onReturnPressed: page.connectSecured(modelData.ssid, text)
                                        Keys.onEnterPressed: page.connectSecured(modelData.ssid, text)
                                    }

                                    Text {
                                        id: eyeBtn

                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: page.showPassword ? "" : ""
                                        color: eyeMouse.containsMouse ? Theme.text : Theme.textDim
                                        font.family: Theme.iconFont
                                        font.pixelSize: 13

                                        MouseArea {
                                            id: eyeMouse

                                            anchors.fill: parent
                                            anchors.margins: -6
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                page.showPassword = !page.showPassword;
                                                pwField.forceActiveFocus();
                                            }
                                        }

                                    }

                                }

                                Text {
                                    text: "CONNECT"
                                    color: Theme.accent2
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: page.connectSecured(modelData.ssid, pwField.text)
                                    }

                                }

                            }

                        }

                    }

                }

            }

        }

    }

}