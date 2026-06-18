import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property string font_: "JetBrainsMono Nerd Font"
    property color fg: "#d0d0d0"
    property color dim: "#777777"
    property color bg: "#1a1a1a"
    property color border_: "#2a2a2a"
    property color accent: "#a78bfa"
    property color red: "#f38ba8"
    property bool danger: false
    property bool active: false

    signal clicked()

    Layout.fillWidth: true
    implicitHeight: sublabel.length > 0 ? 48 : 40
    radius: 7
    opacity: enabled ? 1 : 0.45
    color: active
        ? Qt.lighter(bg, 1.16)
        : ma.pressed
            ? Qt.lighter(bg, 1.24)
            : ma.containsMouse
                ? Qt.lighter(bg, 1.15)
                : bg
    border.width: 1
    border.color: danger
        ? Qt.rgba(red.r, red.g, red.b, ma.containsMouse ? 0.75 : 0.38)
        : active
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.7)
            : ma.containsMouse
                ? Qt.lighter(border_, 1.65)
                : border_

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
        }
        spacing: 10

        Text {
            text: root.icon
            color: root.danger ? root.red : root.active ? root.accent : root.fg
            font { pixelSize: 16; family: root.font_ }
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: 22
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Text {
                text: root.label
                color: root.danger ? root.red : root.fg
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
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
