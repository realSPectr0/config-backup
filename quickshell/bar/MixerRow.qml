import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: "󰕾"
    property string label: ""
    property string sublabel: ""
    property string font_: "JetBrainsMono Nerd Font"
    property color fg: "#d0d0d0"
    property color dim: "#777777"
    property color bg: "#1a1a1a"
    property color border_: "#2a2a2a"
    property color accent: "#a78bfa"
    property color red: "#f38ba8"
    property bool muted: false
    property bool active: false
    property bool defaultable: false
    property int volume: 0
    property int liveVolume: volume

    signal volumePreview(int value)
    signal volumeCommitted(int value)
    signal muteClicked()
    signal defaultClicked()

    onVolumeChanged: liveVolume = volume

    implicitHeight: 78
    radius: 9
    color: active
        ? Qt.rgba(accent.r, accent.g, accent.b, 0.16)
        : rowArea.containsMouse
            ? Qt.lighter(bg, 1.12)
            : bg
    border.width: 1
    border.color: active
        ? Qt.rgba(accent.r, accent.g, accent.b, 0.65)
        : rowArea.containsMouse
            ? Qt.lighter(border_, 1.55)
            : border_

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Timer {
        id: commitTimer
        interval: 80
        repeat: false
        onTriggered: root.volumeCommitted(root.liveVolume)
    }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
            topMargin: 8
            bottomMargin: 8
        }
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            Layout.alignment: Qt.AlignVCenter
            radius: 12
            color: Qt.rgba(accent.r, accent.g, accent.b, active ? 0.22 : 0.12)
            border.width: 1
            border.color: Qt.rgba(accent.r, accent.g, accent.b, active ? 0.60 : 0.28)

            Text {
                anchors.centerIn: parent
                text: root.muted ? "󰝟" : root.icon
                color: root.muted ? root.red : root.accent
                font { pixelSize: 19; family: root.font_ }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: root.label
                        color: root.fg
                        font { pixelSize: 12; family: root.font_ }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: root.sublabel.length > 0
                        text: root.sublabel
                        color: root.dim
                        font { pixelSize: 10; family: root.font_ }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    visible: root.defaultable
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 26
                    radius: 7
                    color: root.active
                        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.20)
                        : defArea.containsMouse
                            ? Qt.lighter(root.bg, 1.22)
                            : Qt.darker(root.bg, 1.08)
                    border.width: 1
                    border.color: root.active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55) : root.border_

                    Text {
                        anchors.centerIn: parent
                        text: root.active ? "Default" : "Use"
                        color: root.active ? root.accent : root.dim
                        font { pixelSize: 10; family: root.font_ }
                    }

                    MouseArea {
                        id: defArea
                        anchors.fill: parent
                        enabled: root.defaultable
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.defaultClicked()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 26
                    radius: 7
                    color: muteArea.containsMouse ? Qt.lighter(root.bg, 1.22) : Qt.darker(root.bg, 1.08)
                    border.width: 1
                    border.color: root.muted ? Qt.rgba(root.red.r, root.red.g, root.red.b, 0.55) : root.border_

                    Text {
                        anchors.centerIn: parent
                        text: root.muted ? "󰝟" : "󰕾"
                        color: root.muted ? root.red : root.dim
                        font { pixelSize: 12; family: root.font_ }
                    }

                    MouseArea {
                        id: muteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.muteClicked()
                    }
                }

                Text {
                    text: root.liveVolume + "%"
                    color: root.liveVolume > 100 ? root.red : root.accent
                    font { pixelSize: 11; family: root.font_ }
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 42
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            AudioSlider {
                Layout.fillWidth: true
                value: root.liveVolume
                maxValue: 150
                muted: root.muted
                bg: Qt.darker(root.bg, 1.38)
                fill: root.liveVolume > 100 ? root.red : root.accent
                knob: root.fg
                onMoved: value => {
                    root.liveVolume = value
                    root.volumePreview(value)
                    commitTimer.restart()
                }
            }
        }
    }
}
