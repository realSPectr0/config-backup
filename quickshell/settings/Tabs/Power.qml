import "../"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: page

    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    property string currentProfile: ""
    property var availableProfiles: []
    property bool hasBattery: false
    property int batteryPercent: 0
    property string batteryStatus: ""

    // Profiles come from power-profiles-daemon (powerprofilesctl), which
    // switches without sudo and owns the CPU governor/EPP while it runs.
    function profileLabel(profile) {
        switch (profile) {
        case "power-saver":
            return "POWER SAVER";
        case "balanced":
            return "BALANCED";
        case "performance":
            return "PERFORMANCE";
        default:
            return profile.toUpperCase();
        }
    }

    function profileIcon(profile) {
        switch (profile) {
        case "power-saver":
            return "";
        case "balanced":
            return "";
        case "performance":
            return "";
        default:
            return "";
        }
    }

    function profileDescription(profile) {
        switch (profile) {
        case "power-saver":
            return "Lower power usage";
        case "balanced":
            return "Dynamic CPU scaling";
        case "performance":
            return "Highest performance";
        default:
            return "Power profile";
        }
    }

    function setProfile(profile) {
        if (profileSet.running)
            return ;

        if (page.availableProfiles.indexOf(profile) === -1)
            return ;

        page.currentProfile = profile;
        profileSet.command = ["powerprofilesctl", "set", profile];
        profileSet.running = true;
    }

    function refresh() {
        if (!profileGet.running)
            profileGet.running = true;

        if (!profileList.running)
            profileList.running = true;

        if (!batteryGet.running)
            batteryGet.running = true;

    }

    Component.onCompleted: page.refresh()

    Process {
        id: profileGet

        command: ["powerprofilesctl", "get"]

        stdout: StdioCollector {
            onStreamFinished: {
                const profile = text.trim();
                if (profile.length > 0)
                    page.currentProfile = profile;

            }
        }

    }

    Process {
        id: profileList

        command: ["powerprofilesctl", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                const re = /^\s*\*?\s*([\w-]+):\s*$/gm;
                let match;
                while ((match = re.exec(text)) !== null)
                    found.push(match[1]);
                if (found.length > 0) {
                    const preferredOrder = ["power-saver", "balanced", "performance"];
                    found.sort(function(a, b) {
                        let ai = preferredOrder.indexOf(a);
                        let bi = preferredOrder.indexOf(b);
                        if (ai === -1)
                            ai = preferredOrder.length;

                        if (bi === -1)
                            bi = preferredOrder.length;

                        return ai - bi;
                    });
                    page.availableProfiles = found;
                }
            }
        }

    }

    Process {
        id: profileSet

        onExited: (exitCode) => {
            if (exitCode !== 0)
                Quickshell.execDetached(["notify-send", "Power profile", "Failed to change the power profile. Is power-profiles-daemon running?"]);

            refreshTimer.restart();
        }
    }

    Process {
        id: batteryGet

        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do " + "if [ -r \"$b/capacity\" ] && [ -r \"$b/status\" ]; then " + "cat \"$b/capacity\"; cat \"$b/status\"; exit 0; fi; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length >= 2 && lines[0].length > 0) {
                    const percent = parseInt(lines[0]);
                    if (!isNaN(percent)) {
                        page.batteryPercent = Math.max(0, Math.min(100, percent));
                        page.batteryStatus = lines[1].trim();
                        page.hasBattery = true;
                        return ;
                    }
                }
                page.hasBattery = false;
            }
        }

    }

    Timer {
        id: refreshTimer

        interval: 400
        onTriggered: page.refresh()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (!batteryGet.running)
                batteryGet.running = true;

            if (!profileGet.running)
                profileGet.running = true;

        }
    }

    Flickable {
        id: flick

        anchors.fill: parent
        anchors.leftMargin: page.marginLeft
        anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop
        anchors.bottomMargin: page.marginBottom
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content

            width: flick.width
            spacing: 14

            Text {
                text: "POWER"
                color: Theme.text
                font.family: "Noto Sans"
                font.pixelSize: 19
                font.letterSpacing: 3
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Column {
                width: parent.width
                spacing: 10

                Text {
                    text: "POWER PROFILE"
                    color: Theme.text
                    font.family: "Noto Sans"
                    font.pixelSize: 15
                    font.bold: true
                    font.letterSpacing: 2
                }

                Text {
                    width: parent.width
                    text: page.currentProfile.length > 0 ? "CURRENT: " + page.currentProfile.toUpperCase() : "CURRENT: DETECTING..."
                    color: Theme.textDim
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                }

                Row {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: page.availableProfiles

                        delegate: Rectangle {
                            id: card

                            required property string modelData
                            readonly property bool selected: page.currentProfile === modelData
                            property bool hovered: false

                            width: (parent.width - parent.spacing * (page.availableProfiles.length - 1)) / Math.max(1, page.availableProfiles.length)
                            height: 100
                            radius: Theme.radius
                            color: selected ? Theme.alpha(Theme.accent, 0.1) : hovered ? Theme.alpha(Theme.accent, 0.08) : "#00000000"
                            border.width: 1
                            border.color: (selected || hovered) ? Theme.accent : Theme.border

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: Theme.radius
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: card.selected ? Theme.alpha(Theme.accent, 0.1) : Theme.alpha("#A0A0A0", 0.15)
                                    border.width: 1
                                    border.color: card.selected ? Theme.accent : Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: page.profileIcon(card.modelData)
                                        color: card.selected ? Theme.accent : "#A0A0A0"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 12
                                    }

                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: page.profileLabel(card.modelData)
                                    color: Theme.text
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 1
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: page.profileDescription(card.modelData)
                                    color: Theme.textDim
                                    font.family: "Noto Sans"
                                    font.pixelSize: 9
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: card.selected
                                    text: "ACTIVE"
                                    color: Theme.accent
                                    font.family: "Noto Sans"
                                    font.pixelSize: 9
                                    font.bold: true
                                }

                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !profileSet.running
                                onEntered: card.hovered = true
                                onExited: card.hovered = false
                                onClicked: {
                                    if (!card.selected)
                                        page.setProfile(card.modelData);

                                }
                            }

                        }

                    }

                }

                Text {
                    visible: page.availableProfiles.length === 0
                    width: parent.width
                    text: "No power profiles detected. Is power-profiles-daemon running?"
                    color: Theme.textDim
                    font.family: "Noto Sans"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: "Profiles are managed by power-profiles-daemon."
                    color: Theme.textDim
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

            }

            Rectangle {
                visible: page.hasBattery
                width: parent.width
                height: 100
                radius: Theme.radius
                color: "#00000000"
                border.width: 1
                border.color: Theme.border

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Row {
                        spacing: 10

                        Text {
                            text: "BATTERY"
                            color: Theme.text
                            font.family: "Noto Sans"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            text: page.batteryStatus.toUpperCase()
                            color: Theme.textDim
                            font.family: "Noto Sans"
                            font.pixelSize: 12
                        }

                        Text {
                            visible: page.batteryStatus === "Charging"
                            text: "CHARGING"
                            color: Theme.accent2
                            font.family: "Noto Sans"
                            font.pixelSize: 10
                        }

                    }

                    Item {
                        width: parent.width
                        height: levelLabel.implicitHeight

                        Text {
                            id: levelLabel

                            anchors.left: parent.left
                            text: "LEVEL"
                            color: Theme.textDim
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                        }

                        Text {
                            anchors.right: parent.right
                            text: page.batteryPercent + "%"
                            color: Theme.text
                            font.family: "Noto Sans"
                            font.pixelSize: 11
                        }

                    }

                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Theme.alpha("#A0A0A0", 0.15)

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, page.batteryPercent / 100))
                            height: parent.height
                            radius: 3
                            color: page.batteryPercent <= 15 ? "#E05555" : Theme.accent2

                            Behavior on width {
                                NumberAnimation {
                                    duration: 200
                                }

                            }

                        }

                    }

                }

            }

        }

        ScrollBar.vertical: ScrollBar {
            id: scrollBar

            background: Rectangle {
                color: "transparent"
                radius: width / 2
            }

            contentItem: Rectangle {
                color: Theme.accent
                radius: width / 2
            }

        }

    }

}
