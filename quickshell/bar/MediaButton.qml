import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: ""
    property color fg: "#d8e6f2"
    property color dim: "#8ba4bc"
    property color bg: "#101827"
    property color border_: "#1d3450"
    property color accent: "#7c8ef0"
    property color red: "#f87171"
    property bool active: false
    property bool danger: false
    property bool primary: false
    property real size: 40
    property real iconSize: 16
    property string font_: "JetBrainsMono Nerd Font"

    signal clicked()

    Layout.preferredWidth: root.size
    Layout.preferredHeight: root.size
    radius: root.size / 2
    opacity: root.enabled ? 1 : 0.36
    scale: ma.pressed ? 0.96 : ma.containsMouse ? 1.04 : 1
    color: root.primary
        ? ma.pressed
            ? Qt.lighter(root.accent, 1.12)
            : ma.containsMouse
                ? Qt.lighter(root.accent, 1.06)
                : root.accent
        : ma.pressed
            ? Qt.lighter(root.bg, 1.24)
            : ma.containsMouse || root.active
                ? Qt.lighter(root.bg, 1.14)
                : Qt.lighter(root.bg, 1.04)
    border.width: 1
    border.color: root.primary
        ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.28)
        : root.danger
            ? Qt.rgba(root.red.r, root.red.g, root.red.b, ma.containsMouse ? 0.72 : 0.42)
            : root.active
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.70)
                : ma.containsMouse
                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.42)
                    : Qt.rgba(root.border_.r, root.border_.g, root.border_.b, 0.52)

    Behavior on scale { NumberAnimation { duration: 90 } }
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.primary
            ? root.bg
            : root.danger
                ? root.red
                : root.active
                    ? root.accent
                    : root.fg
        font { pixelSize: root.iconSize; family: root.font_; bold: root.primary }
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
