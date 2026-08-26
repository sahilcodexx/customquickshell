pragma Singleton
import QtQuick
QtObject {
    property bool showAiUsage: true
    property string aiUsageProviders: "claude,codex,antigravity,cursor,copilot,grok,opencode,minimax"
    // Collectors scan local agent history files. Keep normal refreshes light;
    // the Refresh button still performs an immediate full update.
    property int aiUsageRefreshMinutes: 15
    property bool aiUsageAutoRefresh: true
    property string aiUsageSyncMode: "Off"
    property string aiUsageSyncDir: ""
    property string aiUsageSyncFileName: ""
    property string aiUsageSyncDeviceId: ""
}
