import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var parentWindow: null
    property color fg: "#d0d0d0"
    property color dim: "#555555"
    property color bg: "#1a1a1a"
    property color border_: "#2a2a2a"
    property color accent: "#a78bfa"
    property color blue: "#5ba8d4"
    property color green: "#86efac"
    property color yellow: "#fbbf24"
    property color red: "#f87171"
    property string font_: "JetBrainsMono Nerd Font"

    signal activated()

    function itemIdentity(item) {
        if (!item)
            return ""

        const keys = ["id", "title", "tooltipTitle", "tooltipDescription", "icon"]
        let parts = []
        for (let i = 0; i < keys.length; i++) {
            const value = item[keys[i]]
            if (value !== undefined && value !== null)
                parts.push(value.toString())
        }
        return parts.join(" ").toLowerCase()
    }

    function symbolFor(item) {
        const name = itemIdentity(item)
        if (name.includes("discord") || name.includes("vesktop"))
            return "󰙯"
        if (name.includes("steam"))
            return "󰓓"
        if (name.includes("spotify"))
            return "󰓇"
        if (name.includes("telegram"))
            return "󰍡"
        if (name.includes("slack"))
            return "󰒱"
        if (name.includes("signal"))
            return "󰭹"
        if (name.includes("obs") || name.includes("record"))
            return "󰻃"
        if (name.includes("flameshot") || name.includes("screenshot"))
            return "󰹑"
        if (name.includes("dropbox") || name.includes("drive") || name.includes("sync"))
            return "󰇣"
        if (name.includes("update") || name.includes("package"))
            return "󰚰"
        if (name.includes("network") || name.includes("nm-applet"))
            return "󰖩"
        if (name.includes("bluetooth"))
            return ""
        if (name.includes("audio") || name.includes("volume"))
            return "󰕾"
        if (name.includes("battery") || name.includes("power"))
            return "󰁹"
        return ""
    }

    function accentFor(item) {
        const name = itemIdentity(item)
        if (name.includes("spotify"))
            return green
        if (name.includes("steam") || name.includes("telegram") || name.includes("network") || name.includes("bluetooth"))
            return blue
        if (name.includes("obs") || name.includes("record") || name.includes("flameshot") || name.includes("screenshot"))
            return red
        if (name.includes("update") || name.includes("package"))
            return yellow
        return accent
    }

    function iconSourceFor(item) {
        let icon = item && item.icon
        if (!icon)
            return ""
        if (icon.includes("?path=")) {
            const split = icon.split("?path=")
            if (split.length !== 2)
                return icon
            return "file://" + split[1] + "/" + split[0].substring(split[0].lastIndexOf("/") + 1)
        }
        if (icon.startsWith("/") && !icon.startsWith("file://"))
            return "file://" + icon
        return icon
    }

    function showMenu(item, anchor) {
        if (!item || !item.hasMenu || !parentWindow)
            return
        const point = anchor.mapToItem(null, anchor.width / 2, anchor.height)
        item.display(parentWindow, Math.round(point.x), Math.round(point.y))
    }

    implicitHeight: 38
    implicitWidth: Math.max(44, trayRow.implicitWidth + 18)
    radius: 9
    color: bg
    border.width: 4
    border.color: Qt.rgba(border_.r, border_.g, border_.b, 0.45)

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: 4

        Rectangle {
            visible: SystemTray.items.values.length === 0
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 8
            color: Qt.lighter(root.bg, 1.04)
            border.width: 1
            border.color: Qt.rgba(root.border_.r, root.border_.g, root.border_.b, 0.22)

            Text {
                anchors.centerIn: parent
                text: "󰇙"
                color: root.dim
                font { pixelSize: 15; family: root.font_ }
            }
        }

        Repeater {
            model: SystemTray.items.values

            Rectangle {
                id: trayItem
                property var item: modelData
                property string iconSource: root.iconSourceFor(item)
                property string symbol: root.symbolFor(item)
                property color itemAccent: root.accentFor(item)
                readonly property bool hasSymbol: symbol.length > 0
                readonly property bool hovered: trayArea.containsMouse
                readonly property bool pressed: trayArea.pressed

                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 8
                scale: trayItem.pressed ? 0.92 : trayItem.hovered ? 1.07 : 1
                color: trayItem.pressed
                    ? Qt.lighter(root.bg, 1.24)
                    : trayItem.hovered
                        ? Qt.rgba(trayItem.itemAccent.r, trayItem.itemAccent.g, trayItem.itemAccent.b, 0.14)
                        : Qt.lighter(root.bg, 1.04)
                border.width: 1
                border.color: trayItem.hovered
                    ? Qt.rgba(trayItem.itemAccent.r, trayItem.itemAccent.g, trayItem.itemAccent.b, 0.58)
                    : Qt.rgba(root.border_.r, root.border_.g, root.border_.b, 0.22)

                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Rectangle {
                    anchors.centerIn: parent
                    width: trayItem.hovered ? 20 : trayItem.hasSymbol ? 18 : 0
                    height: width
                    radius: width / 2
                    color: Qt.rgba(trayItem.itemAccent.r, trayItem.itemAccent.g, trayItem.itemAccent.b, trayItem.hovered ? 0.18 : 0.08)
                    visible: width > 0

                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Text {
                    visible: trayItem.hasSymbol
                    anchors.centerIn: parent
                    text: trayItem.symbol
                    color: trayItem.itemAccent
                    font { pixelSize: 15; family: root.font_; bold: true }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                IconImage {
                    visible: !trayItem.hasSymbol && trayItem.iconSource.length > 0
                    anchors.centerIn: parent
                    width: trayItem.hovered ? 20 : 18
                    height: width
                    source: trayItem.iconSource
                    asynchronous: true
                    mipmap: true
                    opacity: trayItem.hovered ? 1 : 0.9

                    Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Text {
                    visible: !trayItem.hasSymbol && trayItem.iconSource.length === 0
                    anchors.centerIn: parent
                    text: "󰣆"
                    color: trayItem.itemAccent
                    font { pixelSize: 15; family: root.font_; bold: true }
                }

                MouseArea {
                    id: trayArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (!trayItem.item)
                            return
                        root.activated()
                        if (mouse.button === Qt.RightButton) {
                            root.showMenu(trayItem.item, trayItem)
                        } else if (mouse.button === Qt.MiddleButton) {
                            trayItem.item.secondaryActivate()
                        } else if (trayItem.item.onlyMenu) {
                            root.showMenu(trayItem.item, trayItem)
                        } else {
                            trayItem.item.activate()
                        }
                    }
                    onWheel: wheel => {
                        if (trayItem.item)
                            trayItem.item.scroll(wheel.angleDelta.y, false)
                    }
                }
            }
        }
    }
}
