import Quickshell.Services.Mpris
import QtQuick

Rectangle {
    id: root

    property color fg: "#d8e6f2"
    property color dim: "#8ba4bc"
    property color bg: "#0e1828"
    property color border_: "#1d3450"
    property color accent: "#7c8ef0"
    property color blue: "#5ba8d4"
    property string font_: "JetBrainsMono Nerd Font"
    property bool active: false

    signal openRequested()

    readonly property var players: Mpris.players.values.filter(p => !root.isHoverPreview(p))
    readonly property MprisPlayer activePlayer: players.find(p => p.playbackState === MprisPlaybackState.Playing)
        ?? players.find(p => p.canControl && p.canPlay)
        ?? null
    readonly property bool playerAvailable: activePlayer !== null
    readonly property bool playing: activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property color glowColor: playing ? accent : blue
    readonly property bool hovered: hoverHandler.hovered
    readonly property string mediaIcon: playing ? "󰎆" : "󰝛"

    function isHoverPreview(player) {
        if (!player)
            return false
        const id = (player.identity || "").toLowerCase()
        if (!id.includes("firefox"))
            return false
        const url = (player.metadata?.["xesam:url"] || "").toString()
        return /^https?:\/\/(www\.)?youtube\.com\/?($|\?|#)/i.test(url)
    }

    visible: playerAvailable
    implicitWidth: playerAvailable ? 48 : 0
    implicitHeight: 38
    radius: 9
    clip: true
    scale: clickArea.pressed ? 0.98 : hovered ? 1.01 : 1
    color: active
        ? Qt.lighter(root.bg, 1.16)
        : clickArea.pressed
            ? Qt.lighter(root.bg, 1.22)
            : hovered
                ? Qt.lighter(root.bg, 1.12)
                : root.bg
    border.width: 4
    border.color: hovered || active
        ? Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.62)
        : Qt.rgba(root.border_.r, root.border_.g, root.border_.b, 0.45)

    Behavior on scale { NumberAnimation { duration: 110 } }
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    HoverHandler { id: hoverHandler }

    Text {
        anchors.fill: parent
        anchors.leftMargin: -1
        text: root.mediaIcon
        color: root.playing ? root.accent : root.fg
        font { pixelSize: 16; family: root.font_; letterSpacing: 0 }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openRequested()
        onWheel: wheel => {
            if (!root.activePlayer || !root.activePlayer.canSeek || root.activePlayer.length <= 0)
                return
            const delta = wheel.angleDelta.y > 0 ? 5 : -5
            root.activePlayer.position = Math.max(0, Math.min(root.activePlayer.length * 0.99, (root.activePlayer.position || 0) + delta))
        }
    }
}
