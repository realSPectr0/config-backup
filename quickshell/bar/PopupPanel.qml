import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: popup

    property bool showing: false
    property string title: ""
    property string subtitle: ""
    property int panelWidth: 340
    property color cBg: "#111111"
    property color cCard: "#181818"
    property color cBord: "#303030"
    property color cFg: "#d0d0d0"
    property color cDim: "#777777"
    property color cAccent: "#a78bfa"
    property color cWarm: "#ffb3a4"
    property string cFont: "JetBrainsMono Nerd Font"
    property bool keyboardFocus: false
    property real anchorCenterX: screenWidth - panelWidth / 2 - edgeGap
    readonly property int barTopGap: 5
    readonly property int barHeight: 44
    readonly property int popupGap: 4
    readonly property int edgeGap: 8
    readonly property real screenWidth: popup.screen?.width ?? 1920
    readonly property real panelLeft: Math.round(Math.max(edgeGap, Math.min(screenWidth - panelWidth - edgeGap, anchorCenterX - panelWidth / 2)))

    default property alias bodyContent: body.data

    signal dismissRequested()

    visible: showing
    color: "transparent"
    implicitWidth: panelWidth
    implicitHeight: Math.max(1, contentColumn.implicitHeight + 20)

    anchors { top: true; left: true }
    margins { top: barTopGap + barHeight + popupGap; left: popup.panelLeft }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-bar-popup"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: popup.keyboardFocus && popup.showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(popup.cBg.r, popup.cBg.g, popup.cBg.b, 0.94)
        border.width: 2
        border.color: Qt.rgba(popup.cWarm.r, popup.cWarm.g, popup.cWarm.b, 0.22)
        clip: true
        antialiasing: true

        Rectangle {
            width: Math.max(parent.width, parent.height) * 0.92
            height: width
            radius: width / 2
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: -20
            }
            color: Qt.rgba(popup.cWarm.r, popup.cWarm.g, popup.cWarm.b, 0.045)
        }

        Rectangle {
            width: Math.max(parent.width, parent.height) * 0.58
            height: width
            radius: width / 2
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: -8
            }
            color: Qt.rgba(popup.cWarm.r, popup.cWarm.g, popup.cWarm.b, 0.045)
        }

        ColumnLayout {
            id: contentColumn
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 4
                    Layout.preferredHeight: 28
                    radius: 2
                    color: popup.cWarm
                    opacity: 0.9
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: popup.title
                        color: popup.cFg
                        font { pixelSize: 14; family: popup.cFont; bold: true }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: popup.subtitle.length > 0
                        text: popup.subtitle
                        color: popup.cDim
                        font { pixelSize: 10; family: popup.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    id: closeButton
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 7
                    color: closeMa.pressed
                        ? Qt.rgba(popup.cWarm.r, popup.cWarm.g, popup.cWarm.b, 0.18)
                        : closeMa.containsMouse
                            ? Qt.rgba(popup.cWarm.r, popup.cWarm.g, popup.cWarm.b, 0.12)
                            : Qt.rgba(popup.cCard.r, popup.cCard.g, popup.cCard.b, 0.72)
                    border.width: 1
                    border.color: closeMa.containsMouse ? Qt.rgba(popup.cWarm.r, popup.cWarm.g, popup.cWarm.b, 0.42) : Qt.rgba(popup.cFg.r, popup.cFg.g, popup.cFg.b, 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: "x"
                        color: popup.cDim
                        font { pixelSize: 13; family: popup.cFont }
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.dismissRequested()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: popup.cBord
                opacity: 0.42
            }

            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: 8
            }
        }
    }
}
