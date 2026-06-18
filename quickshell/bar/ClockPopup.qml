import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupPanel {
    id: root

    title: "Time"
    subtitle: dateLine
    panelWidth: 860

    property string dateLine: ""
    property string timeLine: ""
    property string secondsLine: "00"
    property string meridiem: "AM"
    property string timezone: ""
    property string weekLine: ""
    property string dayOfYear: ""
    property string uptimeLine: ""
    property real dayProgress: 0
    property real yearProgress: 0
    property color warmAccent: "#ffb3a4"
    property int shownYear: new Date().getFullYear()
    property int shownMonth: new Date().getMonth()
    property string todayKey: ""
    property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    property var weekdayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    ListModel { id: calendarModel }

    function leapYear(year) {
        return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0
    }

    function makeDayKey(year, month, day) {
        return year + "-" + month + "-" + day
    }

    function monthTitle() {
        return root.monthNames[root.shownMonth] + " " + root.shownYear
    }

    function rebuildCalendar() {
        const today = new Date()
        root.todayKey = root.makeDayKey(today.getFullYear(), today.getMonth(), today.getDate())

        calendarModel.clear()

        const first = new Date(root.shownYear, root.shownMonth, 1)
        const mondayOffset = (first.getDay() + 6) % 7
        const start = new Date(root.shownYear, root.shownMonth, 1 - mondayOffset)

        for (let i = 0; i < 42; i++) {
            const dayDate = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
            const dayKey = root.makeDayKey(dayDate.getFullYear(), dayDate.getMonth(), dayDate.getDate())
            calendarModel.append({
                "day": dayDate.getDate(),
                "inMonth": dayDate.getMonth() === root.shownMonth,
                "isToday": dayKey === root.todayKey,
                "isWeekend": dayDate.getDay() === 0 || dayDate.getDay() === 6
            })
        }
    }

    function setShownMonth(year, month) {
        const next = new Date(year, month, 1)
        root.shownYear = next.getFullYear()
        root.shownMonth = next.getMonth()
        root.rebuildCalendar()
    }

    function showPreviousMonth() {
        root.setShownMonth(root.shownYear, root.shownMonth - 1)
    }

    function showNextMonth() {
        root.setShownMonth(root.shownYear, root.shownMonth + 1)
    }

    function showCurrentMonth() {
        const today = new Date()
        root.setShownMonth(today.getFullYear(), today.getMonth())
    }

    function refresh() {
        dateProc.running = false
        dateProc.running = true
        uptimeProc.running = false
        uptimeProc.running = true
    }

    onShowingChanged: if (showing) {
        root.showCurrentMonth()
        refresh()
    }

    Component.onCompleted: root.showCurrentMonth()

    Timer {
        interval: 1000
        repeat: true
        running: root.showing
        onTriggered: {
            dateProc.running = false
            dateProc.running = true
        }
    }

    Process {
        id: dateProc
        command: ["bash", "-lc", "TZ=America/Los_Angeles date '+%A|%B %-d, %Y|%-I:%M|%S|%p|%Z|%V|%j|%H|%M|%Y'"]
        stdout: SplitParser {
            onRead: d => {
                const parts = d.trim().split("|")
                root.dateLine = parts[0] && parts[1] ? parts[0] + ", " + parts[1] : ""
                root.timeLine = parts[2] || ""
                root.secondsLine = parts[3] || "00"
                root.meridiem = parts[4] || ""
                root.timezone = parts[5] || ""
                root.weekLine = parts[6] ? "Week " + parts[6] : ""
                root.dayOfYear = parts[7] ? "Day " + parts[7] : ""
                const h = parseInt(parts[8]) || 0
                const m = parseInt(parts[9]) || 0
                const y = parseInt(parts[10]) || new Date().getFullYear()
                const doy = parseInt(parts[7]) || 1
                root.dayProgress = (h * 60 + m) / 1440
                root.yearProgress = doy / (root.leapYear(y) ? 366 : 365)

                const today = new Date()
                const key = root.makeDayKey(today.getFullYear(), today.getMonth(), today.getDate())
                if (root.todayKey !== key)
                    root.rebuildCalendar()
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["bash", "-lc", "awk '{s=int($1); d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60); if (d>0) printf \"%dd %02dh %02dm\", d, h, m; else printf \"%02dh %02dm\", h, m}' /proc/uptime"]
        stdout: SplitParser { onRead: d => root.uptimeLine = d.trim() }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 238
        radius: 18
        color: Qt.rgba(16 / 255, 10 / 255, 8 / 255, 0.82)
        border.width: 1
        border.color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.24)
        clip: true

        Rectangle {
            width: 520
            height: 260
            radius: 130
            anchors.centerIn: parent
            color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.040)
        }

        Rectangle {
            width: 340
            height: 170
            radius: 85
            anchors.centerIn: parent
            color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.040)
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.15) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        RowLayout {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 126
                Layout.preferredHeight: 126
                Layout.alignment: Qt.AlignVCenter
                radius: 63
                color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.15)
                border.width: 1
                border.color: Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.48)

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        text: root.secondsLine
                        color: root.warmAccent
                        font { pixelSize: 40; family: root.cFont; bold: true }
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "seconds"
                        color: root.cDim
                        font { pixelSize: 9; family: root.cFont }
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: root.timeLine
                        color: root.cFg
                        font { pixelSize: 62; family: root.cFont; bold: true }
                        Layout.alignment: Qt.AlignBottom
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignBottom
                        spacing: 0

                        Text {
                            text: root.meridiem
                            color: root.warmAccent
                            font { pixelSize: 15; family: root.cFont }
                        }

                        Text {
                            text: root.timezone
                            color: root.cDim
                            font { pixelSize: 10; family: root.cFont }
                        }
                    }
                }

                Text {
                    text: root.dateLine
                    color: root.cDim
                    font { pixelSize: 12; family: root.cFont }
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: 24
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            radius: 4
                            color: index / 24 <= root.dayProgress
                                ? Qt.rgba(root.warmAccent.r, root.warmAccent.g, root.warmAccent.b, 0.62)
                                : Qt.rgba(root.cBord.r, root.cBord.g, root.cBord.b, 0.55)
                        }
                    }
                }

                Text {
                    text: "Day progress " + Math.round(root.dayProgress * 100) + "%"
                    color: root.cDim
                    font { pixelSize: 10; family: root.cFont }
                    Layout.fillWidth: true
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 4
        rowSpacing: 8
        columnSpacing: 8

        Repeater {
            model: [
                { icon: "󰃭", label: "Date", value: root.dateLine },
                { icon: "󰅐", label: "Uptime", value: root.uptimeLine },
                { icon: "󰨳", label: "Week", value: root.weekLine },
                { icon: "󰃮", label: "Year", value: Math.round(root.yearProgress * 100) + "%" }
            ]

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 9
                color: root.cCard
                border.width: 1
                border.color: root.cBord

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 9
                    }
                    spacing: 2

                    Text {
                        text: modelData.icon + "  " + modelData.label
                        color: root.cDim
                        font { pixelSize: 9; family: root.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.fillWidth: true
                    }

                    Text {
                        text: modelData.value
                        color: root.cFg
                        font { pixelSize: 10; family: root.cFont }
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 330
        radius: 12
        color: root.cCard
        border.width: 1
        border.color: root.cBord

        ColumnLayout {
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.monthTitle()
                    color: root.cFg
                    font { pixelSize: 13; family: root.cFont }
                    Layout.fillWidth: true
                }

                Rectangle {
                    id: prevMonthButton
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 28
                    radius: 7
                    color: prevMonthArea.pressed
                        ? Qt.lighter(root.cBg, 1.32)
                        : prevMonthArea.containsMouse
                            ? Qt.lighter(root.cBg, 1.18)
                            : root.cBg
                    border.width: 1
                    border.color: prevMonthArea.containsMouse ? Qt.lighter(root.cBord, 1.6) : root.cBord

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: root.cFg
                        font { pixelSize: 18; family: root.cFont }
                    }

                    MouseArea {
                        id: prevMonthArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showPreviousMonth()
                    }
                }

                Rectangle {
                    id: todayButton
                    Layout.preferredWidth: 68
                    Layout.preferredHeight: 28
                    radius: 14
                    readonly property bool currentMonth: {
                        const now = new Date()
                        return root.shownYear === now.getFullYear() && root.shownMonth === now.getMonth()
                    }
                    color: currentMonth
                        ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18)
                        : todayArea.pressed
                            ? Qt.lighter(root.cBg, 1.32)
                            : todayArea.containsMouse
                                ? Qt.lighter(root.cBg, 1.18)
                                : root.cBg
                    border.width: 1
                    border.color: currentMonth
                        ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.55)
                        : todayArea.containsMouse ? Qt.lighter(root.cBord, 1.6) : root.cBord

                    Text {
                        anchors.centerIn: parent
                        text: "Today"
                        color: todayButton.currentMonth ? root.cAccent : root.cFg
                        font { pixelSize: 11; family: root.cFont }
                    }

                    MouseArea {
                        id: todayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showCurrentMonth()
                    }
                }

                Rectangle {
                    id: nextMonthButton
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 28
                    radius: 7
                    color: nextMonthArea.pressed
                        ? Qt.lighter(root.cBg, 1.32)
                        : nextMonthArea.containsMouse
                            ? Qt.lighter(root.cBg, 1.18)
                            : root.cBg
                    border.width: 1
                    border.color: nextMonthArea.containsMouse ? Qt.lighter(root.cBord, 1.6) : root.cBord

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: root.cFg
                        font { pixelSize: 18; family: root.cFont }
                    }

                    MouseArea {
                        id: nextMonthArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showNextMonth()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.cBord
                opacity: 0.7
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 0
                columnSpacing: 6

                Repeater {
                    model: root.weekdayNames

                    Text {
                        text: modelData
                        color: index >= 5 ? root.cAccent : root.cDim
                        font { pixelSize: 10; family: root.cFont }
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: calendarModel

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34

                        Rectangle {
                            anchors.centerIn: parent
                            width: isToday ? 34 : parent.width
                            height: 30
                            radius: isToday ? 15 : 8
                            color: isToday
                                ? root.cAccent
                                : inMonth
                                    ? Qt.rgba(root.cBord.r, root.cBord.g, root.cBord.b, isWeekend ? 0.30 : 0.18)
                                    : "transparent"
                            border.width: isToday || !inMonth ? 0 : 1
                            border.color: Qt.rgba(root.cBord.r, root.cBord.g, root.cBord.b, 0.72)

                            Text {
                                anchors.centerIn: parent
                                text: day
                                color: isToday ? root.cBg : inMonth ? root.cFg : root.cDim
                                opacity: isToday || inMonth ? 1 : 0.48
                                font {
                                    pixelSize: isToday ? 13 : 11
                                    family: root.cFont
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
