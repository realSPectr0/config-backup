import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property bool active: false
    readonly property int barTopGap: 5
    readonly property int barHeight: 44
    readonly property real screenWidth: root.screen?.width ?? 1920
    readonly property real screenHeight: root.screen?.height ?? 1080
    readonly property real inputTop: barTopGap + barHeight

    signal clickedAway()

    visible: active
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-bar-click-away"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: inputRegion }

    Rectangle {
        id: inputRegion
        visible: false
        x: 0
        y: root.inputTop
        width: root.active ? root.screenWidth : 0
        height: root.active ? Math.max(0, root.screenHeight - root.inputTop) : 0
    }

    MouseArea {
        x: 0
        y: root.inputTop
        width: root.screenWidth
        height: Math.max(0, root.screenHeight - root.inputTop)
        enabled: root.active
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: false
        onPressed: root.clickedAway()
    }
}
