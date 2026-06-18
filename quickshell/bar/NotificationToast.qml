import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    property color cBg: "#0b1018"
    property color cCard: "#101827"
    property color cBord: "#1d3450"
    property color cFg: "#d8e6f2"
    property color cDim: "#8ba4bc"
    property color cAccent: "#7c8ef0"
    property color cRed: "#f87171"
    property color warmAccent: "#ffd179"
    property string cFont: "JetBrainsMono Nerd Font"

    property var toasts: []

    function safeImageSource(source) {
        const text = (source || "").toString()
        return text.startsWith("image://qsimage/") ? "" : text
    }

    function addToast(item) {
        const duration = item.urgency === 2 ? 10000 : 5000
        const toast = {
            id: "t" + Date.now() + Math.random(),
            appName: item.appName || "App",
            summary: item.summary || "Notification",
            body: item.body || "",
            image: item.image || "",
            urgency: item.urgency,
            expiresAt: Date.now() + duration,
            duration: duration
        }
        const next = [toast]
        for (const t of root.toasts) {
            next.push(t)
            if (next.length >= 4) break
        }
        root.toasts = next
    }

    function dismiss(id) {
        root.toasts = root.toasts.filter(t => t.id !== id)
    }

    visible: toasts.length > 0
    color: "transparent"
    anchors { top: true; right: true }
    margins { top: 54; right: 10 }
    implicitWidth: 360
    implicitHeight: Math.max(1, toastCol.implicitHeight + 8)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notification-toast"
    WlrLayershell.exclusiveZone: -1

    Timer {
        interval: 250
        repeat: true
        running: root.toasts.length > 0
        onTriggered: {
            const now = Date.now()
            const next = root.toasts.filter(t => t.expiresAt > now)
            if (next.length !== root.toasts.length)
                root.toasts = next
        }
    }

    Column {
        id: toastCol
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 4 }
        spacing: 8

        Repeater {
            model: root.toasts

            Rectangle {
                id: card
                width: toastCol.width
                height: Math.max(70, cardContent.implicitHeight + 22)
                radius: 12
                color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.95)
                border.width: modelData.urgency === 2 ? 2 : 1
                border.color: modelData.urgency === 2
                    ? Qt.rgba(root.cRed.r, root.cRed.g, root.cRed.b, 0.80)
                    : Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.36)
                clip: true

                opacity: 0
                Component.onCompleted: fadeIn.running = true

                NumberAnimation {
                    id: fadeIn
                    target: card
                    property: "opacity"
                    from: 0; to: 1
                    duration: 200
                    easing.type: Easing.OutCubic
                }

                RowLayout {
                    id: cardContent
                    anchors { fill: parent; margins: 12; bottomMargin: 16 }
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignTop
                        radius: 9
                        color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.34)
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.safeImageSource(modelData.image)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: source.toString().length > 0 && status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: (modelData.appName || "?").charAt(0).toUpperCase()
                            color: root.cAccent
                            font { pixelSize: 15; family: root.cFont; bold: true }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: modelData.appName
                                color: root.cAccent
                                font { pixelSize: 9; family: root.cFont; bold: true }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "✕"
                                color: root.cDim
                                font { pixelSize: 11; family: root.cFont }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.dismiss(modelData.id)
                                }
                            }
                        }

                        Text {
                            text: modelData.summary
                            color: root.cFg
                            font { pixelSize: 12; family: root.cFont; bold: true }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: modelData.body.length > 0
                            text: modelData.body
                            color: root.cDim
                            font { pixelSize: 10; family: root.cFont }
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // auto-dismiss progress bar
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 3
                    color: "transparent"
                    radius: 2

                    Rectangle {
                        id: progressBar
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: parent.width
                        radius: 2
                        color: modelData.urgency === 2 ? root.cRed : root.warmAccent
                        opacity: 0.7

                        NumberAnimation on width {
                            from: progressBar.parent.width
                            to: 0
                            duration: modelData.duration
                            easing.type: Easing.Linear
                            running: true
                        }
                    }
                }
            }
        }
    }
}
