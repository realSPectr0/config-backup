// Calendar + weather popup for the PHNexus waybar clock, modelled on the
// Caffyne calendar/weather applets. Launched (and closed) by
// ~/.local/bin/calweather; the instance quits when the popup is dismissed.
//
// Uses a layer-shell PanelWindow rather than a PopupWindow: xdg_popup is the
// code path that segfaults when quickshell is out of step with system Qt.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root

    // ---- matugen palette (regenerated on every wallpaper change) ----
    property color bg: "#1b110f"
    property color fg: "#f3deda"
    property color accent: "#e56c58"
    property color muted: "#dec0bb"

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.bg = d.special.background;
                root.fg = d.special.foreground;
                root.accent = d.colors.color1;
                root.muted = d.colors.color8;
            } catch (e) {}
        }
    }

    readonly property string iconFont: "FiraCode Nerd Font"

    // ---- weather (Open-Meteo, location from IP like Caffyne) ----
    property string location: ""
    property var current: null
    property var hourly: []
    property var daily: []
    property string weatherError: ""

    readonly property string cacheFile: Quickshell.env("HOME") + "/.cache/calweather.json"

    function weatherIcon(code, isDay) {
        if (code === 0) return isDay ? "\u{F0599}" : "\u{F0594}";
        if (code <= 2) return isDay ? "\u{F0595}" : "\u{F0F31}";
        if (code === 3) return "\u{F0590}";
        if (code === 45 || code === 48) return "\u{F0591}";
        if (code >= 51 && code <= 67) return code >= 63 ? "\u{F0596}" : "\u{F0597}";
        if (code >= 71 && code <= 77) return "\u{F0598}";
        if (code >= 80 && code <= 82) return "\u{F0596}";
        if (code === 85 || code === 86) return "\u{F067F}";
        if (code >= 95) return "\u{F0593}";
        return "\u{F0590}";
    }

    function weatherText(code) {
        const t = {0: "Clear", 1: "Mostly clear", 2: "Partly cloudy", 3: "Overcast",
                   45: "Fog", 48: "Fog", 51: "Drizzle", 53: "Drizzle", 55: "Drizzle",
                   61: "Light rain", 63: "Rain", 65: "Heavy rain", 71: "Light snow",
                   73: "Snow", 75: "Heavy snow", 80: "Showers", 81: "Showers",
                   82: "Heavy showers", 95: "Thunderstorm", 96: "Thunderstorm", 99: "Thunderstorm"};
        return t[code] || "Cloudy";
    }

    function hourLabel(iso) {
        const h = parseInt(iso.split("T")[1].slice(0, 2));
        if (h === 0) return "12AM";
        if (h < 12) return h + "AM";
        if (h === 12) return "12PM";
        return (h - 12) + "PM";
    }

    function applyWeather(w) {
        const now = new Date();
        const nowKey = Qt.formatDateTime(now, "yyyy-MM-ddThh");
        let start = w.hourly.time.findIndex(t => t.slice(0, 13) >= nowKey);
        if (start < 0) start = 0;
        const hrs = [];
        for (let i = start; i < Math.min(start + 6, w.hourly.time.length); i++)
            hrs.push({ time: w.hourly.time[i], temp: w.hourly.temperature_2m[i],
                       code: w.hourly.weather_code[i], day: w.hourly.is_day[i] === 1 });
        const days = [];
        for (let i = 0; i < w.daily.time.length; i++)
            days.push({ date: w.daily.time[i], max: w.daily.temperature_2m_max[i],
                        min: w.daily.temperature_2m_min[i], code: w.daily.weather_code[i] });
        root.current = w.current;
        root.hourly = hrs;
        root.daily = days;
        root.location = w.location || "";
        root.weatherError = "";
    }

    function getJson(url, cb) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try { cb(JSON.parse(xhr.responseText)); return; } catch (e) {}
            }
            if (!root.current) root.weatherError = "Weather unavailable";
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function fetchWeather() {
        getJson("http://ip-api.com/json/", loc => {
            const url = "https://api.open-meteo.com/v1/forecast?latitude=" + loc.lat
                + "&longitude=" + loc.lon
                + "&current=temperature_2m,weather_code,is_day,apparent_temperature"
                + "&hourly=temperature_2m,weather_code,is_day"
                + "&daily=temperature_2m_max,temperature_2m_min,weather_code"
                + "&temperature_unit=fahrenheit&timezone=auto&forecast_days=5";
            getJson(url, w => {
                w.location = loc.city;
                w.fetched = Date.now();
                applyWeather(w);
                cache.setText(JSON.stringify(w));
            });
        });
    }

    // Show the last forecast instantly, refresh in the background if stale.
    FileView {
        id: cache
        path: root.cacheFile
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            let fresh = false;
            try {
                const w = JSON.parse(text());
                root.applyWeather(w);
                fresh = Date.now() - w.fetched < 15 * 60 * 1000;
            } catch (e) {}
            if (!fresh) root.fetchWeather();
        }
    }

    // ---- calendar state ----
    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    function shiftMonth(n) {
        let m = viewMonth + n, y = viewYear;
        while (m < 0) { m += 12; y--; }
        while (m > 11) { m -= 12; y++; }
        viewMonth = m; viewYear = y;
    }

    // 6 weeks of cells, Monday first, padded with the neighbouring months.
    function monthCells(y, m) {
        const first = (new Date(y, m, 1).getDay() + 6) % 7;
        const inMonth = new Date(y, m + 1, 0).getDate();
        const prevDays = new Date(y, m, 0).getDate();
        const cells = [];
        for (let i = first - 1; i >= 0; i--) cells.push({ d: prevDays - i, cur: false });
        for (let d = 1; d <= inMonth; d++) cells.push({ d: d, cur: true });
        for (let d = 1; cells.length < 42; d++) cells.push({ d: d, cur: false });
        return cells;
    }

    IpcHandler {
        target: "calweather"
        function close(): void { Qt.quit(); }
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors.top: true
        margins.top: 6
        exclusiveZone: 0
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "calweather"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // Hyprland clears a grab that is taken before the surface maps, so
        // only arm click-outside-to-close once the popup is on screen.
        Timer {
            interval: 150
            running: true
            onTriggered: grab.active = true
        }

        HyprlandFocusGrab {
            id: grab
            windows: [win]
            onCleared: { console.log("calweather: grab cleared"); Qt.quit(); }
        }

        Rectangle {
            id: card
            implicitWidth: 340
            implicitHeight: content.implicitHeight + 36
            radius: 16
            color: Qt.rgba(10 / 255, 10 / 255, 12 / 255, 1)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)
            focus: true
            Keys.onEscapePressed: Qt.quit()

            opacity: 0
            scale: 0.96
            transformOrigin: Item.Top
            Component.onCompleted: { opacity = 1; scale = 1; }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                // ---------- calendar ----------
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: Qt.locale().standaloneMonthName(root.viewMonth) + " " + root.viewYear
                        color: root.fg
                        font.pixelSize: 16
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Repeater {
                        model: [{ g: "\u{F0141}", n: -1 }, { g: "\u{F0142}", n: 1 }]
                        Rectangle {
                            required property var modelData
                            implicitWidth: 28; implicitHeight: 28; radius: 8
                            color: navMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                            Text {
                                anchors.centerIn: parent
                                text: modelData.g
                                font.family: root.iconFont
                                font.pixelSize: 16
                                color: root.fg
                            }
                            MouseArea {
                                id: navMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.shiftMonth(modelData.n)
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.alignment: Qt.AlignHCenter
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 6

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        Text {
                            required property string modelData
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: root.muted
                            opacity: 0.7
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    Repeater {
                        model: root.monthCells(root.viewYear, root.viewMonth)
                        Rectangle {
                            required property var modelData
                            readonly property bool isToday: modelData.cur
                                && modelData.d === root.today.getDate()
                                && root.viewMonth === root.today.getMonth()
                                && root.viewYear === root.today.getFullYear()
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 30
                            radius: 8
                            color: isToday ? root.accent : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.d
                                font.pixelSize: 13
                                font.bold: isToday
                                color: isToday ? root.bg : root.fg
                                opacity: modelData.cur ? 1 : 0.25
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Qt.rgba(1, 1, 1, 0.07)
                }

                // ---------- weather ----------
                Text {
                    visible: root.current === null
                    Layout.alignment: Qt.AlignHCenter
                    text: root.weatherError || "Loading weather…"
                    color: root.muted
                    font.pixelSize: 13
                }

                ColumnLayout {
                    visible: root.current !== null
                    Layout.fillWidth: true
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: root.current ? root.weatherIcon(root.current.weather_code, root.current.is_day === 1) : ""
                            font.family: root.iconFont
                            font.pixelSize: 38
                            color: root.accent
                        }
                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: root.current ? Math.round(root.current.temperature_2m) + "°F" : ""
                                color: root.fg
                                font.pixelSize: 28
                                font.bold: true
                            }
                            Text {
                                text: root.current ? root.weatherText(root.current.weather_code)
                                      + (root.location ? " · " + root.location : "") : ""
                                color: root.muted
                                font.pixelSize: 12
                            }
                        }
                        Item { Layout.fillWidth: true }
                        ColumnLayout {
                            spacing: 2
                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: root.daily.length ? "\u{F0360} " + Math.round(root.daily[0].max) + "°" : ""
                                font.family: root.iconFont
                                font.pixelSize: 13
                                color: root.fg
                            }
                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: root.daily.length ? "\u{F035D} " + Math.round(root.daily[0].min) + "°" : ""
                                font.family: root.iconFont
                                font.pixelSize: 13
                                color: root.muted
                            }
                        }
                    }

                    // hourly: equal fixed-width columns across the card
                    Row {
                        id: hourRow
                        Layout.fillWidth: true
                        Repeater {
                            model: root.hourly
                            ColumnLayout {
                                required property var modelData
                                required property int index
                                width: hourRow.width / Math.max(1, root.hourly.length)
                                spacing: 4
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: index === 0 ? "Now" : root.hourLabel(modelData.time)
                                    color: root.muted
                                    font.pixelSize: 11
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.weatherIcon(modelData.code, modelData.day)
                                    font.family: root.iconFont
                                    font.pixelSize: 20
                                    color: root.fg
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Math.round(modelData.temp) + "°"
                                    color: root.fg
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }
                    }

                    // daily, with a range bar scaled across the whole week
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        readonly property real lo: Math.min(...root.daily.map(d => d.min))
                        readonly property real hi: Math.max(...root.daily.map(d => d.max))
                        id: dailyCol

                        Repeater {
                            model: root.daily
                            RowLayout {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: 10
                                Text {
                                    Layout.preferredWidth: 40
                                    text: index === 0 ? "Today" : Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd")
                                    color: root.fg
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    Layout.preferredWidth: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.weatherIcon(modelData.code, true)
                                    font.family: root.iconFont
                                    font.pixelSize: 15
                                    color: root.fg
                                }
                                Text {
                                    Layout.preferredWidth: 28
                                    horizontalAlignment: Text.AlignRight
                                    text: Math.round(modelData.min) + "°"
                                    color: root.muted
                                    font.pixelSize: 12
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 6
                                    radius: 3
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    Rectangle {
                                        readonly property real span: Math.max(1, dailyCol.hi - dailyCol.lo)
                                        x: parent.width * (modelData.min - dailyCol.lo) / span
                                        width: Math.max(6, parent.width * (modelData.max - modelData.min) / span)
                                        height: parent.height
                                        radius: 3
                                        color: root.accent
                                    }
                                }
                                Text {
                                    Layout.preferredWidth: 28
                                    text: Math.round(modelData.max) + "°"
                                    color: root.fg
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
