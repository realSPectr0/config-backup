import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PopupPanel {
    id: root

    title: "Weather"
    subtitle: location.length > 0 ? location : "wttr.in auto location"
    panelWidth: 560

    property string location: ""
    property string temp: "--"
    property string feels: "--"
    property string condition: "Loading..."
    property string weatherIcon: "󰖐"
    property string humidity: "--"
    property string wind: "--"
    property string pressure: "--"
    property string rain: "--"
    property string uv: "--"
    property string visibility: "--"
    property string cloud: "--"
    property string highLow: "--"
    property string sunrise: "--"
    property string sunset: "--"
    property string moon: "--"
    property string updated: ""
    property bool loading: false

    function conditionIcon(desc, code) {
        const d = (desc || "").toLowerCase()
        if (d.indexOf("thunder") !== -1) return "󰙾"
        if (d.indexOf("snow") !== -1 || d.indexOf("sleet") !== -1) return "󰼶"
        if (d.indexOf("rain") !== -1 || d.indexOf("shower") !== -1 || d.indexOf("drizzle") !== -1) return "󰖗"
        if (d.indexOf("fog") !== -1 || d.indexOf("mist") !== -1) return "󰖑"
        if (d.indexOf("cloud") !== -1 || d.indexOf("overcast") !== -1) return "󰖐"
        if (d.indexOf("clear") !== -1) return "󰖔"
        if (d.indexOf("sun") !== -1) return "󰖙"
        return "󰖐"
    }

    function hourLabel(raw) {
        let n = parseInt(raw) || 0
        let h = Math.floor(n / 100)
        const suffix = h >= 12 ? "PM" : "AM"
        h = h % 12
        if (h === 0) h = 12
        return h + " " + suffix
    }

    function dayLabel(raw, index) {
        const d = new Date(raw + "T12:00:00")
        if (!isNaN(d.getTime()))
            return d.toLocaleDateString("en-US", { weekday: "short" })
        return index === 0 ? "Today" : "Day " + (index + 1)
    }

    function refresh() {
        loading = true
        weatherProc.running = false
        weatherProc.running = true
    }

    function parseWeather(raw) {
        try {
            const data = JSON.parse(raw)
            const current = data.current_condition?.[0] || {}
            const area = data.nearest_area?.[0] || {}
            const today = data.weather?.[0] || {}
            const astro = today.astronomy?.[0] || {}
            const name = area.areaName?.[0]?.value || ""
            const region = area.region?.[0]?.value || ""
            const desc = current.weatherDesc?.[0]?.value || "Unknown"

            location = region.length > 0 ? name + ", " + region : name
            temp = (current.temp_F || "--") + "°"
            feels = (current.FeelsLikeF || "--") + "°"
            condition = desc
            weatherIcon = conditionIcon(desc, current.weatherCode || "")
            humidity = (current.humidity || "--") + "%"
            wind = (current.windspeedMiles || "--") + " mph " + (current.winddir16Point || "")
            pressure = (current.pressureInches || "--") + " in"
            rain = (current.precipInches || "0.0") + " in"
            uv = current.uvIndex || "--"
            visibility = (current.visibilityMiles || "--") + " mi"
            cloud = (current.cloudcover || "--") + "%"
            highLow = today.maxtempF && today.mintempF ? today.mintempF + "° / " + today.maxtempF + "°" : "--"
            sunrise = astro.sunrise || "--"
            sunset = astro.sunset || "--"
            moon = astro.moon_phase || "--"
            updated = current.localObsDateTime || ""

            hourlyModel.clear()
            const nowSlot = new Date().getHours() * 100
            const days = data.weather || []
            let added = 0
            for (let d = 0; d < days.length && added < 6; d++) {
                const hours = days[d].hourly || []
                for (let i = 0; i < hours.length && added < 6; i++) {
                    const h = hours[i]
                    const slot = parseInt(h.time) || 0
                    if (d === 0 && slot < nowSlot)
                        continue
                    const hDesc = h.weatherDesc?.[0]?.value || ""
                    hourlyModel.append({
                        time: hourLabel(h.time),
                        icon: conditionIcon(hDesc, h.weatherCode || ""),
                        temp: (h.tempF || "--") + "°",
                        rain: (h.chanceofrain || "0") + "%"
                    })
                    added++
                }
            }

            dailyModel.clear()
            for (let i = 0; i < Math.min(3, days.length); i++) {
                const day = days[i]
                const noon = day.hourly?.[4] || day.hourly?.[0] || {}
                const dDesc = noon.weatherDesc?.[0]?.value || ""
                dailyModel.append({
                    day: i === 0 ? "Today" : dayLabel(day.date, i),
                    icon: conditionIcon(dDesc, noon.weatherCode || ""),
                    range: (day.mintempF || "--") + "° / " + (day.maxtempF || "--") + "°",
                    desc: dDesc || "Forecast"
                })
            }
        } catch (e) {
            condition = "Weather unavailable"
            location = ""
            temp = "--"
            feels = "--"
            humidity = "--"
            wind = "--"
            pressure = "--"
            rain = "--"
            uv = "--"
            visibility = "--"
            cloud = "--"
            highLow = "--"
            hourlyModel.clear()
            dailyModel.clear()
        }
        loading = false
    }

    onShowingChanged: if (showing) refresh()

    ListModel { id: hourlyModel }
    ListModel { id: dailyModel }

    Process {
        id: weatherProc
        command: ["curl", "-fsS", "--max-time", "6", "https://wttr.in/?format=j1"]
        stdout: StdioCollector { onStreamFinished: root.parseWeather(text.trim()) }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.loading = false
                root.condition = "Weather unavailable"
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 164
        radius: 14
        color: root.cCard
        border.width: 1
        border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.38)
        clip: true

        Rectangle {
            anchors.fill: parent
            opacity: 0.24
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.66) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        RowLayout {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 18

            Rectangle {
                Layout.preferredWidth: 104
                Layout.preferredHeight: 104
                Layout.alignment: Qt.AlignVCenter
                radius: 28
                color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.52)

                Text {
                    anchors.centerIn: parent
                    text: root.weatherIcon
                    color: root.cAccent
                    font { pixelSize: 48; family: root.cFont }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: root.temp
                        color: root.cFg
                        font { pixelSize: 44; family: root.cFont }
                        Layout.alignment: Qt.AlignBottom
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBottom
                        spacing: 1

                        Text {
                            text: root.condition
                            color: root.cFg
                            font { pixelSize: 15; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "Feels " + root.feels + " · " + root.highLow
                            color: root.cDim
                            font { pixelSize: 10; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }
                    }
                }

                Text {
                    text: root.location
                    color: root.cDim
                    font { pixelSize: 11; family: root.cFont }
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: 22
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 5 + ((index * 5) % 18)
                            radius: 2
                            color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.16 + (index % 5) * 0.055)
                        }
                    }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 8
        columnSpacing: 8

        Repeater {
            model: [
                { icon: "󰖎", label: "Humidity", value: root.humidity },
                { icon: "󰖝", label: "Wind", value: root.wind },
                { icon: "󰖑", label: "Clouds", value: root.cloud },
                { icon: "󰖈", label: "Rain", value: root.rain },
                { icon: "󰔏", label: "UV", value: root.uv },
                { icon: "󰥻", label: "Visibility", value: root.visibility }
            ]

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                radius: 9
                color: root.cCard
                border.width: 1
                border.color: root.cBord

                RowLayout {
                    anchors {
                        fill: parent
                        margins: 9
                    }
                    spacing: 8

                    Text {
                        text: modelData.icon
                        color: root.cAccent
                        font { pixelSize: 16; family: root.cFont }
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            text: modelData.label
                            color: root.cDim
                            font { pixelSize: 9; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }

                        Text {
                            text: modelData.value
                            color: root.cFg
                            font { pixelSize: 11; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    Text {
        text: "Next hours"
        color: root.cFg
        font { pixelSize: 12; family: root.cFont }
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: hourlyModel
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 82
                radius: 10
                color: root.cCard
                border.width: 1
                border.color: root.cBord

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    spacing: 3

                    Text {
                        text: time
                        color: root.cDim
                        font { pixelSize: 9; family: root.cFont }
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    Text {
                        text: icon
                        color: root.cAccent
                        font { pixelSize: 18; family: root.cFont }
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    Text {
                        text: temp
                        color: root.cFg
                        font { pixelSize: 11; family: root.cFont }
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "󰖗 " + rain
                        color: root.cDim
                        font { pixelSize: 9; family: root.cFont }
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    Text {
        text: "Forecast"
        color: root.cFg
        font { pixelSize: 12; family: root.cFont }
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: dailyModel
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                radius: 10
                color: root.cCard
                border.width: 1
                border.color: root.cBord

                RowLayout {
                    anchors {
                        fill: parent
                        margins: 10
                    }
                    spacing: 9

                    Text {
                        text: icon
                        color: root.cAccent
                        font { pixelSize: 22; family: root.cFont }
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            text: day
                            color: root.cFg
                            font { pixelSize: 12; family: root.cFont }
                            Layout.fillWidth: true
                        }

                        Text {
                            text: range
                            color: root.cAccent
                            font { pixelSize: 10; family: root.cFont }
                            Layout.fillWidth: true
                        }

                        Text {
                            text: desc
                            color: root.cDim
                            font { pixelSize: 9; family: root.cFont }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
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
            icon: "󰖜"
            label: "Sunrise"
            sublabel: root.sunrise
            enabled: false
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
        }

        ActionButton {
            icon: "󰖛"
            label: "Sunset"
            sublabel: root.sunset
            enabled: false
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
        }

        ActionButton {
            icon: root.loading ? "󰔟" : "󰑓"
            label: root.loading ? "Refreshing" : "Refresh"
            sublabel: root.updated.length > 0 ? root.updated : "wttr.in"
            fg: root.cFg; dim: root.cDim; bg: root.cCard; border_: root.cBord; accent: root.cAccent; font_: root.cFont
            onClicked: root.refresh()
        }
    }
}
