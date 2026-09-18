import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// GitHub dashboard card matching end-4's frosted style.
// Tabs: Overview / Inbox / Pulls / Actions.

Item {
    id: root

    signal closeRequested()
    signal refreshRequested()

    // ----- Appearance (wallpaper-driven) -----
    readonly property var m3: theme.m3colors
    readonly property color colBackground: m3.m3surfaceContainerHigh
    readonly property color colBackgroundLow: m3.m3surfaceContainerLow
    readonly property color colBorder: m3.m3outlineVariant
    readonly property color colText: m3.m3onSurface
    readonly property color colTextDim: m3.m3onSurfaceVariant
    readonly property color colAccent: m3.m3primary
    readonly property color colAccentContainer: m3.m3primaryContainer
    readonly property color colOnAccent: m3.m3onPrimary
    readonly property color colInverse: m3.m3inverseSurface
    readonly property color colOnInverse: m3.m3inverseOnSurface
    readonly property color colTodayAccent: m3.m3tertiary

    // ----- end-4 font conventions -----
    readonly property string fontTitle: "Google Sans Flex"
    readonly property string fontMain: "Google Sans Flex"
    readonly property string fontMono: "JetBrains Mono NF"

    // ----- State -----
    property string activeTab: "overview"
    property bool loading: false
    property var ghData: ({
        "user": {},
        "stats": { "stars_total": 0, "public_repos": 0, "followers": 0,
                   "contributions_total": 0, "streak_current": 0,
                   "streak_best": 0, "streak_today": 0 },
        "calendar": { "weeks": [], "days": [], "total": 0 },
        "streaks": { "current": 0, "best": 0, "today": 0 },
        "top_repos": [],
        "notifications": [],
        "open_prs": [],
        "actions": { "total": 0, "failing": 0, "items": [] },
        "_fetched_at": 0
    })

    // ----- Layout -----
    readonly property real cardWidth: 920
    readonly property int heatmapRows: 7
    readonly property int heatmapCols: 53
    readonly property real cellSize: 13
    readonly property real cellGap: 1

    // ----- Inlined theme loader -----
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
            property color m3error: "#ffb4ab"
            property color m3onError: "#690005"
            property bool darkmode: true
        }
        readonly property string colorsPath: Quickshell.env("HOME") + "/.local/state/quickshell/user/generated/colors.json"
        function apply(json) {
            try {
                const obj = JSON.parse(json)
                for (const key in obj) {
                    if (!obj.hasOwnProperty(key)) continue
                    const camel = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
                    const m3key = "m3" + camel
                    if (m3key in m3colors) m3colors[m3key] = obj[key]
                }
                m3colors.darkmode = (m3colors.m3background.hslLightness < 0.5)
            } catch (e) {
                console.warn("github-card: failed to apply colors:", e)
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
        onLoadedChanged: { if (loaded) theme.apply(text()) }
        onFileChanged: { reload(); themeDelayed.restart() }
        onLoadFailed: console.warn("github-card: could not load colors at", path)
    }

    // ----- Wallpaper path -----
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
                if (wp && wp !== root.wallpaperPath) root.wallpaperPath = wp
            } catch (e) { console.warn("github-card: config parse failed:", e) }
        }
        onFileChanged: reload()
        onLoadFailed: console.warn("github-card: config.json not loaded")
    }

    // ----- Data fetch -----
    function refresh() {
        loading = true
        refreshProc.running = false
        refreshProc.running = true
    }

    Process {
        id: refreshProc
        property string buffer: ""
        command: ["github-fetch"]
        stdout: SplitParser {
            onRead: data => { refreshProc.buffer += data }
        }
        onExited: {
            loading = false
            try {
                root.ghData = JSON.parse(refreshProc.buffer)
            } catch (e) {
                console.warn("github-card: parse failed:", e)
            }
            refreshProc.buffer = ""
        }
    }

    Timer {
        interval: 300000 // 5 min
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // ----- Helpers -----
    function maxContribCount(): int {
        let m = 1
        const days = ghData?.calendar?.days || []
        for (let i = 0; i < days.length; i++) {
            const c = days[i].count
            if (c > m) m = c
        }
        return m
    }

    // Map a day's contribution count to GitHub's DARK theme palette.
    // 0  → #161b22 (very dark, almost invisible against the dark surface)
    // 1-3 → #0e4429 (dark green)
    // 4-6 → #006d32
    // 7-9 → #26a641
    // 10+ → #39d353 (bright green)
    // Bucketing is by ratio against the dataset max so the most-active
    // days always reach the brightest color regardless of absolute counts.
    function gitHubColorFor(count, max) {
        if (!count || count <= 0) return "#161b22"
        if (!max || max <= 0) return "#0e4429"
        const r = count / max
        if (r >= 0.75) return "#39d353"
        if (r >= 0.50) return "#26a641"
        if (r >= 0.25) return "#006d32"
        return "#0e4429"
    }

    function isToday(iso) {
        if (!iso) return false
        const d = new Date(iso + "T00:00:00")
        const t = new Date()
        return d.getFullYear() === t.getFullYear()
            && d.getMonth() === t.getMonth()
            && d.getDate() === t.getDate()
    }

    // ----- Render -----
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: root.cardWidth
        height: contentColumn.implicitHeight + 2 * 28
        radius: 0 // sharp corners per user request

        // Wallpaper backdrop with frosted blur — clip prevents leak past bounds.
        // Strong tint masks any edge halo.
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

            Rectangle {
                anchors.fill: parent
                color: root.colBackground.a > 0 ? root.colBackground : "#2a2b28"
                opacity: 0.88
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(root.colBorder.r, root.colBorder.g, root.colBorder.b, 0.4)
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 28
            spacing: 18

            // ===== Header =====
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "GITHUB"
                    color: root.colText
                    font.family: root.fontMono
                    font.pixelSize: 15
                    font.letterSpacing: 2
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                }

                // Username pill
                Rectangle {
                    visible: !!root.ghData?.user?.login
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: usernameText.implicitWidth + 16
                    radius: 12
                    color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.20)
                    border.width: 1
                    border.color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.35)
                    Text {
                        id: usernameText
                        anchors.centerIn: parent
                        text: "@" + (root.ghData?.user?.login || "")
                        color: root.colAccent
                        font.family: root.fontMono
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillWidth: true }

                // Refresh
                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    radius: 16
                    color: refreshArea.containsMouse
                        ? Qt.rgba(root.colText.r, root.colText.g, root.colText.b, 0.12)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: root.loading ? "⟳" : "↻"
                        color: root.loading ? root.colAccent : root.colTextDim
                        font.pixelSize: 16
                        font.family: root.fontMono
                        RotationAnimation on rotation {
                            running: root.loading
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }
                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refresh()
                    }
                }

                // Close
                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    radius: 16
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
                        onClicked: root.closeRequested()
                    }
                }
            }

            // ===== Tabs =====
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { id: "overview", label: "Overview", count: 0 },
                        { id: "inbox",    label: "Inbox",    count: root.ghData?.notifications?.length || 0 },
                        { id: "pulls",    label: "Pulls",    count: root.ghData?.open_prs?.length || 0 },
                        { id: "actions",  label: "Actions",  count: root.ghData?.actions?.total || 0 },
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        property bool isActive: root.activeTab === modelData.id
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 12
                        color: isActive
                            ? Qt.rgba(root.colText.r, root.colText.g, root.colText.b, 0.10)
                            : "transparent"
                        border.width: isActive ? 0 : 1
                        border.color: Qt.rgba(root.colBorder.r, root.colBorder.g, root.colBorder.b, 0.3)

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: modelData.label
                                color: root.activeTab === modelData.id ? root.colText : root.colTextDim
                                font.family: root.fontMono
                                font.pixelSize: 12
                                font.weight: root.activeTab === modelData.id ? Font.DemiBold : Font.Normal
                            }
                            Rectangle {
                                visible: modelData.count > 0
                                Layout.preferredHeight: 18
                                Layout.preferredWidth: countText.implicitWidth + 12
                                radius: 9
                                color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.18)
                                Text {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: modelData.count
                                    color: root.colAccent
                                    font.family: root.fontMono
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTab = modelData.id
                        }
                    }
                }
            }

            // ===== Tab content =====
            // Overview tab
            ColumnLayout {
                visible: root.activeTab === "overview"
                Layout.fillWidth: true
                spacing: 16

                // Heatmap header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "CONTRIBUTIONS · LAST 12 MONTHS"
                        color: root.colTextDim
                        font.family: root.fontMono
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                        font.capitalization: Font.AllUppercase
                        font.weight: Font.Medium
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (root.ghData?.stats?.contributions_total || 0).toLocaleString() + " total"
                        color: root.colText
                        font.family: root.fontMono
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }

                // Heatmap
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.cellSize * 7 + root.cellGap * 6
                    Layout.alignment: Qt.AlignHCenter

                    Repeater {
                        model: root.ghData?.calendar?.weeks?.length || 0
                        delegate: Item {
                            required property int index
                            property var week: root.ghData.calendar.weeks[index]
                            width: 7 * root.cellSize + 6 * root.cellGap
                            height: root.cellSize * 7 + root.cellGap * 6
                            x: index * (root.cellSize + root.cellGap)
                            Repeater {
                                model: week
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    property int col: Math.floor(index / 7)
                                    property int row: index % 7
                                    width: root.cellSize
                                    height: root.cellSize
                                    radius: 3
                                    x: col * (root.cellSize + root.cellGap)
                                    y: row * (root.cellSize + root.cellGap)
                                    // GitHub's GraphQL returns the LIGHT theme palette
                                    // by default (`#ebedf0` for zero commits — near-white).
                                    // Map by count instead so the card uses the dark-theme
                                    // intensity ramp that matches the rest of the UI.
                                    color: root.gitHubColorFor(modelData.count, root.maxContribCount())
                                    HoverHandler {
                                        id: cellHover
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !!modelData.date
                                    }
                                    ToolTip {
                                        visible: cellHover.hovered
                                        delay: 200
                                        background: Rectangle {
                                            color: root.m3.m3inverseSurface
                                            radius: 6
                                            border.color: Qt.rgba(root.colBorder.r, root.colBorder.g, root.colBorder.b, 0.4)
                                            border.width: 1
                                        }
                                        contentItem: Column {
                                            spacing: 2
                                            Text {
                                                text: modelData.date || ""
                                                color: root.m3.m3inverseOnSurface
                                                font.family: root.fontMain
                                                font.pixelSize: 11
                                            }
                                            Text {
                                                text: (modelData.count || 0) + " contribution" + ((modelData.count || 0) === 1 ? "" : "s")
                                                color: root.m3.m3inverseOnSurface
                                                font.family: root.fontMono
                                                font.pixelSize: 10
                                                opacity: 0.85
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Legend + streak info
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Less"
                        color: root.colTextDim
                        font.family: root.fontMain
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Row {
                        spacing: 3
                        Repeater {
                            model: 5
                            delegate: Rectangle {
                                width: 12; height: 12
                                radius: 2
                                color: {
                                    // GitHub's standard intensity ramp (dark theme)
                                    const colors = ["#161b22", "#0e4429", "#006d32", "#26a641", "#39d353"]
                                    return colors[index]
                                }
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (root.ghData?.stats?.streak_today || 0) + " today · "
                              + (root.ghData?.stats?.streak_current || 0) + " day streak · best "
                              + (root.ghData?.stats?.streak_best || 0)
                        color: root.colTextDim
                        font.family: root.fontMono
                        font.pixelSize: 11
                    }
                }

                // 4 stat cards
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 10

                    Repeater {
                        model: [
                            { label: "CONTRIBS",  value: root.ghData?.stats?.contributions_total || 0 },
                            { label: "STARS",     value: root.ghData?.stats?.stars_total >= 0 ? (root.ghData.stats.stars_total || 0) : 0 },
                            { label: "FOLLOWERS", value: root.ghData?.stats?.followers || 0 },
                            { label: "STREAK",    value: root.ghData?.stats?.streak_current || 0 },
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: 12
                            color: Qt.rgba(root.colBackgroundLow.r, root.colBackgroundLow.g, root.colBackgroundLow.b, 0.6)
                            border.width: 1
                            border.color: Qt.rgba(root.colBorder.r, root.colBorder.g, root.colBorder.b, 0.25)

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: modelData.value.toLocaleString()
                                    color: root.colText
                                    font.family: root.fontMono
                                    font.pixelSize: 22
                                    font.weight: Font.Bold
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: modelData.label
                                    color: root.colTextDim
                                    font.family: root.fontMain
                                    font.pixelSize: 10
                                    font.letterSpacing: 1.5
                                    font.capitalization: Font.AllUppercase
                                    font.weight: Font.Medium
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }

                // Top repos
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Text {
                        text: "TOP REPOS · " + (root.ghData?.user?.public_repos || 0) + " PUBLIC"
                        color: root.colTextDim
                        font.family: root.fontMono
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                        font.capitalization: Font.AllUppercase
                        font.weight: Font.Medium
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root.ghData?.top_repos?.length || 0
                        delegate: Rectangle {
                            required property int index
                            property var repo: root.ghData.top_repos[index]
                            width: parent ? parent.width : 0
                            height: 44
                            radius: 10
                            color: rowArea.containsMouse
                                ? Qt.rgba(root.colText.r, root.colText.g, root.colText.b, 0.06)
                                : Qt.rgba(root.colBackgroundLow.r, root.colBackgroundLow.g, root.colBackgroundLow.b, 0.4)
                            border.width: 1
                            border.color: Qt.rgba(root.colBorder.r, root.colBorder.g, root.colBorder.b, 0.2)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10

                                Text {
                                    text: repo.full_name || ""
                                    color: root.colText
                                    font.family: root.fontMono
                                    font.pixelSize: 12
                                    Layout.alignment: Qt.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: (repo.stars || 0) + " stars"
                                    color: root.colAccent
                                    font.family: root.fontMono
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }
                                Text {
                                    text: repo.updated_ago || ""
                                    color: root.colTextDim
                                    font.family: root.fontMono
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 36
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally(repo.html_url)
                            }
                        }
                    }
                }
            }

            // Inbox tab
            ColumnLayout {
                visible: root.activeTab === "inbox"
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: "NOTIFICATIONS"
                    color: root.colTextDim
                    font.family: root.fontMono
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    font.capitalization: Font.AllUppercase
                    font.weight: Font.Medium
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root.ghData?.notifications?.length || 0
                        delegate: Rectangle {
                            required property int index
                            property var note: root.ghData.notifications[index]
                            width: parent ? parent.width : 0
                            height: 56
                            radius: 10
                            color: Qt.rgba(root.colBackgroundLow.r, root.colBackgroundLow.g, root.colBackgroundLow.b, 0.4)
                            border.width: 1
                            border.color: Qt.rgba(root.colBorder.r, root.colBorder.g, root.colBorder.b, 0.2)
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 2
                                Text {
                                    text: note.repo || ""
                                    color: root.colTextDim
                                    font.family: root.fontMono
                                    font.pixelSize: 10
                                    font.letterSpacing: 1
                                }
                                Text {
                                    text: note.title || ""
                                    color: root.colText
                                    font.family: root.fontMain
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                    Text {
                        visible: !root.ghData?.notifications?.length
                        text: "No unread notifications"
                        color: root.colTextDim
                        font.family: root.fontMain
                        font.pixelSize: 13
                        font.italic: true
                        padding: 12
                    }
                }
            }

            // Pulls tab
            ColumnLayout {
                visible: root.activeTab === "pulls"
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: "OPEN PULL REQUESTS"
                    color: root.colTextDim
                    font.family: root.fontMono
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    font.capitalization: Font.AllUppercase
                    font.weight: Font.Medium
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root.ghData?.open_prs?.length || 0
                        delegate: Rectangle {
                            required property int index
                            property var pr: root.ghData.open_prs[index]
                            width: parent ? parent.width : 0
                            height: 56
                            radius: 10
                            color: Qt.rgba(root.colBackgroundLow.r, root.colBackgroundLow.g, root.colBackgroundLow.b, 0.4)
                            border.width: 1
                            border.color: Qt.rgba(root.colBorder.r, root.colBorder.g, root.colBorder.b, 0.2)
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text {
                                        text: pr.repo || ""
                                        color: root.colTextDim
                                        font.family: root.fontMono
                                        font.pixelSize: 10
                                    }
                                    Rectangle {
                                        visible: pr.is_draft
                                        Layout.preferredHeight: 16
                                        Layout.preferredWidth: draftText.implicitWidth + 10
                                        radius: 8
                                        color: Qt.rgba(root.colTextDim.r, root.colTextDim.g, root.colTextDim.b, 0.18)
                                        Text {
                                            id: draftText
                                            anchors.centerIn: parent
                                            text: "DRAFT"
                                            color: root.colTextDim
                                            font.family: root.fontMono
                                            font.pixelSize: 8
                                            font.weight: Font.Bold
                                        }
                                    }
                                }
                                Text {
                                    text: (pr.title || "")
                                    color: root.colText
                                    font.family: root.fontMain
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally(pr.url)
                            }
                        }
                    }
                    Text {
                        visible: !root.ghData?.open_prs?.length
                        text: "No open pull requests"
                        color: root.colTextDim
                        font.family: root.fontMain
                        font.pixelSize: 13
                        font.italic: true
                        padding: 12
                    }
                }
            }

            // Actions tab
            ColumnLayout {
                visible: root.activeTab === "actions"
                Layout.fillWidth: true
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "WORKFLOW RUNS"
                        color: root.colTextDim
                        font.family: root.fontMono
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                        font.capitalization: Font.AllUppercase
                        font.weight: Font.Medium
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (root.ghData?.actions?.failing || 0) + " failing / "
                              + (root.ghData?.actions?.total || 0) + " total"
                        color: (root.ghData?.actions?.failing || 0) > 0 ? root.m3.m3error : root.colTextDim
                        font.family: root.fontMono
                        font.pixelSize: 11
                    }
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root.ghData?.actions?.items?.length || 0
                        delegate: Rectangle {
                            required property int index
                            property var run: root.ghData.actions.items[index]
                            width: parent ? parent.width : 0
                            height: 52
                            radius: 10
                            color: Qt.rgba(root.colBackgroundLow.r, root.colBackgroundLow.g, root.colBackgroundLow.b, 0.4)
                            border.width: 1
                            border.color: Qt.rgba(root.colBorder.r, root.colBorder.g, root.colBorder.b, 0.2)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    Layout.alignment: Qt.AlignVCenter
                                    color: run.conclusion === "failure"
                                        ? root.m3.m3error
                                        : (run.conclusion === "success" ? root.colAccent : root.colTodayAccent)
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        text: (run.repo || "") + " · " + (run.name || "")
                                        color: root.colText
                                        font.family: root.fontMain
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: (run.branch || "") + " · " + (run.conclusion || run.status || "")
                                        color: root.colTextDim
                                        font.family: root.fontMono
                                        font.pixelSize: 10
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally(run.url)
                            }
                        }
                    }
                    Text {
                        visible: !root.ghData?.actions?.items?.length
                        text: "No recent workflow runs"
                        color: root.colTextDim
                        font.family: root.fontMain
                        font.pixelSize: 13
                        font.italic: true
                        padding: 12
                    }
                }
            }

            // ===== Footer =====
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                text: "1-4 tabs · R refresh · Esc close · polls every 5 min"
                color: root.colTextDim
                font.family: root.fontMono
                font.pixelSize: 10
                opacity: 0.7
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ===== Keyboard =====
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_R) {
            root.refresh()
            event.accepted = true
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
            const tabs = ["overview", "inbox", "pulls", "actions"]
            root.activeTab = tabs[event.key - Qt.Key_1]
            event.accepted = true
        }
    }
}