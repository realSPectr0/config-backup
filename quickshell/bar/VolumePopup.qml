import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupPanel {
    id: root

    title: "Audio"
    subtitle: busyMessage.length > 0 ? busyMessage : summary
    panelWidth: 620

    property string helper: "/home/arch/.config/quickshell/bar/scripts/audio-mixer.py"
    property string summary: "Loading..."
    property string busyMessage: ""
    property string errorText: ""
    property string defaultSinkName: ""
    property string defaultSourceName: ""
    property string defaultSinkLabel: "Output"
    property string defaultSinkIcon: "󰋋"
    property int masterVolume: 0
    property int masterQueuedVolume: 0
    property bool masterMuted: false
    property bool micMuted: false

    function refresh() {
        queryProc.running = false
        queryProc.running = true
    }

    function runAction(args, label, refreshAfter) {
        root.busyMessage = label || ""
        root.errorText = ""
        actionProc.command = ["python3", root.helper].concat(args)
        actionProc.refreshAfter = refreshAfter
        actionProc.running = false
        actionProc.running = true
    }

    function setVolume(kind, target, value) {
        sliderProc.command = ["python3", root.helper, "set-volume", kind, target, String(value)]
        sliderProc.running = false
        sliderProc.running = true
    }

    function toggleMute(kind, target, label) {
        root.runAction(["toggle-mute", kind, target], label, true)
    }

    function setDefault(kind, name, label) {
        root.runAction(["set-default", kind, name], label, true)
    }

    function handleQuery(text) {
        try {
            const data = JSON.parse(text.trim())
            if (!data.ok) {
                root.errorText = data.message || "Could not read audio state."
                return
            }

            sinksModel.clear()
            sourcesModel.clear()
            streamsModel.clear()
            inputStreamsModel.clear()

            root.summary = data.summary || "Audio"
            root.defaultSinkName = data.defaultSinkName || ""
            root.defaultSourceName = data.defaultSourceName || ""
            root.defaultSinkLabel = data.defaultSink?.label || "Output"
            root.defaultSinkIcon = data.defaultSink?.icon || "󰋋"
            root.masterVolume = data.defaultSink?.volume || 0
            root.masterMuted = data.defaultSink?.muted === true
            root.micMuted = data.defaultSource?.muted === true

            const sinks = data.sinks || []
            for (let i = 0; i < sinks.length; i++)
                sinksModel.append(sinks[i])

            const sources = data.sources || []
            for (let i = 0; i < sources.length; i++)
                sourcesModel.append(sources[i])

            const streams = data.streams || []
            for (let i = 0; i < streams.length; i++)
                streamsModel.append(streams[i])

            const inputStreams = data.inputStreams || []
            for (let i = 0; i < inputStreams.length; i++)
                inputStreamsModel.append(inputStreams[i])
        } catch (e) {
            root.errorText = text.trim().length > 0 ? text.trim() : "Could not parse audio state."
        }
    }

    function handleAction(text) {
        try {
            const result = JSON.parse(text.trim())
            if (!result.ok)
                root.errorText = result.message || "Audio action failed."
        } catch (e) {
            if (text.trim().length > 0)
                root.errorText = text.trim()
        }
    }

    onShowingChanged: if (showing) refresh()

    Timer {
        interval: 2500
        repeat: true
        running: root.showing
        onTriggered: root.refresh()
    }

    ListModel { id: sinksModel }
    ListModel { id: sourcesModel }
    ListModel { id: streamsModel }
    ListModel { id: inputStreamsModel }

    Timer {
        id: masterCommitTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (root.defaultSinkName.length > 0)
                root.setVolume("sink", root.defaultSinkName, root.masterQueuedVolume)
        }
    }

    Process {
        id: queryProc
        command: ["python3", root.helper, "scan"]
        stdout: StdioCollector {
            onStreamFinished: root.handleQuery(text)
        }
    }

    Process {
        id: actionProc
        property bool refreshAfter: true
        stdout: StdioCollector {
            onStreamFinished: root.handleAction(text)
        }
        onExited: {
            root.busyMessage = ""
            if (refreshAfter)
                root.refresh()
        }
    }

    Process { id: sliderProc }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 132
        radius: 12
        color: root.cCard
        border.width: 1
        border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.34)
        clip: true

        Rectangle {
            anchors.fill: parent
            opacity: 0.20
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.65) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        RowLayout {
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 86
                Layout.preferredHeight: 86
                Layout.alignment: Qt.AlignVCenter
                radius: 24
                color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.50)

                Text {
                    anchors.centerIn: parent
                    text: root.masterMuted ? "󰟎" : root.defaultSinkIcon
                    color: root.masterMuted ? "#f87171" : root.cAccent
                    font { pixelSize: 38; family: root.cFont }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: root.defaultSinkLabel
                            color: root.cFg
                            font { pixelSize: 15; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.masterMuted ? "Muted output" : "Default output"
                            color: root.cDim
                            font { pixelSize: 10; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: root.masterVolume + "%"
                        color: root.masterVolume > 100 ? "#f87171" : root.cAccent
                        font { pixelSize: 20; family: root.cFont }
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                AudioSlider {
                    Layout.fillWidth: true
                    value: root.masterVolume
                    maxValue: 150
                    muted: root.masterMuted
                    bg: Qt.darker(root.cCard, 1.45)
                    fill: root.masterVolume > 100 ? "#f87171" : root.cAccent
                    knob: root.cFg
                    onMoved: value => {
                        root.masterVolume = value
                        root.masterQueuedVolume = value
                        root.masterMuted = false
                        masterCommitTimer.restart()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: 18
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4 + ((index * 7) % 15)
                            radius: 2
                            color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18 + (index % 4) * 0.08)
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ActionButton {
            icon: root.masterMuted ? "󰕾" : "󰝟"
            label: root.masterMuted ? "Unmute output" : "Mute output"
            sublabel: root.defaultSinkLabel
            active: root.masterMuted
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.defaultSinkName.length > 0 && root.toggleMute("sink", root.defaultSinkName, "Toggling output...")
        }

        ActionButton {
            icon: root.micMuted ? "󰍬" : "󰍭"
            label: root.micMuted ? "Unmute mic" : "Mute mic"
            sublabel: "Default input"
            active: root.micMuted
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.defaultSourceName.length > 0 && root.toggleMute("source", root.defaultSourceName, "Toggling microphone...")
        }

        ActionButton {
            icon: "󰑐"
            label: "Refresh"
            sublabel: sinksModel.count + " outputs"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.refresh()
        }
    }

    Text {
        text: "Outputs"
        color: root.cFg
        font { pixelSize: 12; family: root.cFont }
        Layout.fillWidth: true
    }

    ListView {
        id: outputList
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Math.max(1, sinksModel.count) * 86, 184)
        model: sinksModel
        spacing: 8
        clip: true
        interactive: contentHeight > height

        delegate: MixerRow {
            width: outputList.width
            icon: model.icon
            label: model.label
            sublabel: model.sublabel
            volume: model.volume
            muted: model.muted
            active: model.isDefault
            defaultable: true
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onVolumePreview: value => sinksModel.setProperty(index, "volume", value)
            onVolumeCommitted: value => root.setVolume("sink", model.id, value)
            onMuteClicked: root.toggleMute("sink", model.id, "Toggling " + model.label + "...")
            onDefaultClicked: !model.isDefault && root.setDefault("sink", model.name, "Switching to " + model.label + "...")
        }
    }

    Text {
        visible: streamsModel.count > 0
        text: "Apps"
        color: root.cFg
        font { pixelSize: 12; family: root.cFont }
        Layout.fillWidth: true
    }

    ListView {
        id: streamList
        visible: streamsModel.count > 0
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? Math.min(streamsModel.count * 86, 184) : 0
        model: streamsModel
        spacing: 8
        clip: true
        interactive: contentHeight > height

        delegate: MixerRow {
            width: streamList.width
            icon: model.icon
            label: model.label
            sublabel: model.sublabel
            volume: model.volume
            muted: model.muted
            active: false
            defaultable: false
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onVolumePreview: value => streamsModel.setProperty(index, "volume", value)
            onVolumeCommitted: value => root.setVolume("stream", model.id, value)
            onMuteClicked: root.toggleMute("stream", model.id, "Toggling " + model.label + "...")
        }
    }

    Text {
        text: "Inputs"
        color: root.cFg
        font { pixelSize: 12; family: root.cFont }
        Layout.fillWidth: true
    }

    ListView {
        id: inputList
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Math.max(1, sourcesModel.count) * 86, 184)
        model: sourcesModel
        spacing: 8
        clip: true
        interactive: contentHeight > height

        delegate: MixerRow {
            width: inputList.width
            icon: model.icon
            label: model.label
            sublabel: model.sublabel
            volume: model.volume
            muted: model.muted
            active: model.isDefault
            defaultable: true
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onVolumePreview: value => sourcesModel.setProperty(index, "volume", value)
            onVolumeCommitted: value => root.setVolume("source", model.id, value)
            onMuteClicked: root.toggleMute("source", model.id, "Toggling " + model.label + "...")
            onDefaultClicked: !model.isDefault && root.setDefault("source", model.name, "Switching to " + model.label + "...")
        }
    }

    Text {
        visible: inputStreamsModel.count > 0
        text: "Recording streams"
        color: root.cFg
        font { pixelSize: 12; family: root.cFont }
        Layout.fillWidth: true
    }

    ListView {
        id: inputStreamList
        visible: inputStreamsModel.count > 0
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? Math.min(inputStreamsModel.count * 86, 160) : 0
        model: inputStreamsModel
        spacing: 8
        clip: true
        interactive: contentHeight > height

        delegate: MixerRow {
            width: inputStreamList.width
            icon: model.icon
            label: model.label
            sublabel: model.sublabel
            volume: model.volume
            muted: model.muted
            active: false
            defaultable: false
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onVolumePreview: value => inputStreamsModel.setProperty(index, "volume", value)
            onVolumeCommitted: value => root.setVolume("input-stream", model.id, value)
            onMuteClicked: root.toggleMute("input-stream", model.id, "Toggling " + model.label + "...")
        }
    }

    Rectangle {
        visible: root.errorText.length > 0
        Layout.fillWidth: true
        implicitHeight: visible ? errorItem.implicitHeight + 18 : 0
        radius: 7
        color: Qt.rgba(1, 0.35, 0.35, 0.10)
        border.width: 1
        border.color: Qt.rgba(1, 0.35, 0.35, 0.36)

        Text {
            id: errorItem
            anchors {
                fill: parent
                margins: 9
            }
            text: root.errorText
            color: "#fca5a5"
            font { pixelSize: 10; family: root.cFont }
            wrapMode: Text.Wrap
        }
    }
}
