import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

PanelWindow {
    id: root

    property bool showing: false
    property real anchorCenterX: screenWidth - panelWidth / 2 - edgeGap
    property int panelWidth: 700
    property int panelHeight: 490
    property color cBg: "#0b1018"
    property color cCard: "#101827"
    property color cBord: "#1d3450"
    property color cFg: "#d8e6f2"
    property color cDim: "#8ba4bc"
    property color cAccent: "#7c8ef0"
    property color cBlue: "#5ba8d4"
    property color cGreen: "#86efac"
    property color cYellow: "#fbbf24"
    property color cRed: "#f87171"
    property string cFont: "JetBrainsMono Nerd Font"
    property color warmAccent: "#ffb3a4"
    property MprisPlayer selectedPlayer: null
    property real restoreVolume: 0.7

    readonly property int barTopGap: 5
    readonly property int barHeight: 44
    readonly property int popupGap: 4
    readonly property int edgeGap: 8
    readonly property real screenWidth: root.screen?.width ?? 1920
    readonly property real panelLeft: Math.round(Math.max(edgeGap, Math.min(screenWidth - panelWidth - edgeGap, anchorCenterX - panelWidth / 2)))
    readonly property var players: Mpris.players.values.filter(p => !root.isHoverPreview(p))
    readonly property MprisPlayer activePlayer: selectedPlayer && players.indexOf(selectedPlayer) !== -1
        ? selectedPlayer
        : players.find(p => p.playbackState === MprisPlaybackState.Playing)
            ?? players.find(p => p.canControl && p.canPlay)
            ?? null
    readonly property bool playing: activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property string title: cleanText(activePlayer?.trackTitle, "Nothing playing")
    readonly property string artist: cleanText(activePlayer?.trackArtist, activePlayer?.identity || "No active player")
    readonly property string album: cleanText(activePlayer?.trackAlbum, "")
    readonly property string artUrl: activePlayer?.trackArtUrl || ""
    readonly property string playerName: activePlayer?.desktopEntry || activePlayer?.identity || "player"
    readonly property bool loopActive: !!activePlayer && activePlayer.loopState !== MprisLoopState.None
    readonly property bool rateSupported: !!activePlayer && activePlayer.maxRate > activePlayer.minRate && activePlayer.maxRate > 0
    readonly property real progress: activePlayer && activePlayer.length > 0
        ? Math.max(0, Math.min(1, ((activePlayer.position || 0) % Math.max(1, activePlayer.length)) / activePlayer.length))
        : 0

    signal dismissRequested()

    function cleanText(value, fallback) {
        const text = (value || "").toString().trim()
        return text.length > 0 ? text : fallback
    }

    function isHoverPreview(player) {
        if (!player)
            return false
        const id = (player.identity || "").toLowerCase()
        if (!id.includes("firefox"))
            return false
        const url = (player.metadata?.["xesam:url"] || "").toString()
        return /^https?:\/\/(www\.)?youtube\.com\/?($|\?|#)/i.test(url)
    }

    function formatTime(value) {
        const safeValue = Math.max(0, value || 0)
        const minutes = Math.floor(safeValue / 60)
        const seconds = Math.floor(safeValue % 60)
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    function positionText() {
        if (!activePlayer)
            return "0:00"
        const rawPos = Math.max(0, activePlayer.position || 0)
        const pos = activePlayer.length ? rawPos % Math.max(1, activePlayer.length) : rawPos
        return formatTime(pos)
    }

    function seekToRatio(ratio) {
        if (!activePlayer || !activePlayer.canSeek || activePlayer.length <= 0)
            return
        activePlayer.position = Math.max(0, Math.min(activePlayer.length * 0.99, ratio * activePlayer.length))
    }

    function previousSmart() {
        if (!activePlayer)
            return
        if (activePlayer.position > 8 && activePlayer.canSeek)
            activePlayer.position = 0
        else if (activePlayer.canGoPrevious)
            activePlayer.previous()
    }

    function cycleLoop() {
        if (!activePlayer || !activePlayer.loopSupported)
            return
        switch (activePlayer.loopState) {
        case MprisLoopState.None:
            activePlayer.loopState = MprisLoopState.Playlist
            break
        case MprisLoopState.Playlist:
            activePlayer.loopState = MprisLoopState.Track
            break
        default:
            activePlayer.loopState = MprisLoopState.None
            break
        }
    }

    function loopIcon() {
        if (!activePlayer || activePlayer.loopState !== MprisLoopState.Track)
            return "󰑖"
        return "󰑘"
    }

    function setRate(delta) {
        if (!rateSupported)
            return
        const current = activePlayer.rate > 0 ? activePlayer.rate : 1
        const next = Math.max(activePlayer.minRate, Math.min(activePlayer.maxRate, current + delta))
        activePlayer.rate = Math.round(next * 100) / 100
    }

    function resetRate() {
        if (rateSupported)
            activePlayer.rate = 1
    }

    function toggleMute() {
        if (!activePlayer || !activePlayer.volumeSupported)
            return
        if (activePlayer.volume > 0) {
            restoreVolume = activePlayer.volume
            activePlayer.volume = 0
        } else {
            activePlayer.volume = Math.max(0.01, restoreVolume)
        }
    }

    visible: showing
    color: "transparent"
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    anchors { top: true; left: true }
    margins { top: barTopGap + barHeight + popupGap; left: root.panelLeft }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-bar-media-popup"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onShowingChanged: {
        if (showing && (!selectedPlayer || players.indexOf(selectedPlayer) === -1))
            selectedPlayer = activePlayer
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.showing && root.playing
        onTriggered: root.activePlayer?.positionChanged()
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 18
        color: Qt.darker(root.cBg, 1.04)
        border.width: 2
        border.color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.28)
        clip: true
        antialiasing: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 6
            shadowBlur: 0.55
            shadowColor: Qt.rgba(0, 0, 0, 0.62)
            shadowOpacity: 0.34
        }

        Rectangle {
            id: backgroundClip
            anchors {
                fill: parent
                margins: 2
            }
            radius: panel.radius - 2
            color: root.cBg
            clip: true
            antialiasing: true

            Image {
                id: bgImage
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: bgImage
                blurEnabled: true
                blurMax: 64
                blur: 0.60
                saturation: -0.20
                brightness: -0.22
                visible: bgImage.status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, bgImage.status === Image.Ready ? 0.48 : 0.12)
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.10) }
                    GradientStop { position: 0.52; color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.62) }
                    GradientStop { position: 1.0; color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.92) }
                }
            }

        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 18
            }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 130
                spacing: 16

                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 120
                    radius: 14
                    color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.80)
                    border.width: 1
                    border.color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.30)
                    clip: true

                    Image {
                        id: art
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        text: "󰎆"
                        color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.7)
                        font { pixelSize: 36; family: root.cFont }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 5

                    Text {
                        text: root.title
                        color: root.cFg
                        font { pixelSize: 20; family: root.cFont; bold: true }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.artist
                        color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.72)
                        font { pixelSize: 12; family: root.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.album
                        color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.40)
                        font { pixelSize: 10; family: root.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                        visible: root.album.length > 0
                    }

                    Item { height: 4 }

                    Rectangle {
                        height: 22
                        width: statusLabel.implicitWidth + 20
                        radius: 6
                        color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, root.playing ? 0.15 : 0.06)
                        border.width: 1
                        border.color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, root.playing ? 0.40 : 0.18)

                        Text {
                            id: statusLabel
                            anchors.centerIn: parent
                            text: root.playing ? "▶  playing" : "⏸  paused"
                            color: root.playing ? root.warmAccent : root.cDim
                            font { pixelSize: 9; family: root.cFont; bold: true }
                        }
                    }
                }

                MediaButton {
                    Layout.alignment: Qt.AlignTop
                    size: 28
                    iconSize: 11
                    icon: "x"
                    danger: true
                    fg: root.cFg; bg: root.cCard; border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                    onClicked: root.dismissRequested()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                spacing: 14

                Item { Layout.fillWidth: true }

                MediaButton {
                    size: 38
                    icon: "󰒟"
                    active: root.activePlayer?.shuffle ?? false
                    enabled: root.activePlayer?.shuffleSupported ?? false
                    fg: root.cFg; bg: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.72); border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                    onClicked: root.activePlayer.shuffle = !root.activePlayer.shuffle
                }

                MediaButton {
                    size: 42
                    iconSize: 17
                    icon: "󰒮"
                    enabled: root.activePlayer?.canGoPrevious ?? false
                    fg: root.cFg; bg: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.72); border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                    onClicked: root.previousSmart()
                }

                MediaButton {
                    size: 54
                    iconSize: 22
                    icon: root.playing ? "󰏤" : "󰐊"
                    primary: true
                    enabled: root.activePlayer?.canTogglePlaying ?? false
                    fg: root.cFg; bg: root.cBg; border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                    onClicked: root.activePlayer?.togglePlaying()
                }

                MediaButton {
                    size: 42
                    iconSize: 17
                    icon: "󰒭"
                    enabled: root.activePlayer?.canGoNext ?? false
                    fg: root.cFg; bg: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.72); border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                    onClicked: root.activePlayer?.next()
                }

                MediaButton {
                    size: 38
                    icon: root.loopIcon()
                    active: root.loopActive
                    enabled: root.activePlayer?.loopSupported ?? false
                    fg: root.cFg; bg: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.72); border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                    onClicked: root.cycleLoop()
                }

                Item { Layout.fillWidth: true }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10
                    radius: 5
                    color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.12)
                    clip: true

                    Rectangle {
                        width: parent.width * root.progress
                        height: parent.height
                        radius: parent.radius
                        color: root.warmAccent
                        Behavior on width { NumberAnimation { duration: 120 } }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                            shadowBlur: 1.0
                            shadowColor: root.warmAccent
                            shadowOpacity: 0.6
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: (root.activePlayer?.canSeek ?? false) && ((root.activePlayer?.length ?? 0) > 0)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => root.seekToRatio(Math.max(0, Math.min(1, mouse.x / Math.max(1, width))))
                        onPositionChanged: mouse => {
                            if (pressed)
                                root.seekToRatio(Math.max(0, Math.min(1, mouse.x / Math.max(1, width))))
                        }
                        onWheel: wheel => {
                            if (!root.activePlayer || !root.activePlayer.canSeek || root.activePlayer.length <= 0)
                                return
                            const delta = wheel.angleDelta.y > 0 ? 5 : -5
                            root.activePlayer.position = Math.max(0, Math.min(root.activePlayer.length * 0.99, (root.activePlayer.position || 0) + delta))
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.positionText()
                        color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.55)
                        font { pixelSize: 9; family: root.cFont }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.activePlayer?.length ? root.formatTime(root.activePlayer.length) : "0:00"
                        color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.55)
                        font { pixelSize: 9; family: root.cFont }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.68)
                    border.width: 1
                    border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.14)
                    opacity: root.activePlayer?.volumeSupported ? 1 : 0.44

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 8

                        MediaButton {
                            size: 32
                            iconSize: 14
                            icon: root.activePlayer?.volume === 0 ? "󰖁" : "󰕾"
                            enabled: root.activePlayer?.volumeSupported ?? false
                            fg: root.cFg; bg: root.cCard; border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                            onClicked: root.toggleMute()
                        }

                        AudioSlider {
                            Layout.fillWidth: true
                            value: Math.round((root.activePlayer?.volume || 0) * 100)
                            maxValue: 100
                            muted: root.activePlayer?.volume === 0
                            bg: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.12)
                            fill: root.cAccent
                            knob: root.cFg
                            onMoved: value => {
                                if (root.activePlayer?.volumeSupported)
                                    root.activePlayer.volume = Math.max(0, Math.min(1, value / 100))
                            }
                        }

                        Text {
                            text: Math.round((root.activePlayer?.volume || 0) * 100) + "%"
                            color: root.cFg
                            font { pixelSize: 10; family: root.cFont; bold: true }
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 156
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.68)
                    border.width: 1
                    border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.14)
                    opacity: root.rateSupported ? 1 : 0.44

                    RowLayout {
                        anchors { fill: parent; leftMargin: 9; rightMargin: 9 }
                        spacing: 6

                        MediaButton {
                            size: 28
                            iconSize: 13
                            icon: "-"
                            enabled: root.rateSupported
                            fg: root.cFg; bg: root.cCard; border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                            onClicked: root.setRate(-0.05)
                        }

                        Text {
                            text: (root.activePlayer?.rate ? root.activePlayer.rate.toFixed(2) : "1.00") + "x"
                            color: root.cFg
                            font { pixelSize: 11; family: root.cFont; bold: true }
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.rateSupported
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.resetRate()
                            }
                        }

                        MediaButton {
                            size: 28
                            iconSize: 13
                            icon: "+"
                            enabled: root.rateSupported
                            fg: root.cFg; bg: root.cCard; border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                            onClicked: root.setRate(0.05)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                spacing: 8

                ActionButton {
                    icon: "󰤢"
                    label: "Focus"
                    enabled: root.activePlayer?.canRaise ?? false
                    fg: root.cFg; dim: root.cDim; bg: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.68); border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                    onClicked: root.activePlayer?.raise()
                }

                ActionButton {
                    icon: "󰊓"
                    label: "Full"
                    active: root.activePlayer?.fullscreen ?? false
                    enabled: root.activePlayer?.canSetFullscreen ?? false
                    fg: root.cFg; dim: root.cDim; bg: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.68); border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                    onClicked: root.activePlayer.fullscreen = !root.activePlayer.fullscreen
                }

                ActionButton {
                    icon: "󰓛"
                    label: "Stop"
                    enabled: root.activePlayer?.canControl ?? false
                    fg: root.cFg; dim: root.cDim; bg: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.68); border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                    onClicked: root.activePlayer?.stop()
                }

                ActionButton {
                    icon: "󰅖"
                    label: "Quit"
                    danger: true
                    enabled: root.activePlayer?.canQuit ?? false
                    fg: root.cFg; dim: root.cDim; bg: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.68); border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                    onClicked: {
                        root.activePlayer?.quit()
                        root.dismissRequested()
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                spacing: 7
                clip: true

                Repeater {
                    model: root.players

                    Rectangle {
                        width: Math.max(88, playerLabel.implicitWidth + 22)
                        height: 28
                        radius: 9
                        color: modelData === root.activePlayer
                            ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.20)
                            : playerArea.containsMouse
                                ? Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.10)
                                : Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.54)
                        border.width: 1
                        border.color: modelData === root.activePlayer ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.60) : Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.12)

                        Text {
                            id: playerLabel
                            anchors {
                                left: parent.left
                                right: parent.right
                                leftMargin: 10
                                rightMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            text: modelData.identity || modelData.desktopEntry || "player"
                            color: modelData === root.activePlayer ? root.cAccent : root.cFg
                            font { pixelSize: 9; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        MouseArea {
                            id: playerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedPlayer = modelData
                        }
                    }
                }
            }
        }

    }
}
