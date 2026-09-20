pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    readonly property var providers: AgentUsage.enabledProviders
    readonly property var provider: AgentUsage.selectedProvider
    readonly property var models: AgentUsage.modelRows(provider)
    // Always show last 7 calendar days ending today, filling missing with 0 — fixes stale 17-23 when today is 25
    readonly property var days: {
        if (!provider || !provider.recentDays) return []
        var map = {}
        for (var i = 0; i < provider.recentDays.length; i++) {
            var e = provider.recentDays[i]
            if (e && e.date) map[String(e.date)] = Number(e.messageCount || 0)
        }
        var out = []
        var t = new Date()
        for (var off = 6; off >= 0; off--) {
            var d = new Date(t)
            d.setDate(t.getDate() - off)
            var iso = d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2)
            out.push({date: iso, messageCount: map[iso] !== undefined ? map[iso] : 0})
        }
        return out
    }
    readonly property string logoFolder: Qt.resolvedUrl("/home/sahilcodex/Downloads/agentslogo")

    // Auto-refresh if data is stale (today not in file or last update >15m) — fixes 23 vs 25
    function isStale() {
        if (!provider || !provider.recentDays || provider.recentDays.length === 0) return true
        var todayIso = new Date().toISOString().slice(0,10)
        var last = String(provider.recentDays[provider.recentDays.length - 1].date || "")
        // if file's last date != today, it's stale
        if (last !== todayIso) return true
        // also if last update > refresh interval
        if (AgentUsage.lastUpdatedMs && (Date.now() - AgentUsage.lastUpdatedMs) > AgentUsage.refreshIntervalSec * 1000) return true
        return false
    }
    Component.onCompleted: {
        if (root.isStale() && !AgentUsage.updating) Qt.callLater(function(){ AgentUsage.refreshAll(false) })
    }
    onProviderChanged: {
        if (root.isStale() && !AgentUsage.updating) Qt.callLater(function(){ AgentUsage.refreshAll(false) })
    }

    function logo(id) {
        var x = String(id || "").toLowerCase()
        if (x === "opencode") return "opencode.svg"
        if (x === "claude") return "claude-color.svg"
        if (x === "codex") return "codex-color.svg"
        if (x === "antigravity") return "antigravity-color.svg"
        if (x === "deepseek") return "deepseek-color.svg"
        if (x === "cursor") return "cursor.svg"
        if (x === "grok") return "grok.svg"
        if (x === "minimax") return "minimax.svg"
        if (x === "mcode") return "minimax.svg"
        return root.provider ? root.logo(root.provider.providerId) : ""
    }
    function logoTileColor(id) {
        var x = String(id || "").toLowerCase()
        if (x === "opencode") return "#f4d7b8"
        if (x === "claude") return "#f1d9d0"
        if (x === "codex") return "#d9e0ff"
        if (x === "antigravity") return "#dcecf5"
        return Appearance.colors.colLayer3
    }
    function fmt(value) { return AgentUsage.formatTokenCount(Number(value || 0)) }
    function modelName(value) {
        return String(value || "Unknown").replace(/\s+(Contributor\s+)?Free$/i, "")
    }
    function totalTokens() {
        var total = 0
        if (!root.provider || !root.provider.modelUsage) return total
        for (var key in root.provider.modelUsage) {
            var row = root.provider.modelUsage[key] || {}
            total += Number(row.inputTokens || 0) + Number(row.outputTokens || 0) + Number(row.cacheReadInputTokens || 0) + Number(row.cacheCreationInputTokens || 0)
        }
        return total
    }
    function dayName(value) { var d = new Date(String(value || "") + "T00:00:00"); return isNaN(d.getTime()) ? "" : ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][d.getDay()] }
    function dayNumber(value) { var d = new Date(String(value || "") + "T00:00:00"); return isNaN(d.getTime()) ? "" : String(d.getDate()) }
    function averagePrompt() { return root.provider ? root.fmt(root.totalTokens() / Math.max(1, Number(root.provider.totalPrompts || 0))) : "0" }
    function peakDay() {
        var best = null
        for (var i = 0; i < root.days.length; i++) {
            if (!best || Number(root.days[i].messageCount || 0) > Number(best.messageCount || 0)) best = root.days[i]
        }
        return best ? root.dayName(best.date) : "—"
    }
    function peakValue() {
        var best = 0
        for (var i = 0; i < root.days.length; i++) best = Math.max(best, Number(root.days[i].messageCount || 0))
        return root.fmt(best) + " peak"
    }
    function cacheHit() {
        var input = 0
        var cached = 0
        if (root.provider && root.provider.modelUsage) {
            for (var key in root.provider.modelUsage) {
                var row = root.provider.modelUsage[key] || {}
                input += Number(row.inputTokens || 0)
                cached += Number(row.cacheReadInputTokens || 0)
            }
        }
        return Math.round(cached / Math.max(1, input + cached) * 100) + "%"
    }

    component Card: Rectangle {
        Layout.fillWidth: true
        radius: Appearance.rounding.normal
        // Adaptive: #e9efea light / #201f20 dark — fixes dark 83M invisible on light card
        color: Appearance.m3colors.m3surfaceContainer
        border.width: 1
        border.color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.55)
        implicitHeight: body.implicitHeight + 24
        default property alias content: body.data
        ColumnLayout { id: body; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; spacing: 10 }
    }
    component SmallLabel: StyledText {
        Layout.fillWidth: true
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
    }
    component InsightTile: Rectangle {
        id: tile
        required property string value
        required property string caption
        Layout.fillWidth: true
        Layout.preferredHeight: 86
        radius: Appearance.rounding.small
        // Adaptive: #e4eae5 light / #2b2a2a dark
        color: Appearance.m3colors.m3surfaceContainerHigh
        border.width: 1
        border.color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.6)
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 3
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: tile.value
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.numbers
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: tile.caption
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }
        }
    }
    component LogoTile: Rectangle {
        required property string providerId
        implicitWidth: 32
        implicitHeight: 32
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: Appearance.rounding.verysmall
        // Keep the source artwork untouched; the original SVG supplies its
        // own colors and should not be placed on a generated color tile.
        color: "transparent"
        CustomIcon {
            anchors.centerIn: parent
            width: 20
            height: 20
            iconFolder: root.logoFolder
            source: root.logo(providerId)
            colorize: String(providerId).toLowerCase() === "opencode"
            color: "#ff7512"
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: Translation.tr("AI Usage")
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                Rectangle {
                    implicitWidth: providerCount.implicitWidth + 16
                    implicitHeight: 24
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colSecondaryContainer
                    StyledText {
                        id: providerCount
                        anchors.centerIn: parent
                        text: Translation.tr("%1 providers").arg(root.providers.length)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
                Item { Layout.fillWidth: true }
                RippleButton {
                    implicitWidth: 86
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer3Base
                    colBackgroundHover: Appearance.colors.colLayer3Hover
                    colRipple: Appearance.colors.colLayer3Active
                    onClicked: AgentUsage.refreshAll(true)
                    contentItem: RowLayout {
                        spacing: 5
                        MaterialSymbol { text: "refresh"; iconSize: 15 }
                        StyledText { text: AgentUsage.updating ? "Updating" : "Refresh"; font.pixelSize: Appearance.font.pixelSize.smaller }
                    }
                }
            }

            StyledFlickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: stack.implicitHeight + 8
                ColumnLayout {
                    id: stack
                    width: parent.width
                    spacing: 10

                    Card {
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 62
                                // Left: current usage - keep as was, just +6px from left line
                                StyledText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "current usage"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                    horizontalAlignment: Text.AlignLeft
                                    font.weight: Font.Medium
                                }
                                // Center: 7.1M + credits today - truly centered in card
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    StyledText { text: root.provider ? root.fmt(root.provider.todayTotalTokens) : "0"; font.family: Appearance.font.family.numbers; font.pixelSize: 34; font.weight: Font.DemiBold; lineHeight: 1.0; horizontalAlignment: Text.AlignHCenter }
                                    StyledText { text: "credits today"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext; horizontalAlignment: Text.AlignHCenter }
                                }
                                // Right: logo as in red box
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 48
                                    height: 48
                                        radius: Appearance.rounding.full
                                        color: "transparent"
                                        CustomIcon {
                                            anchors.centerIn: parent
                                            width: 36
                                            height: 36
                                            iconFolder: root.logoFolder
                                            source: root.logo(root.provider ? root.provider.providerId : "")
                                            colorize: String(root.provider ? root.provider.providerId : "").toLowerCase() === "opencode"
                                            color: "#ff6a00"
                                            visible: root.provider && source !== ""
                                    }
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "analytics"
                                        iconSize: 20
                                        color: Appearance.colors.colSubtext
                                        visible: !root.provider || root.logo(root.provider ? root.provider.providerId : "") === ""
                                    }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.75)
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Repeater {
                                    model: [["Total", root.fmt(root.totalTokens()), "credits"], ["Active", root.provider ? root.provider.activeDays : 0, "days"], ["Sessions", root.provider ? root.provider.totalSessions : 0, "total"]]
                                    delegate: RowLayout {
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 36; color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.7); visible: index !== 0 }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            StyledText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData[0]; font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext; font.weight: Font.Medium }
                                            StyledText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData[1]; font.pixelSize: Appearance.font.pixelSize.large; font.family: Appearance.font.family.numbers; font.weight: Font.DemiBold }
                                            StyledText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData[2]; font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer2
                            border.width: 1
                            border.color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.70)
                        }
                        RippleButton {
                            id: providerButton
                            anchors.fill: parent
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer2Hover, 0.30)
                            onClicked: providerPopup.visible ? providerPopup.close() : providerPopup.open()
                            contentItem: Item {
                                LogoTile {
                                    id: selectedLogo
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    providerId: root.provider ? root.provider.providerId : ""
                                }
                                ColumnLayout {
                                    anchors.left: selectedLogo.right
                                    anchors.leftMargin: 10
                                    anchors.right: selectedChevron.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0
                                    StyledText {
                                        text: root.provider ? root.provider.providerName : "No provider"
                                        horizontalAlignment: Text.AlignLeft
                                        font.pixelSize: Appearance.font.pixelSize.smallie
                                        font.weight: Font.Medium
                                    }
                                    StyledText {
                                        text: root.provider ? root.fmt(root.provider.todayTotalTokens) : ""
                                        horizontalAlignment: Text.AlignLeft
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                    }
                                }
                                MaterialSymbol {
                                    id: selectedChevron
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: providerPopup.visible ? "expand_less" : "expand_more"
                                    iconSize: 20
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        Popup {
                            id: providerPopup
                            y: providerButton.height + 6
                            width: providerButton.width
                            padding: 6
                            modal: true
                            dim: false
                            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                            z: 100
                            background: Rectangle { color: Appearance.colors.colLayer2Base; radius: Appearance.rounding.small; border.width: 1; border.color: Appearance.colors.colOutlineVariant }
                            contentItem: ColumnLayout {
                                spacing: 2
                                Repeater {
                                    model: root.providers
                                    delegate: RippleButton {
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        implicitHeight: 48
                                        Layout.preferredHeight: 48
                                        buttonRadius: Appearance.rounding.verysmall
                                        colBackground: index === AgentUsage.selectedProviderIndex ? Appearance.colors.colSecondaryContainer : "transparent"
                                        onClicked: { AgentUsage.selectProvider(index); providerPopup.close() }
                                        contentItem: Item {
                                            LogoTile {
                                                id: popupLogo
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                providerId: modelData.providerId
                                            }
                                            ColumnLayout {
                                                anchors.left: popupLogo.right
                                                anchors.leftMargin: 10
                                                anchors.right: popupCheck.left
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 0
                                                StyledText {
                                                    text: modelData.providerName
                                                    horizontalAlignment: Text.AlignLeft
                                                }
                                                StyledText {
                                                    text: root.fmt(modelData.todayTotalTokens)
                                                    horizontalAlignment: Text.AlignLeft
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    color: Appearance.colors.colSubtext
                                                }
                                            }
                                            MaterialSymbol {
                                                id: popupCheck
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: index === AgentUsage.selectedProviderIndex
                                                text: "check"
                                                iconSize: 16
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    }

                    Card {
                        RowLayout {
                            Layout.fillWidth: true
                            SmallLabel { text: "Last 7 days" }
                            StyledText { text: root.provider ? root.fmt(root.days.reduce((sum, d) => sum + Number(d.messageCount || 0), 0)) + " total" : ""; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: root.days
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                spacing: 5
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 72
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 5
                                            // Bit more light in light mode only (was #b9c7bf)
                                            color: Appearance.m3colors.darkmode ? Appearance.m3colors.m3outlineVariant : "#d0dcd5"
                                        }
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: Math.max(6, parent.height * Number(modelData.messageCount || 0) / Math.max(1, AgentUsage.weekPeak(root.provider)))
                                            radius: 5
                                            color: Appearance.colors.colPrimary
                                        }
                                        MouseArea {
                                            id: dayHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            StyledToolTip {
                                                extraVisibleCondition: false
                                                alternativeVisibleCondition: dayHover.containsMouse
                                                text: root.dayName(modelData.date) + " " + root.dayNumber(modelData.date) + "\n" + root.fmt(modelData.messageCount) + " prompts"
                                            }
                                        }
                                    }
                                    StyledText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.dayName(modelData.date); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                                    StyledText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: root.dayNumber(modelData.date); font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext }
                                }
                            }
                        }
                    }

                    Card {
                        SmallLabel { text: "Top models" }
                        Repeater {
                            model: root.models.slice(0, 3)
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                RowLayout {
                                    Layout.fillWidth: true
                                LogoTile { providerId: modelData.id }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                    StyledText { text: root.modelName(modelData.name); font.pixelSize: Appearance.font.pixelSize.smallie; font.weight: Font.Medium }
                                        StyledText { text: "In " + root.fmt(modelData.input) + " · Out " + root.fmt(modelData.output) + (modelData.cacheRead > 0 ? " · Cache " + root.fmt(modelData.cacheRead) : ""); font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext; elide: Text.ElideRight }
                                    }
                                    StyledText { text: root.fmt(modelData.total); font.pixelSize: Appearance.font.pixelSize.smallie; font.family: Appearance.font.family.numbers }
                                }
                                StyledProgressBar { Layout.fillWidth: true; value: modelData.total / Math.max(1, root.models.length > 0 ? root.models[0].total : 1); valueBarHeight: 6 }
                            }
                        }
                    }

                    Card {
                        RowLayout {
                            Layout.fillWidth: true
                            SmallLabel { text: "Insights" }
                            MaterialSymbol {
                                text: "auto_awesome"
                                iconSize: 16
                                color: Appearance.colors.colSubtext
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            InsightTile { value: root.averagePrompt(); caption: "per prompt" }
                            InsightTile { value: root.peakDay(); caption: root.peakValue() }
                            InsightTile { value: root.cacheHit(); caption: "cache hit" }
                        }
                    }

                    Card {
                        RowLayout {
                            Layout.fillWidth: true
                            MaterialSymbol {
                                text: "schedule"
                                iconSize: 20
                                color: Appearance.colors.colSubtext
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                StyledText {
                                    text: AgentUsage.updating ? "Updating usage…" : "Usage loaded from cache · Manual refresh"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                                StyledText {
                                    text: (root.provider ? root.provider.totalPrompts : 0) + " prompts · " + (root.provider ? root.provider.totalSessions : 0) + " sessions · " + (root.provider ? root.provider.activeDays : 0) + " days"
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                }
                            }
                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colPrimary
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "folder_open"
                                    iconSize: 18
                                    color: Appearance.colors.colOnPrimary
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
