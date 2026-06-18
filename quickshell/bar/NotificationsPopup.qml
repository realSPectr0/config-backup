import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

PanelWindow {
    id: root

    property bool showing: false
    property real anchorCenterX: screenWidth - panelWidth / 2 - edgeGap
    property int panelWidth: 820
    property int panelHeight: 620
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
    property color warmAccent: "#ffd179"
    property bool dnd: false
    property int unreadCount: 0
    property int activeTab: 0
    property var liveNotifications: []
    property var history: []
    property var clipboardItems: []
    property var screenshots: []
    readonly property var notificationRows: buildNotificationRows()

    readonly property int barTopGap: 5
    readonly property int barHeight: 44
    readonly property int popupGap: 4
    readonly property int edgeGap: 8
    readonly property real screenWidth: root.screen?.width ?? 1920
    readonly property real panelLeft: Math.round(Math.max(edgeGap, Math.min(screenWidth - panelWidth - edgeGap, anchorCenterX - panelWidth / 2)))

    signal dismissRequested()
    signal notificationReceived(var item)

    function stripMarkup(value) {
        return (value || "").toString()
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<[^>]+>/g, "")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .trim()
    }

    function clampText(value, fallback) {
        const text = stripMarkup(value)
        return text.length > 0 ? text : fallback
    }

    function basename(path) {
        const text = (path || "").toString()
        const idx = text.lastIndexOf("/")
        return idx >= 0 ? text.substring(idx + 1) : text
    }

    function safeImageSource(source) {
        const text = (source || "").toString()
        return text.startsWith("image://qsimage/") ? "" : text
    }

    function shellQuote(value) {
        return "'" + (value || "").toString().replace(/'/g, "'\\''") + "'"
    }

    function timeAgo(timestamp) {
        const diff = Math.max(0, Math.floor((Date.now() - timestamp) / 1000))
        if (diff < 60)
            return "now"
        if (diff < 3600)
            return Math.floor(diff / 60) + "m"
        if (diff < 86400)
            return Math.floor(diff / 3600) + "h"
        return Math.floor(diff / 86400) + "d"
    }

    function notificationItem(notif) {
        const ts = Date.now()
        return {
            live: true,
            id: "live-" + notif.id,
            sourceId: notif.id.toString(),
            notification: notif,
            appName: clampText(notif.appName, "App"),
            appIcon: notif.appIcon || "",
            summary: clampText(notif.summary, "Notification"),
            body: stripMarkup(notif.body),
            image: notif.image || "",
            urgency: notif.urgency,
            actions: Array.from(notif.actions || []),
            timestamp: ts
        }
    }

    function historyItemFrom(item) {
        return {
            live: false,
            id: "hist-" + item.sourceId + "-" + item.timestamp,
            sourceId: item.sourceId,
            appName: item.appName,
            appIcon: item.appIcon,
            summary: item.summary,
            body: item.body,
            image: item.image,
            urgency: item.urgency,
            timestamp: item.timestamp
        }
    }

    function buildNotificationRows() {
        const rows = []
        const seen = {}
        for (const item of liveNotifications) {
            if (!item)
                continue
            rows.push(item)
            seen[item.sourceId] = true
        }
        for (const item of history) {
            if (!item || seen[item.sourceId])
                continue
            rows.push(historyItemFrom(item))
            if (rows.length >= 80)
                break
        }
        return rows
    }

    function saveHistory() {
        historyAdapter.notifications = history
        historyFile.writeAdapter()
    }

    function loadHistory() {
        const loaded = historyAdapter.notifications || []
        history = loaded.slice(0, 90)
    }

    function addToHistory(item) {
        // Strip ephemeral quickshell image:// handles — they're invalid after restart
        const persistedImage = (item.image && !item.image.startsWith("image://")) ? item.image : ""
        const plain = {
            sourceId: item.sourceId,
            appName: item.appName,
            appIcon: item.appIcon,
            summary: item.summary,
            body: item.body,
            image: persistedImage,
            urgency: item.urgency,
            timestamp: item.timestamp
        }
        const next = [plain]
        for (const old of history) {
            if (old.sourceId !== plain.sourceId)
                next.push(old)
            if (next.length >= 90)
                break
        }
        history = next
        saveHistory()
    }

    function removeNotification(item) {
        if (!item)
            return
        if (item.live && item.notification) {
            try {
                item.notification.dismiss()
            } catch(e) {}
        }
        liveNotifications = liveNotifications.filter(n => n && n.id !== item.id)
        history = history.filter(n => n && !(n.sourceId === item.sourceId && n.timestamp === item.timestamp))
        saveHistory()
    }

    function clearNotifications() {
        for (const item of liveNotifications) {
            try {
                item.notification?.dismiss()
            } catch(e) {}
        }
        liveNotifications = []
        history = []
        unreadCount = 0
        saveHistory()
    }

    function parseClipboard(text) {
        const rows = []
        const lines = (text || "").split("\n")
        for (const line of lines) {
            const trimmed = line.trim()
            if (trimmed.length === 0)
                continue
            const tab = trimmed.indexOf("\t")
            const id = tab >= 0 ? trimmed.substring(0, tab) : trimmed.split(/\s+/)[0]
            const preview = tab >= 0 ? trimmed.substring(tab + 1) : trimmed.substring(id.length).trim()
            const isImage = preview.indexOf("[[ binary data") === 0
            rows.push({
                id: id,
                text: preview.length > 0 ? preview : "Clipboard item",
                image: isImage
            })
        }
        clipboardItems = rows
    }

    function actionLabel(action) {
        const label = (action?.text ?? action?.identifier ?? action?.id ?? "").toString().trim()
        return label.length > 0 ? label : "Action"
    }

    function parseScreenshots(text) {
        screenshots = (text || "").split("\n").map(s => s.trim()).filter(s => s.length > 0)
    }

    function refreshClipboard() {
        clipboardProc.running = false
        clipboardProc.running = true
    }

    function refreshScreenshots() {
        screenshotsProc.running = false
        screenshotsProc.running = true
    }

    function showTab(index) {
        const parsed = parseInt(index)
        activeTab = Math.max(0, Math.min(2, isNaN(parsed) ? 0 : parsed))
        if (activeTab === 1)
            refreshClipboard()
        else if (activeTab === 2)
            refreshScreenshots()
    }

    function copyClipboardItem(item) {
        if (!item)
            return
        copyProc.command = ["bash", "-c", "cliphist decode " + shellQuote(item.id) + " | wl-copy"]
        copyProc.running = false
        copyProc.running = true
    }

    function copyScreenshot(path) {
        if (!path)
            return
        copyProc.command = ["bash", "-c", "wl-copy --type image/png < " + shellQuote(path)]
        copyProc.running = false
        copyProc.running = true
    }

    function clearCurrentTab() {
        if (activeTab === 0) {
            clearNotifications()
        } else if (activeTab === 1) {
            clearClipProc.running = false
            clearClipProc.running = true
        } else {
            refreshScreenshots()
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
    WlrLayershell.namespace: "qs-bar-notifications-popup"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onShowingChanged: {
        if (showing) {
            unreadCount = 0
            refreshClipboard()
            refreshScreenshots()
        }
    }

    onActiveTabChanged: {
        if (!showing)
            return
        if (activeTab === 1)
            refreshClipboard()
        else if (activeTab === 2)
            refreshScreenshots()
    }

    Component.onCompleted: mkdirProc.running = true

    FileView {
        id: historyFile
        path: "/home/arch/.cache/quickshell/bar-notification-history.json"
        printErrors: false
        onLoaded: root.loadHistory()
        onLoadFailed: {
            root.history = []
            root.saveHistory()
        }

        JsonAdapter {
            id: historyAdapter
            property var notifications: []
        }
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        inlineReplySupported: false
        persistenceSupported: false

        onNotification: notif => {
            const item = root.notificationItem(notif)
            Qt.callLater(() => { try { notif.tracked = true } catch(e) {} })
            const nextLive = [item]
            for (const old of root.liveNotifications) {
                if (old && old.sourceId !== item.sourceId)
                    nextLive.push(old)
                if (nextLive.length >= 48)
                    break
            }
            root.liveNotifications = nextLive
            root.addToHistory(item)
            if (!root.showing)
                root.unreadCount += 1
            if (!root.dnd)
                root.notificationReceived(item)
        }
    }

    Process { id: mkdirProc; command: ["mkdir", "-p", "/home/arch/.cache/quickshell"] }
    Process {
        id: clipboardProc
        command: ["bash", "-c", "cliphist list | head -40"]
        stdout: StdioCollector { onStreamFinished: root.parseClipboard(text) }
    }
    Process {
        id: screenshotsProc
        command: ["bash", "-c", "find /home/arch/Pictures/Screenshots -maxdepth 2 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) -printf '%T@|%p\\n' 2>/dev/null | sort -rn | head -18 | cut -d'|' -f2-"]
        stdout: StdioCollector { onStreamFinished: root.parseScreenshots(text) }
    }
    Process { id: copyProc }
    Process {
        id: clearClipProc
        command: ["cliphist", "wipe"]
        onExited: root.refreshClipboard()
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.94)
        border.width: 2
        border.color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.24)
        clip: true
        antialiasing: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 5
            shadowBlur: 0.50
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowOpacity: 0.34
        }

        Rectangle {
            anchors {
                fill: parent
                margins: 1
            }
            radius: panel.radius - 1
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.12) }
                GradientStop { position: 0.42; color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.96) }
                GradientStop { position: 1.0; color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 1.0) }
            }
        }

        Rectangle {
            width: 470
            height: 470
            radius: 235
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: -90
            }
            color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.045)
        }

        Rectangle {
            width: 300
            height: 300
            radius: 150
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: -12
            }
            color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.050)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                    text: "Notification Center"
                    color: root.cFg
                        font { pixelSize: 19; family: root.cFont; bold: true }
                    }

                    Text {
                        text: root.dnd ? "Do not disturb" : root.notificationRows.length + " saved / " + root.clipboardItems.length + " clips / " + root.screenshots.length + " shots"
                        color: root.dnd ? root.cRed : root.cDim
                        font { pixelSize: 10; family: root.cFont }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 76
                    Layout.preferredHeight: 30
                    radius: 9
                    color: root.dnd ? Qt.lighter(root.cCard, 1.16) : Qt.lighter(root.cCard, 1.04)
                    border.width: 1
                    border.color: root.dnd ? Qt.rgba(root.cRed.r, root.cRed.g, root.cRed.b, 0.64) : Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.24)

                    Text {
                        anchors.centerIn: parent
                        text: "DND"
                        color: root.dnd ? root.cRed : root.cFg
                        font { pixelSize: 10; family: root.cFont; bold: true }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dnd = !root.dnd
                    }
                }

                ActionButton {
                    Layout.preferredWidth: 92
                    Layout.fillWidth: false
                    icon: root.activeTab === 2 ? "󰑓" : "󰆴"
                    label: root.activeTab === 2 ? "Refresh" : "Clear"
                    fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                    onClicked: root.clearCurrentTab()
                }

                MediaButton {
                    size: 30
                    iconSize: 12
                    icon: "x"
                    danger: true
                    fg: root.cFg; bg: root.cCard; border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                    onClicked: root.dismissRequested()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { index: 0, label: "Notifications", count: root.notificationRows.length },
                        { index: 1, label: "Clipboard", count: root.clipboardItems.length },
                        { index: 2, label: "Screenshots", count: root.screenshots.length }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 9
                        color: root.activeTab === modelData.index ? Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.18) : Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.72)
                        border.width: 1
                        border.color: root.activeTab === modelData.index ? Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.54) : Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.10)

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 7

                            Text {
                                text: modelData.label
                                color: root.activeTab === modelData.index ? root.warmAccent : root.cFg
                                font { pixelSize: 10; family: root.cFont; bold: root.activeTab === modelData.index }
                            }

                            Rectangle {
                                width: Math.max(20, countText.implicitWidth + 10)
                                height: 18
                                radius: 9
                                color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, root.activeTab === modelData.index ? 0.20 : 0.10)

                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: modelData.count
                                    color: root.cFg
                                    font { pixelSize: 9; family: root.cFont; bold: true }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTab = modelData.index
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 480
                    sourceComponent: root.activeTab === 0 ? notificationsComponent : root.activeTab === 1 ? clipboardComponent : screenshotsComponent
                }

                ColumnLayout {
                    Layout.preferredWidth: 250
                    Layout.minimumWidth: 250
                    Layout.maximumWidth: 250
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 232
                        radius: 18
                        color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.66)
                        border.width: 1
                        border.color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.24)

                        Rectangle {
                            width: 152
                            height: 152
                            radius: 76
                            anchors.centerIn: parent
                            color: "transparent"
                            border.width: 10
                            border.color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.72)
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: root.notificationRows.length
                                color: root.cFg
                                horizontalAlignment: Text.AlignHCenter
                                font { pixelSize: 42; family: root.cFont; bold: true }
                            }

                            Text {
                                text: root.dnd ? "DND ENABLED" : "SAVED"
                                color: root.dnd ? root.cRed : root.cDim
                                horizontalAlignment: Text.AlignHCenter
                                font { pixelSize: 10; family: root.cFont; bold: true }
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 10
                        columnSpacing: 10

                        Repeater {
                            model: [
                                { icon: root.dnd ? "󰂛" : "󰂚", label: "DND", action: 0 },
                                { icon: "󰑓", label: "Refresh", action: 1 },
                                { icon: "󰆴", label: "Clear", action: 2 },
                                { icon: "󰅖", label: "Close", action: 3 }
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                radius: 12
                                color: actionArea.containsMouse ? Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.14) : Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.66)
                                border.width: 1
                                border.color: actionArea.containsMouse ? Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.46) : Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.10)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: modelData.icon
                                        color: modelData.action === 0 && root.dnd ? root.cRed : root.warmAccent
                                        horizontalAlignment: Text.AlignHCenter
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font { pixelSize: 19; family: root.cFont }
                                    }

                                    Text {
                                        text: modelData.label
                                        color: root.cFg
                                        horizontalAlignment: Text.AlignHCenter
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font { pixelSize: 10; family: root.cFont; bold: true }
                                    }
                                }

                                MouseArea {
                                    id: actionArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.action === 0)
                                            root.dnd = !root.dnd
                                        else if (modelData.action === 1) {
                                            root.refreshClipboard()
                                            root.refreshScreenshots()
                                        } else if (modelData.action === 2)
                                            root.clearCurrentTab()
                                        else
                                            root.dismissRequested()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: Qt.rgba(root.cCard.r, root.cCard.g, root.cCard.b, 0.56)
                        border.width: 1
                        border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.10)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            Text {
                                text: "Quick totals"
                                color: root.cFg
                                font { pixelSize: 12; family: root.cFont; bold: true }
                            }

                            Text {
                                text: "Notifications  " + root.notificationRows.length + "\nClipboard      " + root.clipboardItems.length + "\nScreenshots    " + root.screenshots.length
                                color: root.cDim
                                lineHeight: 1.35
                                font { pixelSize: 10; family: root.cFont }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: notificationsComponent

        Item {
            anchors.fill: parent
            clip: true

            Text {
                anchors.centerIn: parent
                visible: root.notificationRows.length === 0
                text: "No notifications"
                color: root.cDim
                font { pixelSize: 12; family: root.cFont }
            }

            Flickable {
                anchors.fill: parent
                visible: root.notificationRows.length > 0
                contentWidth: width
                contentHeight: notificationColumn.implicitHeight
                clip: true

                Column {
                    id: notificationColumn
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: root.notificationRows

                        Rectangle {
                            width: notificationColumn.width
                            height: Math.max(82, notificationContent.implicitHeight + 20)
                            radius: 10
                            color: Qt.lighter(root.cCard, notificationArea.containsMouse ? 1.12 : 1.04)
                            border.width: modelData.urgency === NotificationUrgency.Critical ? 2 : 1
                            border.color: modelData.urgency === NotificationUrgency.Critical ? Qt.rgba(root.cRed.r, root.cRed.g, root.cRed.b, 0.72) : root.cBord

                            RowLayout {
                                id: notificationContent
                                anchors { fill: parent; margins: 10 }
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 42
                                    radius: 10
                                    color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.12)
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
                                        font { pixelSize: 16; family: root.cFont; bold: true }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: modelData.appName
                                            color: root.cAccent
                                            font { pixelSize: 9; family: root.cFont; bold: true }
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            Layout.maximumWidth: 160
                                        }

                                        Text {
                                            text: root.timeAgo(modelData.timestamp)
                                            color: root.cDim
                                            font { pixelSize: 9; family: root.cFont }
                                        }

                                        Item { Layout.fillWidth: true }

                                        MediaButton {
                                            size: 24
                                            iconSize: 10
                                            icon: "x"
                                            danger: true
                                            fg: root.cFg; bg: root.cCard; border_: root.cBord; accent: root.cAccent; red: root.cRed; font_: root.cFont
                                            onClicked: root.removeNotification(modelData)
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
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        Layout.fillWidth: true
                                    }

                                    Flow {
                                        visible: modelData.live && modelData.actions && modelData.actions.length > 0
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: modelData.actions || []

                                            Rectangle {
                                                width: Math.max(72, actionText.implicitWidth + 18)
                                                height: 26
                                                radius: 8
                                                color: actionArea.containsMouse ? Qt.lighter(root.cCard, 1.20) : Qt.lighter(root.cCard, 1.10)
                                                border.width: 1
                                                border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, actionArea.containsMouse ? 0.58 : 0.32)

                                                Text {
                                                    id: actionText
                                                    anchors.centerIn: parent
                                                    text: root.actionLabel(modelData)
                                                    color: root.cFg
                                                    font { pixelSize: 9; family: root.cFont; bold: true }
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                }

                                                MouseArea {
                                                    id: actionArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: modelData?.invoke()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: notificationArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: clipboardComponent

        Item {
            anchors.fill: parent
            clip: true

            Text {
                anchors.centerIn: parent
                visible: root.clipboardItems.length === 0
                text: "No clipboard history"
                color: root.cDim
                font { pixelSize: 12; family: root.cFont }
            }

            Flickable {
                anchors.fill: parent
                visible: root.clipboardItems.length > 0
                contentWidth: width
                contentHeight: clipColumn.implicitHeight
                clip: true

                Column {
                    id: clipColumn
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: root.clipboardItems

                        Rectangle {
                            width: clipColumn.width
                            height: 58
                            radius: 10
                            color: clipArea.containsMouse ? Qt.lighter(root.cCard, 1.12) : Qt.lighter(root.cCard, 1.04)
                            border.width: 1
                            border.color: clipArea.containsMouse ? Qt.rgba(root.cBlue.r, root.cBlue.g, root.cBlue.b, 0.52) : root.cBord

                            RowLayout {
                                anchors { fill: parent; margins: 10 }
                                spacing: 10

                                Text {
                                    text: modelData.image ? "󰋩" : "󰅍"
                                    color: modelData.image ? root.cGreen : root.cBlue
                                    font { pixelSize: 16; family: root.cFont }
                                    Layout.preferredWidth: 24
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: modelData.text
                                        color: root.cFg
                                        font { pixelSize: 11; family: root.cFont }
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "#" + modelData.id
                                        color: root.cDim
                                        font { pixelSize: 9; family: root.cFont }
                                    }
                                }

                                MediaButton {
                                    size: 30
                                    iconSize: 13
                                    icon: "󰆏"
                                    fg: root.cFg; bg: root.cCard; border_: root.cBord; accent: root.cBlue; red: root.cRed; font_: root.cFont
                                    onClicked: root.copyClipboardItem(modelData)
                                }
                            }

                            MouseArea {
                                id: clipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyClipboardItem(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: screenshotsComponent

        Item {
            anchors.fill: parent
            clip: true

            Text {
                anchors.centerIn: parent
                visible: root.screenshots.length === 0
                text: "No screenshots"
                color: root.cDim
                font { pixelSize: 12; family: root.cFont }
            }

            Flickable {
                anchors.fill: parent
                visible: root.screenshots.length > 0
                contentWidth: width
                contentHeight: screenshotFlow.implicitHeight
                clip: true

                Flow {
                    id: screenshotFlow
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: root.screenshots

                        Rectangle {
                            width: Math.floor((screenshotFlow.width - 20) / 3)
                            height: 132
                            radius: 10
                            color: shotArea.containsMouse ? Qt.lighter(root.cCard, 1.12) : Qt.lighter(root.cCard, 1.04)
                            border.width: 1
                            border.color: shotArea.containsMouse ? Qt.rgba(root.cGreen.r, root.cGreen.g, root.cGreen.b, 0.52) : root.cBord
                            clip: true

                            Image {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    bottom: shotBar.top
                                }
                                source: "file://" + modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }

                            Rectangle {
                                id: shotBar
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                }
                                height: 28
                                color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.88)

                                Text {
                                    id: shotName
                                    anchors {
                                        left: parent.left
                                        leftMargin: 8
                                        right: parent.right
                                        rightMargin: 8
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: root.basename(modelData)
                                    color: root.cFg
                                    font { pixelSize: 9; family: root.cFont }
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            MouseArea {
                                id: shotArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyScreenshot(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
