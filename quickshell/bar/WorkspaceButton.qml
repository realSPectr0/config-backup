import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int workspaceId: 1
    property bool active: false
    property bool occupied: false
    property bool urgent: false
    property color fg: "#d0d0d0"
    property color dim: "#555555"
    property color bg: "#1a1a1a"
    property color border_: "#2a2a2a"
    property color accent: "#a78bfa"
    property color red: "#f38ba8"
    property string font_: "JetBrainsMono Nerd Font"

    signal clicked()

    Layout.preferredWidth: 30
    Layout.preferredHeight: 34

    Rectangle {
        id: btn
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.active ? 30 : 26
        height: 26
        radius: 8
        scale: ma.pressed ? 0.94 : ma.containsMouse ? 1.03 : 1

        color: root.urgent
            ? Qt.rgba(root.red.r, root.red.g, root.red.b, 0.18)
            : root.active
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.82)
                : ma.containsMouse
                    ? Qt.lighter(root.bg, 1.16)
                    : Qt.lighter(root.bg, 1.04)

        border.width: 0

        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on width { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: root.workspaceId
            color: root.urgent ? root.red
                : root.active ? "#ffffff"
                : root.occupied ? Qt.lighter(root.fg, 1.15)
                : root.dim
            font {
                pixelSize: 12
                family: root.font_
                bold: root.active
                letterSpacing: 0.5
            }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    // dot indicator for occupied workspaces
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.active ? 14 : root.occupied ? 5 : 0
        height: 3
        radius: 2
        color: root.urgent ? root.red
            : root.active ? root.accent
            : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
        visible: root.active || root.occupied
        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
