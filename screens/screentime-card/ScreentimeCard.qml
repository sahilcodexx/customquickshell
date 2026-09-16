import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Habit-style screentime card. Reads screentime data via the `screentime`
// daemon (--export) and renders a heatmap + 7-day breakdown that matches
// the rest of end-4's UI conventions (font families, sizes, surface tones,
// rounding).

Item {
    id: root

    // Emitted when the user clicks the close button. The hosting shell
    // listens and toggles its panel visibility.
    signal closeRequested()

    // ----- Appearance (wallpaper-driven via ThemeLoader) -----
    readonly property var m3: theme.m3colors
    readonly property color colBackground: m3.m3surfaceContainerHigh
    readonly property color colBorder: m3.m3outlineVariant
    readonly property color colText: m3.m3onSurface
    readonly property color colTextDim: m3.m3onSurfaceVariant
    readonly property color colEmpty: Qt.rgba(m3.m3onSurface.r, m3.m3onSurface.g, m3.m3onSurface.b, 0.10)
    readonly property color colAccent: m3.m3primary
    readonly property color colAccentContainer: m3.m3primaryContainer
    readonly property color colOnAccent: m3.m3onPrimary
    readonly property color colTodayAccent: m3.m3tertiary

    // ----- end-4 font conventions (mirrors Appearance.qml) -----
    readonly property string fontTitle: "Google Sans Flex"
    readonly property string fontMain: "Google Sans Flex"
    readonly property string fontMono: "JetBrains Mono NF"

    // ----- Data -----
    property var cells: []
    property var today: ({})
    property var week: []
    property int allTimeTotalSecs: 0
    property int lastUpdatedAt: 0 // unix seconds of last successful fetch
    property int currentSecs: 0 // today secs at last fetch (drives "live" total)

    // Returns true once at least one data source has populated
    readonly property bool dataReady: cells.length > 0 && week.length > 0

    // ----- Fallback data so the card always has consistent layout -----
    // 105 empty placeholder cells (7 rows × 15 cols, all zero, none future)
    readonly property var fallbackCells: {
        const arr = []
        const today = new Date()
        today.setHours(0, 0, 0, 0)
        for (let i = 0; i < 105; i++) {
            const d = new Date(today)
            d.setDate(today.getDate() - (104 - i))
            const iso = d.toISOString().slice(0, 10)
            arr.push({ day: iso, future: false, secs: 0 })
        }
        return arr
    }
    readonly property var displayCells: cells.length > 0 ? cells : fallbackCells

    // 7 day rows for the LAST 7 DAYS list — populated with current week
    readonly property var fallbackWeek: {
        const arr = []
        const today = new Date()
        today.setHours(0, 0, 0, 0)
        for (let i = 6; i >= 0; i--) {
            const d = new Date(today)
            d.setDate(today.getDate() - i)
            const iso = d.toISOString().slice(0, 10)
            arr.push({
                day: iso,
                by_app: {},
                by_app_score: {},
                total_secs: 0,
                weighted_score: 0,
                productive_secs: 0,
                neutral_secs: 0,
                unprod_secs: 0
            })
        }
        return arr
    }
    readonly property var displayWeek: week.length > 0 ? week : fallbackWeek

    // ----- Layout constants -----
    readonly property int heatmapRows: 7
    readonly property int heatmapCols: 15
    readonly property real cellSize: 20
    readonly property real cellGap: 3
    readonly property real rowHeight: 32

    // Inlined ThemeLoader (avoids cross-file import issues for standalone qs)
    QtObject {
        id: theme

        property QtObject m3colors: QtObject {
            property color m3background: "#131412"
            property color m3onBackground: "#e4e2df"
            property color m3surface: "#131412"
            property color m3onSurface: "#e4e2df"
            property color m3surfaceContainerLowest: "#0e0f0d"
            property color m3surfaceContainerLow: "#1b1c19"
            property color m3surfaceContainer: "#1f211e"
            property color m3surfaceContainerHigh: "#2a2b28"
            property color m3surfaceContainerHighest: "#353633"
            property color m3onSurfaceVariant: "#c7c6c3"
            property color m3outline: "#91918e"
            property color m3outlineVariant: "#464745"
            property color m3primary: "#bdcab9"
            property color m3onPrimary: "#283327"
            property color m3primaryContainer: "#3e4a3d"
            property color m3onPrimaryContainer: "#d9e6d5"
            property color m3secondary: "#bdcab9"
            property color m3onSecondary: "#2b322a"
            property color m3tertiary: "#a97363"
            property color m3onTertiary: "#3d1f12"
            property color m3inverseSurface: "#e4e2df"
            property color m3inverseOnSurface: "#30312f"
            property bool darkmode: true
        }

        readonly property string colorsPath: Quickshell.env("HOME") + "/.local/state/quickshell/user/generated/colors.json"

        function apply(json) {
            try {
                let obj = JSON.parse(json)
                for (const key in obj) {
                    if (!obj.hasOwnProperty(key)) continue
                    const camel = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
                    const m3key = "m3" + camel
                    if (m3key in m3colors) {
                        m3colors[m3key] = obj[key]
                    }
                }
                m3colors.darkmode = (m3colors.m3background.hslLightness < 0.5)
            } catch (e) {
                console.warn("screentime-card: failed to apply colors:", e)
            }
        }
    }

    Timer {
        id: themeDelayed
        interval: 100
        repeat: false
        running: false
        onTriggered: theme.apply(themeFile.text())
    }

    FileView {
        id: themeFile
        path: Qt.resolvedUrl(theme.colorsPath)
        watchChanges: true
        onLoadedChanged: {
            if (loaded) theme.apply(text())
        }
        onFileChanged: {
            reload()
            themeDelayed.restart()
        }
        onLoadFailed: console.warn("screentime-card: could not load colors at", path)
    }

    // ----- Wallpaper path (read from end-4's illogical-impulse config) -----
    property string wallpaperPath: ""

    FileView {
        id: configFile
        path: Qt.resolvedUrl(Quickshell.env("HOME") + "/.config/illogical-impulse/config.json")
        watchChanges: true
        onLoadedChanged: {
            if (!loaded) return
            try {
                const cfg = JSON.parse(text())
                const wp = cfg?.background?.wallpaperPath || ""
                if (wp && wp !== root.wallpaperPath) {
                    root.wallpaperPath = wp
                }
            } catch (e) {
                console.warn("screentime-card: failed to parse config:", e)
            }
        }
        onFileChanged: reload()
        onLoadFailed: console.warn("screentime-card: could not load config at", path)
    }

    // ----- Helpers -----
    property int maxCellSecs: {
        let m = 1
        for (let i = 0; i < cells.length; i++) {
            if (cells[i].secs > m) m = cells[i].secs
        }
        return m
    }

    function intensityFor(secs) {
        if (secs <= 0) return 0
        let ratio = secs / root.maxCellSecs
        if (ratio < 0.25) return 1
        if (ratio < 0.50) return 2
        if (ratio < 0.75) return 3
        return 4
    }

    function colorFor(secs, isFuture, isToday) {
        if (isFuture) return Qt.rgba(0, 0, 0, 0)
        if (isToday) return colTodayAccent
        let level = intensityFor(secs)
        if (level === 0) return colEmpty
        let alphas = [0.0, 0.25, 0.55, 0.80, 1.0]
        return Qt.rgba(colText.r, colText.g, colText.b, alphas[level])
    }

    function formatHours(secs) {
        if (secs <= 0) return null
        let h = Math.floor(secs / 3600)
        let m = Math.floor((secs % 3600) / 60)
        let s = secs % 60
        if (h === 0 && m === 0) return s + "s"
        if (h === 0 && m < 5) return m + "m " + s + "s"
        if (h === 0) return m + "m"
        if (m === 0) return h + "h"
        return h + "h " + m + "m"
    }

    function fullDayLabel(iso) {
        let d = new Date(iso + "T00:00:00")
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return days[d.getDay()] + " " + months[d.getMonth()] + " " + d.getDate()
    }

    function longDayLabel(iso) {
        let d = new Date(iso + "T00:00:00")
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate()
    }

    function isToday(iso) {
        let d = new Date(iso + "T00:00:00")
        let t = new Date()
        return d.getFullYear() === t.getFullYear() && d.getMonth() === t.getMonth() && d.getDate() === t.getDate()
    }

    function refresh() {
        allProc.running = false
        allProc.running = true
        todayProc.running = false
        todayProc.running = true
        weekProc.running = false
        weekProc.running = true
    }

    Process {
        id: allProc
        property string allBuffer: ""
        command: ["screentime", "--export", "all"]
        stdout: SplitParser {
            onRead: data => {
                allProc.allBuffer += data
            }
        }
        onExited: {
            try {
                let parsed = JSON.parse(allProc.allBuffer)
                let c = parsed.cells || []
                root.cells = c
                let total = 0
                for (let i = 0; i < c.length; i++) {
                    if (!c[i].future) total += c[i].secs
                }
                root.allTimeTotalSecs = total
            } catch (e) { console.warn("screentime-card: all parse failed:", e) }
            allProc.allBuffer = ""
        }
    }

    Process {
        id: todayProc
        property string todayBuffer: ""
        command: ["screentime", "--export", "today"]
        stdout: SplitParser {
            onRead: data => {
                todayProc.todayBuffer += data
            }
        }
        onExited: {
            try {
                const parsed = JSON.parse(todayProc.todayBuffer)
                root.today = parsed
                if (parsed && typeof parsed.total_secs === "number") {
                    root.currentSecs = parsed.total_secs
                    root.lastUpdatedAt = Math.floor(Date.now() / 1000)
                }
            }
            catch (e) { console.warn("screentime-card: today parse failed:", e) }
            todayProc.todayBuffer = ""
        }
    }

    Process {
        id: weekProc
        property var weekLines: []
        command: ["screentime", "--export", "week"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim()) weekProc.weekLines.push(data)
            }
        }
        onExited: {
            try {
                let arr = []
                for (const line of weekProc.weekLines) {
                    arr.push(JSON.parse(line))
                }
                root.week = arr
            } catch (e) { console.warn("screentime-card: week parse failed:", e) }
            weekProc.weekLines = []
        }
    }

    Timer {
        id: refreshTimer
        interval: 15000 // refresh every 15s — feels live without hammering
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Tick up currentSecs by 1 every second between fetches so the Total
    // display feels live even before the daemon's next sample lands.
    Timer {
        id: tickTimer
        interval: 1000
        repeat: true
        running: root.lastUpdatedAt > 0
        onTriggered: root.currentSecs += 1
    }

    // ----- Render -----
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 460
        // Height is computed from content so all 7 days always fit
        height: contentColumn.implicitHeight + 2 * 24
        radius: 0 // sharp corners per user request

        // Wallpaper backdrop with frosted blur — clip prevents the blur from
        // leaking past the card's bounds. Strong tint masks any edge halo.
        Rectangle {
            id: bgStack
            anchors.fill: parent
            color: "transparent"
            clip: true

            Image {
                id: bgImage
                anchors.fill: parent
                source: root.wallpaperPath ? "file://" + root.wallpaperPath : ""
                fillMode: Image.PreserveAspectCrop
                cache: true
                asynchronous: true
                visible: status === Image.Ready
                layer.enabled: true
                layer.smooth: true
            }

            MultiEffect {
                anchors.fill: bgImage
                source: bgImage
                blurEnabled: true
                blur: 1
                blurMax: 24
            }

            // Strong tint on top of blurred wallpaper
            Rectangle {
                anchors.fill: parent
                color: root.colBackground.a > 0 ? root.colBackground : "#2a2b28"
                opacity: 0.88
            }
        }

        // Border
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(root.colBorder.r, root.colBorder.g, root.colBorder.b, 0.4)
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            // --- Header: title + close ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "SCREENTIME"
                    color: root.colText
                    font.family: root.fontMono
                    font.pixelSize: 14
                    font.letterSpacing: 2
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: closeBtn
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: closeArea.containsMouse
                        ? Qt.rgba(root.colText.r, root.colText.g, root.colText.b, 0.12)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: root.colTextDim
                        font.pixelSize: 18
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: {
                            root.closeRequested()
                        }
                    }
                }
            }

            // --- Heatmap ---
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.cellSize * root.heatmapRows + root.cellGap * (root.heatmapRows - 1)
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: root.displayCells.length
                    delegate: Rectangle {
                        property var cell: root.displayCells[index]
                        property int col: Math.floor(index / root.heatmapRows)
                        property int row: index % root.heatmapRows
                        property bool cellIsToday: root.isToday(cell.day)
                        property string cellDur: root.formatHours(cell.secs)
                        width: root.cellSize
                        height: root.cellSize
                        radius: 4
                        x: col * (root.cellSize + root.cellGap)
                        y: row * (root.cellSize + root.cellGap)
                        color: root.colorFor(cell.secs, cell.future, cellIsToday)
                        Behavior on color { ColorAnimation { duration: 200 } }

                        HoverHandler {
                            id: cellHover
                            cursorShape: Qt.PointingHandCursor
                            enabled: !cell.future
                        }
                        ToolTip {
                            id: cellTip
                            visible: cellHover.hovered
                            delay: 200
                            timeout: 4000
                            background: Rectangle {
                                color: root.m3.m3inverseSurface
                                radius: 6
                                border.color: Qt.rgba(root.colBorder.r, root.colBorder.g, root.colBorder.b, 0.4)
                                border.width: 1
                            }
                            contentItem: Column {
                                spacing: 2
                                Text {
                                    text: root.longDayLabel(cell.day) + (cellIsToday ? " · today" : "")
                                    color: root.m3.m3inverseOnSurface
                                    font.family: root.fontMain
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }
                                Text {
                                    text: cell.future
                                        ? "—"
                                        : (cellDur ? cellDur : "No activity")
                                    color: root.m3.m3inverseOnSurface
                                    font.family: root.fontMono
                                    font.pixelSize: 11
                                    opacity: 0.85
                                }
                            }
                        }
                    }
                }
            }

            // --- Less / More + total ---
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                Text {
                    text: "Less"
                    color: root.colTextDim
                    font.family: root.fontMain
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Row {
                    spacing: 3
                    Repeater {
                        model: 5
                        delegate: Rectangle {
                            width: 14
                            height: 14
                            radius: 3
                            color: {
                                if (index === 0) return root.colEmpty
                                let alphas = [0.0, 0.25, 0.55, 0.80, 1.0]
                                return Qt.rgba(root.colText.r, root.colText.g, root.colText.b, alphas[index])
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "Total " + (root.currentSecs > 0 ? root.formatHours(root.currentSecs) : "—")
                    color: root.colTextDim
                    font.family: root.fontMono
                    font.pixelSize: 12
                }
            }

            // --- Separator ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(root.colBorder.r, root.colBorder.g, root.colBorder.b, 0.3)
            }

            // --- LAST 7 DAYS ---
            Text {
                text: "LAST 7 DAYS"
                color: root.colTextDim
                font.family: root.fontMain
                font.pixelSize: 11
                font.letterSpacing: 2
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                Layout.topMargin: 2
            }

            // Each row: bullet + day label + duration
            Column {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 0

                Repeater {
                    model: root.displayWeek
                    delegate: Item {
                        required property var modelData
                        width: parent ? parent.width : 0
                        height: root.rowHeight
                        property bool rowIsToday: root.isToday(modelData.day)
                        property string rowDur: rowIsToday && root.currentSecs > 0
                            ? root.formatHours(root.currentSecs)
                            : root.formatHours(modelData.total_secs)

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: rowIsToday
                                ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.20)
                                : "transparent"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 14
                            spacing: 10

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: rowIsToday ? root.colAccent : root.colTextDim
                            }

                            Text {
                                text: root.fullDayLabel(modelData.day)
                                color: root.colText
                                font.family: root.fontMain
                                font.pixelSize: 14
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: rowDur ? rowDur : "No activity"
                                color: rowIsToday ? root.colText : root.colTextDim
                                font.family: root.fontMono
                                font.pixelSize: 13
                                font.weight: rowDur ? Font.Medium : Font.Normal
                                font.italic: !rowDur
                            }
                        }
                    }
                }
            }
        }
    }
}