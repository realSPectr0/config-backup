import QtQuick

Rectangle {
    id: root

    property int value: 0
    property int maxValue: 150
    property color bg: "#202020"
    property color fill: "#a78bfa"
    property color knob: "#e5e7eb"
    property bool muted: false

    signal moved(int value)

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v))
    }

    function valueFromX(x) {
        return Math.round(clamp(x / Math.max(1, width), 0, 1) * maxValue)
    }

    implicitHeight: 24
    radius: 12
    color: "transparent"

    Rectangle {
        id: rail
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: 12
        radius: 6
        color: root.bg
        opacity: root.muted ? 0.55 : 1
        clip: true

        Rectangle {
            height: parent.height
            width: parent.width * root.clamp(root.value, 0, root.maxValue) / root.maxValue
            radius: parent.radius
            color: root.fill
            opacity: root.muted ? 0.35 : 0.95
        }
    }

    Rectangle {
        width: 18
        height: 18
        radius: 9
        x: root.clamp(
            rail.width * root.clamp(root.value, 0, root.maxValue) / root.maxValue - width / 2,
            0,
            Math.max(0, root.width - width)
        )
        anchors.verticalCenter: parent.verticalCenter
        color: sliderArea.pressed ? Qt.lighter(root.knob, 1.08) : root.knob
        border.width: 2
        border.color: root.fill
        scale: sliderArea.pressed ? 1.08 : sliderArea.containsMouse ? 1.04 : 1

        Behavior on scale { NumberAnimation { duration: 90 } }
    }

    MouseArea {
        id: sliderArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => root.moved(root.valueFromX(mouse.x))
        onPositionChanged: mouse => {
            if (pressed)
                root.moved(root.valueFromX(mouse.x))
        }
        onWheel: wheel => {
            const delta = wheel.angleDelta.y > 0 ? 2 : -2
            root.moved(root.clamp(root.value + delta, 0, root.maxValue))
        }
    }
}
