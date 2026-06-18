import QtQuick
import QtQuick.Layouts

Rectangle {
    id: pill

    property string label:   ""
    property string font_:   "JetBrainsMono Nerd Font"
    property color  fg:      "#d0d0d0"
    property color  bg:      "#1a1a1a"
    property color  border_: "#2b2b2b"
    property color  accent:  "#a78bfa"
    property real   fontSize: 13
    property real   minW:    0
    property real   maxW:    0
    property bool   clickable: false
    property bool   active: false

    signal clicked()

    readonly property bool hovered: pill.clickable && ma.containsMouse
    readonly property bool pressed: pill.clickable && ma.pressed

    implicitHeight: 38
    readonly property real horizontalPad: pill.clickable ? 32 : 24
    implicitWidth: pill.maxW > 0
        ? Math.min(pill.maxW, Math.max(minW, pillText.implicitWidth + horizontalPad))
        : Math.max(minW, pillText.implicitWidth + horizontalPad)
    radius: 9
    scale: pill.pressed ? 0.98 : pill.hovered ? 1.01 : 1
    color: pill.active
        ? Qt.lighter(pill.bg, 1.16)
        : pill.pressed
            ? Qt.lighter(pill.bg, 1.22)
            : pill.hovered
                ? Qt.lighter(pill.bg, 1.12)
                : pill.bg
    border.width: 4
    border.color: pill.active
        ? Qt.rgba(pill.accent.r, pill.accent.g, pill.accent.b, 0.68)
        : pill.hovered
            ? Qt.lighter(pill.border_, 1.45)
            : Qt.rgba(pill.border_.r, pill.border_.g, pill.border_.b, 0.45)

    Behavior on scale        { NumberAnimation { duration: 90 } }
    Behavior on color        { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
        id: pillText
        anchors.centerIn: parent
        width: Math.max(1, parent.width - pill.horizontalPad)
        horizontalAlignment: Text.AlignHCenter
        text: pill.label
        color: pill.active ? Qt.lighter(pill.fg, 1.15) : pill.fg
        font { pixelSize: pill.fontSize; family: pill.font_; letterSpacing: 0 }
        elide: Text.ElideRight
        maximumLineCount: 1
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: pill.clickable
        hoverEnabled: true
        onClicked: pill.clicked()
        cursorShape: Qt.PointingHandCursor
    }
}
