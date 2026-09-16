import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Standalone Quickshell shell hosting the GitHub dashboard card.
// Run via: qs -p ~/.config/quickshell/github-card
// Trigger via:
//   qs -p ~/.config/quickshell/github-card ipc call github toggle
ShellRoot {
    id: root

    property bool cardVisible: false

    function toggleCard() { root.cardVisible = !root.cardVisible }
    function openCard()   { root.cardVisible = true }
    function closeCard()  { root.cardVisible = false }

    Connections {
        target: cardLoader
        function onLoaded() { root.cardVisible = true }
    }

    Loader {
        id: cardLoader
        active: root.cardVisible
        sourceComponent: panelComponent
    }

    Component {
        id: panelComponent
        PanelWindow {
            id: panel
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:github"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item {
                id: cardContainer
                anchors.fill: parent
                focus: true

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        root.closeCard()
                        event.accepted = true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onPressed: (mouse) => {
                        let pos = cardItem.mapFromItem(null, mouse.x, mouse.y)
                        let insideX = pos.x >= 0 && pos.x <= cardItem.width
                        let insideY = pos.y >= 0 && pos.y <= cardItem.height
                        if (!(insideX && insideY)) {
                            root.closeCard()
                        } else {
                            mouse.accepted = false
                        }
                    }
                }

                GithubCard {
                    id: cardItem
                    anchors.centerIn: parent
                    onCloseRequested: root.closeCard()
                }
            }
        }
    }

    IpcHandler {
        target: "github"
        function toggle(): void { root.toggleCard() }
        function open(): void { root.openCard() }
        function close(): void { root.closeCard() }
    }

    GlobalShortcut {
        name: "githubToggle"
        description: "Toggle GitHub card"
        onPressed: root.toggleCard()
    }
}